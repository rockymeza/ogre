
TF = require 'tierfactory'

redirect = (options)->
        options = {redirect:options} if options and typeof options != 'object'
        options.status ?= 303 if options
        if options?.redirect == true
          response.redirect request.url, options.status
        else if options
          response.redirect options.redirect, options.status
        else
          throw TF.FileNotFound 'This page must be viewed over https'
    
requireHttps = (options = null)->
  (action)->
    (request, response)->
      if not request.connection.encrypted
        redirect(options)
      else
        action(request, response)

requireHttp = (options = null)->
  (action)->
    (request, response)->
      if not request.connection.encrypted
        action(request, response)
      else
        redirect(options)
