debug = require 'debug'
log = debug 'app:log'
errorLog = debug 'app:error'

fail = (err) ->
  if typeof err is 'string'
    err = new Error err
  errorLog err
  throw err

parse = require '../lib/pegg-parse'
request = require 'request'

PARSE_APP_ID = process.env.PARSE_APP_ID or fail "cannot have an empty PARSE_APP_ID"
PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY or fail "cannot have an empty PARSE_MASTER_KEY"
PARSE_SERVER_URL = process.env.PARSE_SERVER_URL or fail "cannot have an empty PARSE_SERVER_URL"

deleteAll = (type) ->
  log "deleting all #{type}s"
  headers = {
    'Content-Type': 'application/json'
    'X-Parse-Application-Id': PARSE_APP_ID
    'X-Parse-Master-Key': PARSE_MASTER_KEY
  }
  request.del {
    headers: headers,
    url: "#{PARSE_SERVER_URL}/purge/#{type}",
    json: true
  }, (err, res, body) =>
    if err? then errorLog err
    else if body.error?
      errorLog body.error
    else log body

deleteAll 'Pref'
deleteAll 'Pegg'
deleteAll 'Bestie'
# - clear from Users: prefCounts, prefCount, peggCounts, peggCount, failCount, lastActiveDate
# - clear from Cards: hasPreffed
# - clear from Choice: prefCount
#
# optional - nuke all users
# - delete all Users
# - delete all UserPrivates
# - delete all UserPublics
# - delete all Roles
# - delete all Sessions
# - delete all Feedback
