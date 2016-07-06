debug = require 'debug'
log = debug 'app:log'
errorLog = debug 'app:error'

fail = (err) ->
  if typeof err is 'string'
    err = new Error err
  errorLog err
  throw err

express = require 'express'
parse = require '../lib/pegg-parse'
router = express.Router()

### GET home page. ###
router.get '/', (req, res) ->
  res.render 'index', title: 'Express'

### New Card ###
router.post '/card', (req, res) ->
  log req.body
  res.send 200

#  if req.body?.card?.id
#    parse.updateCard req.body
#      .then (result) =>
#        res.setHeader 'Content-Type', 'application/json'
#        res.send result
#      .catch (err) => fail err, res
#  else
#    parse.createCard req.body
#      .then (result) =>
#        res.setHeader 'Content-Type', 'application/json'
#        res.send result
#      .catch (err) => fail err, res

module.exports = router
