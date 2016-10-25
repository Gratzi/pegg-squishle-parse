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

{ fail, pretty, debug, log, errorLog } = require '../lib/common'

Promise = require('parse/node').Promise
parse = require '../lib/pegg-parse'
request = require 'request-promise'

PARSE_APP_ID = process.env.PARSE_APP_ID or fail "cannot have an empty PARSE_APP_ID"
PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY or fail "cannot have an empty PARSE_MASTER_KEY"
PARSE_SERVER_URL = process.env.PARSE_SERVER_URL or fail "cannot have an empty PARSE_SERVER_URL"

deleteUser = ({userId}) ->
  log 'deleting user ', userId
  unless userId.match parse.PARSE_OBJECT_ID
    return @_error "Invalid user ID: #{userId}"

  user = parse.pointer type: '_User', id: userId

  Promise.all([
    parse.findAndDelete type: 'UserPrivates', field: 'user', value: user
    parse.findAndDelete type: 'UserPublics', field: 'user', value: user
    parse.findAndDelete type: 'Bestie', field: 'user', value: user
    parse.findAndDelete type: 'Bestie', field: 'friend', value: user
    parse.findAndDelete type: 'Pegg', field: 'user', value: user
    parse.findAndDelete type: 'Pegg', field: 'peggee', value: user
    parse.findAndDelete type: 'Pref', field: 'user', value: user
    parse.findAndDelete type: '_Session', field: 'user', value: user
    parse.findAndDelete type: '_Role', field: 'name', value: "#{userId}_FacebookFriends"
    parse.findAndDelete type: '_Role', field: 'name', value: "#{userId}_Friends"
    parse.delete type: '_User', id: userId
    parse.clearHasPreffed {userId}
    parse.clearHasPegged {userId}
  ])
  .then (results) => log 'done', userId, results

deleteUser userId: 'yXeUDJ4nLK'
