debug = require 'debug'
log = debug 'app:log'
errorLog = debug 'app:error'
fail = (msg) ->
  errorLog msg
  throw new Error msg

express = require 'express'
parse = require '../lib/pegg-parse'
router = express.Router()

validateClient = (secret) ->
  if secret isnt CLIENT_SECRET
    fail "invalid client secret, aborting"

CLIENT_SECRET = process.env.CLIENT_SECRET or fail "cannot have an empty CLIENT_SECRET"

### GET home page. ###
router.get '/', (req, res) ->
  res.render 'index', title: 'Express'

### New Card ###
router.post '/card', (req, res) ->
  validateClient req.body.secret
  req.body.secret = undefined
  if req.body?.card?.objectId
    parse.updateCard req.body
  else
    parse.createCard req.body

  # for friendId in req.body.friends
  #   firebase.child('inbound').child(friendId).push
  #     dts: req.body.dts
  #     type: 'friendsUpdate'
  #     friendId: req.body.userId
  # firebase.child('inbound').child(req.body.userId).push
  #   dts: req.body.dts
  #   type: 'friendsUpdate'
  #
  #
  # msg = "submitting new user notification to firebase: "+ JSON.stringify req.body
  # log msg
  # res.send msg


module.exports = router
