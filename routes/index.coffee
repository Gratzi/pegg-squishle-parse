{ fail, debug, log, errorLog } = require '../lib/common'

request = require 'request-promise'
express = require 'express'
squishle = require '../lib/pegg-squishle'

router = express.Router()

### GET home page. ###
router.get '/', (req, res) ->
  res.render 'index', title: 'Express'

### New Card ###
router.post '/card', (req, res) ->
#  { post_id: '2446', update: '1', categories: '["Playful"]' }
  log req.body

  if req.body?.post_id
    squishle.processCard req.body.post_id, req.body.categories
      .then (result) =>
        res.setHeader 'Content-Type', 'application/json'
        res.send result
      .catch (err) => fail err, res
  else
    res.send()

#    squishle.updateCard req.body
#      .then (result) =>
#        res.setHeader 'Content-Type', 'application/json'
#        res.send result
#      .catch (err) => fail err, res
#  else
#    squishle.createCard req.body
#      .then (result) =>
#        res.setHeader 'Content-Type', 'application/json'
#        res.send result
#      .catch (err) => fail err, res

module.exports = router
