debug = require 'debug'
log = debug 'app:log'
errorLog = debug 'app:error'
fail = (msg) ->
  errorLog msg
  throw new Error msg

express = require 'express'
firebase = require '../lib/pegg-firebase-client'
router = express.Router()

validateClient = (secret) ->
  if secret isnt CLIENT_SECRET
    fail "invalid client secret, aborting"

CLIENT_SECRET = process.env.CLIENT_SECRET or fail "cannot have an empty CLIENT_SECRET"

### GET home page. ###
router.get '/', (req, res) ->
  res.render 'index', title: 'Express'


#### New Card Created ###
#router.post '/newCard', (req, res) ->
#  validateClient req.body.secret
#  req.body.secret = undefined
#
#  for friendId in req.body.friends
#    firebase.child(friendId).child('newCard').update
#      "#{req.body.cardId}":
#        userId: req.body.userId
#        dts: req.body.dts
#
#  msg = "submitting new card notification to firebase: "+ JSON.stringify req.body
#  log msg
#  res.send msg

### New User Created ###
router.post '/newUser', (req, res) ->
  validateClient req.body.secret
  req.body.secret = undefined

  for friendId in req.body.friends
    firebase.child('inbound').child(friendId).push
      dts: req.body.dts
      type: 'friendsUpdate'
      friendId: req.body.userId
  firebase.child('inbound').child(req.body.userId).push
    dts: req.body.dts
    type: 'friendsUpdate'


  msg = "submitting new user notification to firebase: "+ JSON.stringify req.body
  log msg
  res.send msg


module.exports = router
