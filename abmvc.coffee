
fs = require 'fs'
path = require 'path'
yaml = require 'yaml'
_ = require 'underscore'

abmvc = (server, app_dir)->
  abmvc.app_dir = app_dir
  server.reverse = (action_name)-> '/url'
  
  # default views location
  server.set('views', __dirname + '/views');
  server.dynamicHelpers session: (req, res)-> req.session
  
  loadErrorHanders server, ->
    loadHelpers server, ->
      loadDatabase server, ->
        loadRoutes server, -> 
          console.log 'abmvc successfully loaded'

##|
##|  OTHER RESOURCES
##|
abmvc.signedCookieParser = require('./signedCookieParser');
abmvc.FileNotFound = require('./errors/FileNotFound')
module.exports = abmvc


##|
##|  LOADING
##|
loadErrorHanders = (server, callback)->
  server.error (err, req, res, next)->
    if err instanceof abmvc.FileNotFound
      res.render '404'
    else
      next(err);
  callback()


loadDatabase = (server, callback)->
  db_path = abmvc.app_dir + '/config/database.coffee'
  path.exists db_path, (exists)->
    if exists
      abmvc.db = _.extend { host: '127.0.0.1', port: 27017 }, require(db_path)
      if not abmvc.db then throw new Error "name is a required property of database.coffee"
    callback()


loadRoutes = (server, callback)->
  routes = require(abmvc.app_dir + '/config/routes.coffee')
  reversals = {}
  
  actions = {}
  for route_entry in routes
    [route, package] = route_entry
    http_verbs = route.match(/^((?:\|?(?:GET|POST|DEL|PUT|ALL))*) (.*)/i)
    if http_verbs
      route = http_verbs[2]
      http_verbs = http_verbs[1].toLowerCase()
    else
      http_verbs = 'get'

    [resource..., action_name] = package.split '.'
    if resource.length == 0 then resource = action_name
    else  resource = resource.join '.'
    
    if not actions[resource]
      # app is being loaded for the first time
      actions[resource] = require("#{abmvc.app_dir}/apps/#{resource}/actions.coffee")(server)
      if actions[resource] instanceof Function  # only one action was returned
        action = actions[resource]
        actions[resource] = {}
        actions[resource][action_name] = action
    action = actions[resource][action_name]
    
    # for server.reverse
    reversals["#{resource}.#{action_name}"] = route
    
    throw new Error("Unknown action #{action_name} (referrenced in #{package})") if not action
    
    for http_verb in http_verbs.split '|'
      # e.g. server.get, server.post, server.all
      # protect ze vars!
      loadRoute(server, http_verb, route, action, resource)
  callback()

loadRoute = (server, http_verb, route, action, resource)->
  server[http_verb] route, (request, response)->
    server.set('views', "#{abmvc.app_dir}/apps/#{resource}/views");
    action.call this, request, response

##|  MISC
loadHelpers = (server, callback)->
  helper_locations = [ __dirname + '/helpers', abmvc.app_dir + '/helpers' ]
  after_helpers_loaded = _.after(helper_locations.length, callback or ->{})
  
  # abmvc helpers
  for helper_path in helper_locations
    do ( helper_path )->
      path.exists helper_path, (exists)->
        if exists
          fs.readdir helper_path, (error, files)->
            if _.isArray files

              for file in files
                server.helpers require './helpers/' + file
            after_helpers_loaded()
        else
          after_helpers_loaded()
