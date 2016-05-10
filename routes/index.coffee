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
  res.setHeader('Content-Type', 'application/json');
  validateClient req.body.secret
  req.body.secret = undefined

  if req.body?.card?.objectId
    parse.updateCard req.body
    res.send 'Updated'
  else
    parse.createCard req.body
    res.send 'Created'


module.exports = router
