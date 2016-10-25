debugLib = require 'debug'

module.exports =

  log: debugLib 'app:log'
  debug: debugLib 'app:debug'
  errorLog: debugLib 'app:error'

  pretty: (thing) ->
    JSON.stringify thing, null, 2

  fail: (err) ->
    if typeof err is 'string'
      err = new Error err
    throw err

