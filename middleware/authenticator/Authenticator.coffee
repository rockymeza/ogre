
TF = require 'tierfactory'
mongodb = require('mongodb')
Crypto = require 'crypto'

Authenticator =
  cookie_name: 'auth.id'


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
    (action)->
      (request, response, next)->
        if request.signed.getCookie Authenticator.cookie_name
          action(request, response, next)
        else
          # next() if next
          response.redirect url, 301 # unless next


  ##|
  ##|  Function decorator that redirects if the user IS already authenticated
  ##|
  redirectIfAuthenticated: (url)->
    (action)->
      (request, response, next)->
        if request.signed.getCookie Authenticator.cookie_name
          # next() if next
          response.redirect url, 301 # unless next
        else
          action(request, response, next)


  ##|
  ##|  Function decorator that attaches 'user' to the request, based on the signed cookie
  ##|
  fetchAuthenticatedUser: (user_collection = 'users')->
    (action)->
      (request, response, next)->
        on_error = (error)-> throw error
        on_success = (result)->
          request.user = result
          action(request, response, next)

        if Authenticator.authenticatedValue(request, response)
          client = new mongodb.Db(TF.db.name, new mongodb.Server(TF.db.host, TF.db.port))
          
          id = new client.bson_serializer.ObjectID(Authenticator.authenticatedValue(request, response))
          query = { _id: id }
          client.open (error)->
            return on_error(error) if error
            client.collection user_collection, (error, collection)->
              return on_error(error) if error
              collection.findOne query, (error, result)->
                return on_error(error) if error
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
  verifyUserCredentials: (user_collection = 'users', username_keys = 'body.login.email', password_keys = 'body.login.password')->
    (action)->
      (request, response, next)->
        on_error = (error)-> throw error
        on_success = (result)->
          request.user = result
          action(request, response)

        # find_in_request uses the dot-separated keys above and searches in request for that value
        username = find_in_request username_keys, request
        password = find_in_request password_keys, request

        if username
          query = { '$or': [ {username}, {email:username} ] }

          client = new mongodb.Db(TF.db.name, new mongodb.Server(TF.db.host, TF.db.port))
          client.open (error)->
            return on_error(error) if error
            client.collection user_collection, (error, collection)->
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

  ##|
  ##|  The opposite of "verifyUserCredentials" - logout the user
  ##|
  logout: (cookie_name = Authenticator.cookie_name)->
    (action)->
      ->(request, response, next)->
        request.signed.clearCookie Authenticator.cookie_name, null
        action(request, response, next)


find_in_request = (keys, request)->
  keys = keys.split('.') if typeof keys == 'string'

  ret = request
  for k in keys
    ret = ret[k]
    break if not ret?
  ret


module.exports = Authenticator
