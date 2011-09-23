###
Author: Gavin Wahl <gwahl@fusionbox.com>
Ported to javascript by Colin Thomas-Arnold <colin@fusionbox.com>

Signed cookies are awesome. This module allows you to ask users to pass
data around for you, yet be cryptographically assured that they can not
modify it. We also include timeout functionality, so you can give someone a
token and be sure that they haven't held on to it for too long.

The simplest signing functions are sign() and verify(). Use these if you
don't actually want to mess with cookies, but need to pass data around in
urls or emails. SignedCookie could be a bad name, except for...

If you do want to set a cookie, use set() and get(). These will access and
sign or verify a cookie named by one of their parameters.

The realm option adds namespacing to set and get. These check
that the realm hasn't been tampered with, so you can be sure someone can't
transfer their credentials from one realm to another. Values are intentionally
not portable across realms, so a user authenticated in the 'www' realm can not
copy his cookie value into the 'admin' realm.

###

Crypto = require 'crypto'
DU = require 'date-utilities'

module.exports = (options)->
  options ?= {}
  if typeof options == 'string' then options = {salt: options}
  if ! options.salt then throw new Error('SignedCookie.salt is missing, and is a required value.')
  
  (req, res, next)->
    if req.signed then return next()
    
    sc = new SignedCookie(req, res, {salt: options.salt, host: options.host})
    req.signed =
      clearCookie: (name, options)-> sc.set(name, '', options)
      setCookie: (name, value, options)-> sc.set(name, value, options)
      getCookie: (name, options)-> sc.get(name, options)
    next()

###
 options: salt, host, realm.  salt is required.
###
class SignedCookie
  constructor: (req, res, options)->
    @req = req
    @res = res
    {@salt, @host, @realm} = options
    if @realm && @realm.indexOf(':') > -1 then throw new Error("Don't put ':' in realm names please")


  getSignature: (value, key)->
    hash_hmac = Crypto.createHmac 'sha256', key
    hash_hmac.update value
    hash_hmac.digest('base64')


  ###
   Constant-time string comparison. Prevents some timing side-channel 
   attacks, feasibility of which is unknown.
  ###
  compareSignatures: (a, b)->
    if a.length != b.length then return false

    difference = 0
    for v, i in a
      difference |= v.charCodeAt(0) ^ b[i].charCodeAt(0)
    difference == 0


  ###
   Given a secret key, return value with verifiable signature attached.
  ###
  sign: (value, key)->
    value = DU.now() + ':' + value
    signature = @getSignature(value, key)
    signature + ':' + value


  ###
   Verify a string produced by sign()
   Return the original string passed to sign() or null if the signature is
   invalid.
  ###
  verify: (value, key, timeout = null)->
    [left, right...] = value.split(':')
    right = right.join(':')

    if @compareSignatures(left, @getSignature(right, key))
      # good signature, now extract timestamp
      [timestamp, data] = right.split(':', 2)
      if timeout == null or DU.now() <= (timestamp + timeout)
        data
      else
        null
    else
      null


  ###
   The secret used for cookie signing.
  ###
  getCookieKey: ()-> @salt


  ###
   Retrieve the value passed to set() or null if the value doesn't exist or
   if the signature is invalid
  ###
  get: (name, options = { timeout: null })->
    name = "#{if @realm then @realm +':' else ''}#{name}" if @realm
    unsafe_value = if @req.cookies[name]? then @req.cookies[name] else null
    if ! unsafe_value then return null
    @verify(unsafe_value, @getCookieKey(), options.timeout)


  ###
   Set a signed cookie, using a secret per-server value to prevent tampering
  ###
  set: (name, value, options)->
    name = "#{if @realm then @realm +':' else ''}#{name}" if @realm
    value = "#{if @realm then @realm +':' else ''}#{value}" if @realm
    
    options ?= {}
    options.path ?= '/'
    options.domain ?= @host
    options.secure ?= @req.https
    options.maxAge ?= 1000*3600
    
    value = @sign(value, @getCookieKey())

    @req.cookies[name] = value
    @res.cookie(name, value, options)

