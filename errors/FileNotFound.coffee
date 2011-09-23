
class FileNotFound extends Error
  constructor: (msg)->
    @name = 'File Not Found';
    Error.call this, msg
    Error.captureStackTrace this, arguments.callee

module.exports = FileNotFound
