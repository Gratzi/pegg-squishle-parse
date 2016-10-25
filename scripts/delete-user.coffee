# Delete:
# User
# UserPrivates
# UserPublics
# UserBesties where user or friend
# Pref where user
# Pegg where user
# Role where name is userId_FacebookFriends and name is userId_Friends
# Card hasPreffed for user
# Pref hasPegged for user

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

deleteUser = ({userId}) ->
  log 'deleting user ', userId
  unless userId.match parse.PARSE_OBJECT_ID
    return @_error "Invalid user ID: #{userId}"

  user = parse._pointer '_User', userId
  parse.findAndDelete type: 'Pegg', field: 'user', value: user

# Promise.all([
#   parse.findAndDelete 'UserPrivates', user: user
#   parse.findAndDelete 'UserPublics', user: user
#   parse.findAndDelete 'UserBesties', user: user
#   parse.findAndDelete 'UserBesties', friend: user
#   parse.findAndDelete 'Pegg', user: user
#   parse.findAndDelete 'Pegg', peggee: user
#   parse.findAndDelete 'Pref', user: user
#   parse.findAndDelete '_Session', user: user
#   parse.findAndDelete '_Role', name: "#{userId}_FacebookFriends"
#   parse.findAndDelete '_Role', name: "#{userId}_Friends"
#   @delete type: '_User', id: userId
#   parse.clearHasPreffed {userId}
#   parse.clearHasPegged {userId}
# ])
#   .then (results) => log 'done', userId, results

deleteUser userId: 'yXeUDJ4nLK'
