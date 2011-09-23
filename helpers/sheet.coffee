coffeekup = require 'coffeekup'

module.exports =
  sheet: (sheet)->
    link
      href: sheet
      rel: 'stylesheet'
      type: 'text/css'
