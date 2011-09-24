
TF = require 'tierfactory'

redirect = (response, request, options = true)->
        options = {redirect:options} if options and typeof options != 'object'
        options.status ?= 303 if options
        if options?.redirect == true
          if request.connection.encrypted
            options.redirect = 'http://' + request.headers['host'].replace(/:[0-9]+$/, ':' + TF.server.HTTP_PORT)
          else
            options.redirect = 'https://' + request.headers['host'].replace(/:[0-9]+$/, ':' + TF.server.HTTPS_PORT)
          options.redirect += request.url
        
        if options
          response.redirect options.redirect, options.status
        else
          throw TF.FileNotFound 'This page must be viewed over https'

RequireHttps =
    requireHttps: (options = true)->
      (action)->
        (request, response, next)->
          if not request.connection.encrypted
              # next() if next
            redirect(response, request, options) # unless next
          else
            action(request, response)
    
    requireHttp: (options = true)->
      (action)->
        (request, response, next)->
          if not request.connection.encrypted
            action(request, response)
          else
              # next() if next
            redirect(response, request, options) # unless next

module.exports = RequireHttps
