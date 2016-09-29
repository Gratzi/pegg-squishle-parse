debug = require 'debug'
log = debug 'app:log'
errorLog = debug 'app:error'

fail = (err) ->
  if typeof err is 'string'
    err = new Error err
  errorLog err
  throw err

parse = require '../lib/pegg-parse'
request = require 'request-promise'

PARSE_APP_ID = process.env.PARSE_APP_ID or fail "cannot have an empty PARSE_APP_ID"
PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY or fail "cannot have an empty PARSE_MASTER_KEY"
PARSE_SERVER_URL = process.env.PARSE_SERVER_URL or fail "cannot have an empty PARSE_SERVER_URL"

deleteAll = (className) ->
  log "deleting all #{className}s"
  args = arguments
  headers = {
    'Content-Type': 'application/json'
    'X-Parse-Application-Id': PARSE_APP_ID
    'X-Parse-Master-Key': PARSE_MASTER_KEY
  }
  request
    method: 'DELETE'
    headers: headers
    url: "#{PARSE_SERVER_URL}/purge/#{className}"
    json: true
  .then (body) -> log body
  .catch (err) -> errorLog "deleteAll", args, err

addField = (className, fieldName, type) ->
  log "adding field #{className}:#{fieldName}"
  args = arguments
  headers = {
    'Content-Type': 'application/json'
    'X-Parse-Application-Id': PARSE_APP_ID
    'X-Parse-Master-Key': PARSE_MASTER_KEY
  }
  data =
    className: className
    fields:
      "#{fieldName}":
        type: type
  request
    method: 'PUT'
    headers: headers
    body: data
    url: "#{PARSE_SERVER_URL}/schemas/#{className}"
    json: true
  .then (body) -> log body
  .catch (err) -> errorLog "addField", args, err

deleteField = (className, fieldName) ->
  log "deleting field #{className}:#{fieldName}"
  args = arguments
  headers = {
    'Content-Type': 'application/json'
    'X-Parse-Application-Id': PARSE_APP_ID
    'X-Parse-Master-Key': PARSE_MASTER_KEY
  }
  data =
    className: className
    fields:
      "#{fieldName}":
        __op: "Delete"
  request
    method: 'PUT'
    headers: headers
    body: data
    url: "#{PARSE_SERVER_URL}/schemas/#{className}"
    json: true
  .then (body) -> log body
  .catch (err) -> errorLog "deleteField", args, err

clearField = (className, fieldName, type) ->
  deleteField className, fieldName
  .then -> addField className, fieldName, type

deleteAll 'Pegg'
deleteAll 'Bestie'
deleteAll '_Session'
deleteAll 'Pref' # XXX except cosmic unicorn!
clearField 'Card', 'hasPreffed', 'Array' # XXX except cosmic unicorn!
clearField 'Choice', 'prefCount', 'Number'
clearField '_User', 'prefCounts', 'Object'
clearField '_User', 'prefCount', 'Number'
clearField '_User', 'peggCounts', 'Object'
clearField '_User', 'peggCount', 'Number'
clearField '_User', 'failCount', 'Number'
clearField '_User', 'lastActiveDate', 'Number'

# optional - nuke all users
# - delete all Users
# - delete all UserPrivates
# - delete all UserPublics
# - delete all Roles
# - delete all Feedback


