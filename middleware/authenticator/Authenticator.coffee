
abmvc = require('abmvc')
mongodb = require('mongodb')
Crypto = require 'crypto'

Authenticator =
  users: 'uesrs'
  cookie_name: 'auth.id'


  logout: (request, response)->
    request.signed.clearCookie Authenticator.cookie_name, null


  isAuthenticated: (request, response, value)->
    if request.signed.getCookie Authenticator.cookie_name then true
    else false


  authenticatedValue: (request, response, value)->
    request.signed.getCookie Authenticator.cookie_name


  authenticate: (request, response, value)->
    request.signed.setCookie Authenticator.cookie_name, value


  ##|
  ##|  Function decorator that redirects if the user IS NOT already authenticated
  ##|
  redirectIfNotAuthenticated: (url)->
    (next)->
      (request, response)->
        if not request.signed.getCookie Authenticator.cookie_name
          response.redirect url, 301
        else
          next(request, response)


  ##|
  ##|  Function decorator that redirects if the user IS already authenticated
  ##|
  redirectIfAuthenticated: (url)->
    (next)->
      (request, response)->
        if request.signed.getCookie Authenticator.cookie_name
          response.redirect url, 301
        else
          next(request, response)


  ##|
  ##|  Function decorator that attaches 'user' to the request, based on the signed cookie
  ##|
  fetchAuthenticatedUser: (next)->
    (request, response)->
      on_error = (error)-> throw error
      on_success = (result)->
        request.user = result
        next request, response

      if Authenticator.authenticatedValue(request, response)
        client = new mongodb.Db(abmvc.db.name, new mongodb.Server(abmvc.db.host, abmvc.db.port))
        
        id = new client.bson_serializer.ObjectID(Authenticator.authenticatedValue(request, response))
        query = { _id: id }
        client.open (error)->
          return on_error(error) if error
          client.collection 'users', (error, collection)->
            return on_error(error) if error
            collection.findOne query, (error, result)->
              return on_error(error) if error
              console.log result
              if result
                Authenticator.authenticate request, response, result._id
                on_success(result)
              else
                on_success(null)
      else
        on_success(null)


  ##|
  ##|  Function decorator that attaches 'user' to the request, based on POST (or, conceivably, GET) data
  ##|
  verifyUserCredentials: (username_keys = 'body.login.email', password_keys = 'body.login.password')->
    (next)->
      (request, response)->
        on_error = (error)-> throw error
        on_success = (result)->
          request.user = result
          next request, response

        # find_in_request uses the dot-separated keys above and searches in request for that value
        username = find_in_request username_keys, request
        password = find_in_request password_keys, request

        if username
          query = { '$or': [ {username}, {email:username} ] }

          client = new mongodb.Db(abmvc.db.name, new mongodb.Server(abmvc.db.host, abmvc.db.port))
          client.open (error)->
            return on_error(error) if error
            client.collection 'users', (error, collection)->
              return on_error(error) if error
              collection.findOne query, (error, result)->
                return on_error(error) if error
                if result
                  hash = Crypto.createHash 'sha256'
                  hash.update result.salt + password
                  key = hash.digest('hex')
                  if key != result.password
                    result = null
                  else
                    Authenticator.authenticate request, response, result._id
                  on_success(result)
                else
                  on_success(null)
        else
          on_success(null)


find_in_request = (keys, request)->
  keys = keys.split('.') if typeof keys == 'string'

  ret = request
  for k in keys
    ret = ret[k]
    break if not ret?
  ret


module.exports = Authenticator
