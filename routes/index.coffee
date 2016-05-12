debug = require 'debug'
log = debug 'app:log'
errorLog = debug 'app:error'

fail = (err, res) ->
  errorLog err
  if typeof err is 'string'
    msg = err
    err = new Error err
  else
    msg = err.error
  if res?
    res.status(500).send msg
  throw err

express = require 'express'
parse = require '../lib/pegg-parse'
router = express.Router()

validateClient = (secret, res) ->
  if secret isnt CLIENT_SECRET
    fail "invalid client secret, aborting", res

CLIENT_SECRET = process.env.CLIENT_SECRET or fail "cannot have an empty CLIENT_SECRET"

### GET home page. ###
router.get '/', (req, res) ->
  res.render 'index', title: 'Express'

### New Card ###
router.post '/card', (req, res) ->
  validateClient req.body.secret, res
  req.body.secret = undefined

  if req.body?.card?.id
    parse.updateCard req.body
      .then (result) =>
        res.setHeader 'Content-Type', 'application/json'
        res.send result
      .catch (err) => fail err, res
  else
    parse.createCard req.body
      .then (result) =>
        res.setHeader 'Content-Type', 'application/json'
        res.send result
      .catch (err) => fail err, res

module.exports = router
