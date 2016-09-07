debug = require 'debug'
log = debug 'app:log'
errorLog = debug 'app:error'
request = require 'request-promise'

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

  if req.body?.content?
    console.log req.body?.content
  else if req.body?.post_id
    parse.createCard req.body.post_id, req.body.categories
      .then (result) =>
        res.setHeader 'Content-Type', 'application/json'
        res.send result
      .catch (err) => fail err, res
  else
    res.send()

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
