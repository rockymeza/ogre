coffeekup = require 'coffeekup'

module.exports =
  bucket: (options, other_options...) ->
    # this is what gets output
    parts = 
      bucket: { idclass: '.bucket' }
      top   : { content: null, idclass: '.top'}
      middle: { content: null, idclass: '.middle'}
      bottom: { content: null, idclass: '.bottom'}
    
    if options instanceof Array
      assigners = ['bucket', 'top', 'middle', 'bottom']
      while (idclass = options.pop()) and (assign = assigners.pop())
        parts[assign].idclass = '.' + idclass
      options = other_options.shift()
    else if typeof options == 'string' and options in ['.', '#']
      parts.bucket.idclass = options
      options = other_options.shift()
    
    if typeof options == 'string'
      parts.middle.content = options
      options = other_options.shift()
    
    if options instanceof Object
      if options.classes?
        assigners = ['bucket', 'top', 'middle', 'bottom']
        while (idclass = options.classes.pop()) and (assign = assigners.pop())
          parts[assign].idclass = '.' + idclass
      
      for part in ['top', 'middle', 'bottom']
        parts[part].content ?= options[part]
    
    div parts.bucket.idclass, ->
      div parts.top.idclass, parts.top.content
      div parts.middle.idclass, parts.middle.content
      div parts.bottom.idclass, parts.bottom.content
