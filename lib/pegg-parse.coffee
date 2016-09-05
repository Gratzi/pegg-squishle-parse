Parse = require('parse/node')
Promise = Parse.Promise
_ = require 'lodash'
debugLib = require 'debug'
log = debugLib 'app:log'
debug = debugLib 'app:debug'
errorLog = debugLib 'app:error'
request = require 'request-promise'

fail = (msg) ->
  error = new Error msg
  errorLog error
  throw error

PARSE_OBJECT_ID = /^[0-z]{8,10}$/
PARSE_MAX_RESULTS = 1000

PARSE_APP_ID = process.env.PARSE_APP_ID or fail "cannot have an empty PARSE_APP_ID"
PARSE_MASTER_KEY = process.env.PARSE_MASTER_KEY or fail "cannot have an empty PARSE_MASTER_KEY"
PARSE_SERVER_URL = process.env.PARSE_SERVER_URL or fail "cannot have an empty PARSE_SERVER_URL"

class PeggParse
  constructor: ->
    Parse.initialize PARSE_APP_ID, null, PARSE_MASTER_KEY
    Parse.serverURL = PARSE_SERVER_URL

  _pointer: (type, id) ->
    throw new Error "pointer type required" unless type?
    throw new Error "pointer object ID required" unless id?
    parseObject = new Parse.Object type
    parseObject.id = id
    parseObject

  get: ({type, id}) ->
    query = new Parse.Query type
    query.equalTo 'objectId', id
    query.first { useMasterKey: true }
      .then (result) =>
        log 'message', "got #{type} #{id}"
        debug @pretty result
        result

  create: ({type, object}) ->
    log 'message', "creating #{type}"
    debug @pretty object
    parseObject = new Parse.Object type
    for key, val of object
      parseObject.set key, val
    parseObject.save null, { useMasterKey: true }
      .then (result) =>
        log 'message', "created #{type} #{result.id}"
        debug @pretty result
        result

  update: ({type, id, object}) ->
    log 'message', "updating #{type} #{id}"
    debug @pretty object
    @get {type, id}
      .then (parseObject) =>
        unless parseObject?
          throw "object not found"
        for key, val of object
          parseObject.set key, val
        parseObject.save null, { useMasterKey: true }
      .then (result) =>
        log 'message', "updated #{type} #{id}"
        debug @pretty result
        result

  delete: ({type, id}) ->
    parseObject = @_pointer type, id
    parseObject.destroy { useMasterKey: true }
      .then (result) =>
        log 'message', "deleted #{type} #{id}"
        debug @pretty result
        result

  updateCard: ({card}) =>
    cardId = card.id
    console.log "updating card #{cardId}"
    debug @pretty card
    card = card
    choices = card.choices
    Promise.when(
      for choice, i in choices then do (choice, i, cardId) =>
        choice.card = @_pointer 'Card', cardId
        @fetchGifphyDetails choice.gifId
          .then (giphyDetails) =>
            choice.image = giphyDetails
            choice.ACL = "*": read: true
            if _.isEmpty choice.id
              @create type: 'Choice', object: choice
                .then (result) =>
                  choice.id = result.id
                  choice.cardId = cardId
                  choice.card = undefined
                  choice.ACL = undefined
            else if _.isEmpty choice.text
              delete choices[i]
              @delete type: 'Choice', id: choice.id
            else
              @update type: 'Choice', id: choice.id, object: choice
                .then (result) =>
                  choice.cardId = cardId
                  choice.card = undefined
                  choice.ACL = undefined
    ).then =>
      card.choices = _.keyBy choices, 'id'
      card.ACL = "*": read: true
      @update type: 'Card', id: cardId, object: card
    .then =>
      log "updated card #{cardId}"
      result =
        cardId: cardId
        choices: _.map card.choices, 'id'
      log "result:", @pretty result
      result

  #card =
  #  question: 'Some question'
  #  deck: 'Throwback'
  #  choices: [
  #    {text: "first choice", image: {source:"https://media1.giphy.com/media/lppjX4teaSUnu/giphy.gif", url:""}},
  #    {text: "second choice", image:{source:"https://media1.giphy.com/media/lppjX4teaSUnu/giphy.gif", url:""}},
  #    {text:"third choice", image:{source:"https://media1.giphy.com/media/lppjX4teaSUnu/giphy.gif", url:""}},
  #    {text:"fourth choice", image:{source:"https://media1.giphy.com/media/lppjX4teaSUnu/giphy.gif", url:""}}
  #  ]
  createCard: (postId, category) =>
    log "creating card"
    @fetchPostData postId
      .then (post) =>
        cardId = null
        parseCard = null
        card = {}
        choices = [
          {"text": post.answer1, "image": {"url": post.gif1}},
          {"text": post.answer2, "image": {"url": post.gif2}},
          {"text": post.answer3, "image": {"url": post.gif3}},
          {"text": post.answer4, "image": {"url": post.gif4}}
        ]
        card.question = post.title.rendered
        card.deck = category
        card.choices = undefined
        card.ACL = "*": read: true
        card.publishDate = new Date()
        @create type: 'Card', object: card
          .then (result) =>
            parseCard = result
            cardId = parseCard.id
            Promise.when(
              for choice in choices then do (choice, cardId) =>
                choice.card = @_pointer 'Card', cardId
                choice.ACL = "*": read: true
                @create type: 'Choice', object: choice
            )
          .then (parseChoices) =>
            for choice, i in choices
              choice.id = parseChoices[i].id
              choice.cardId = cardId
              choice.card = undefined
              choice.ACL = undefined
            card.choices = _.keyBy choices, 'id'
            parseCard.set 'choices', card.choices
            parseCard.save null, { useMasterKey: true }
          .then =>
            log "created card #{cardId}"
            debug @pretty parseCard
            result =
              cardId: cardId
              choices: _.map card.choices, 'id'
            log "result:", @pretty result
            result

  fetchGifphyDetails: (gifId) =>
    log "fetching giphy details for #{gifId}"
    props =
      url: 'http://api.giphy.com/v1/gifs/' + gifId
      qs:
        api_key: 'dc6zaTOxFJmzC'
      json: true
    request props
      .catch (error) => errorLog error
      .then (result) =>
        url: result.data.images.original.url
        source: result.data.source_post_url

  fetchPostData: (postId) =>
    log "fetching squishle post details for #{postId}"
    props =
      url: 'http://squishle.me/wp-json/wp/v2/post/' + postId
      json: true
    request props
      .catch (error) => errorLog error
      .then (result) =>
        console.log JSON.stringify result
        return result

  createCosmicUnicorn: ->
    # { "results": [
    #     {
    #         "ACL": {
    #             "*": {
    #                 "read": true
    #             },
    #             "role:vVTsQaGIu2_Friends": {
    #                 "read": true
    #             },
    #             "vVTsQaGIu2": {
    #                 "read": true,
    #                 "write": true
    #             }
    #         },
    #         "age_range": {
    #             "min": 21
    #         },
    #         "avatar_url": "https://graph.facebook.com/100006151097293/picture",
    #         "facebook_id": "100006151097293",
    #         "first_name": "Cosmic",
    #         "gender": "male",
    #         "isActive": true,
    #         "last_name": "Unicorn",
    #         "last_pref_date": {
    #             "__type": "Date",
    #             "iso": "2016-05-07T00:05:28.867Z"
    #         },
    #         "objectId": "vVTsQaGIu2",
    #         "username": "cosmic"
    #     }
    # ] }

  pretty: (thing) ->
    JSON.stringify thing, null, 2

  # updateBatchRecursive: (requests, offset) ->
  #   newOffset = offset + 50 # max batch size
  #   @_parse.batchAsync _.slice requests, offset, newOffset
  #     .then (results) =>
  #       if results?.length > 0
  #         log 'update', results
  #         @updateBatchRecursive requests, newOffset
  #
  # # list: ({type, limit}) ->
  # #   if limit? and limit > PARSE_MAX_RESULTS
  # #     @findRecursive type, PARSE_MAX_RESULTS, 0
  # #       .then (results) => log 'done', results
  # #       .catch (error) => log 'error', error
  # #   else
  # #     @_parse.findManyAsync type, limit
  # #       .then (results) => log 'done', results
  # #       .catch (error) => log 'error', error
  #
  # findRecursive: (type, query) ->
  #   @_parse.findAsync type, query
  #     .then (data) =>
  #       if data?.results?.length > 0
  #         log 'fetch', data.results
  #         query.skip += query.limit
  #         @findRecursive type, query
  #
  # deleteCard: ({cardId}) ->
  #   unless cardId.match PARSE_OBJECT_ID
  #     return @_error "Invalid card ID: #{cardId}"
  #
  #   card = @_pointer 'Card', cardId
  #
  #   Promise.all([
  #     @clearCardFromFriendship card
  #     @delete type: 'Card', id: cardId
  #     @_findAndDelete 'Choice', card: card
  #     @_findAndDelete 'Comment', card: card
  #     @_findAndDelete 'Favorite', card: card
  #     @_findAndDelete 'Frown', card: card
  #     @_findAndDelete 'Pegg', card: card
  #     @_findAndDelete 'Pref', card: card
  #   ])
  #     .then (results) => log 'done', cardId, results
  #
  # clearCardFromFriendship: (card) =>
  #   cardId = card.objectId
  #   @_getTable 'Friendship'
  #     .then (friendships) =>
  #       log 'message', "got #{friendships.length} friendships"
  #       log 'message', "clearing card #{cardId} from friendships"
  #       # make a bunch of sub-promises that resolve when the row is successfully cleared, and
  #       # return a promise that resolves iff all of the rows were cleared, otherwise fails
  #       Promise.all(
  #         for friendship in friendships
  #           originalFriendship = _.cloneDeep friendship
  #           _.pull friendship.cardsMatched, cardId
  #           _.pull friendship.cardsPegged, cardId
  #           _.pull friendship.prefsMatched, cardId
  #           friendship.cardsMatchedCount = friendship.cardsMatched.length
  #           friendship.cardsPeggedCount = friendship.cardsPegged.length
  #           friendship.prefsMatchedCount = friendship.prefsMatched.length
  #           unless _.isEqual friendship, originalFriendship
  #             @_parse.updateAsync 'Friendship', friendship.objectId, friendship
  #               .then do (cardId, friendship) => =>
  #                 log 'message', "cleared cardsMatched, cardsPegged, and prefsMatched for card #{cardId} from friendship: #{friendship.objectId}"
  #           else null
  #       )
  #
  # deleteUser: ({userId}) ->
  #   unless userId.match PARSE_OBJECT_ID
  #     return @_error "Invalid user ID: #{userId}"
  #
  #   user = @_pointer '_User', userId
  #
  #   Promise.all([
  #     # XXX If we want to enable (optionally) resetting user to pristine state, como
  #     # recién nacido, then we'd include the following items:
  #     #
  #     @_findAndDelete 'Comment', author: user
  #     @_findAndDelete 'Comment', peggee: user
  #     @_findAndDelete 'Favorite', user: user
  #     @_findAndDelete 'Friendship', user: user
  #     @_findAndDelete 'Friendship', friend: user
  #     @_findAndDelete 'Flag', peggee: user
  #     @_findAndDelete 'Flag', user: user
  #     @_findAndDelete 'Frown', user: user
  #     @_findAndDelete 'Pegg', user: user
  #     @_findAndDelete 'Pegg', peggee: user
  #     @_findAndDelete 'Pref', user: user
  #     @_findAndDelete 'SupportComment', author: user
  #     @_findAndDelete 'SupportComment', peggee: user
  #     @_findAndDelete 'UserMood', user: user
  #     @_findAndDelete 'UserSetting', user: user
  #     #
  #     # Also:
  #     # - find all cards made by user then @deleteCard
  #     # - if we wanted to be really thorough we'd collect IDs and counts for Peggs
  #     #   we delete and decrement PeggCounts
  #     #
  #     # To totally nuke the user, also include:
  #     #
  #     @delete type: '_User', id: userId
  #     @_findAndDelete '_Session', user: user
  #     @_findAndDelete '_Role', name: "#{userId}_FacebookFriends"
  #     @_findAndDelete '_Role', name: "#{userId}_Friends"
  #     @_findAndDelete 'UserPrivates', user: user
  #     #
  #     @_findAndDelete 'Pref', user: user
  #     @_findAndDelete 'Pegg', user: user
  #     @_findAndDelete 'Pegg', peggee: user
  #     @clearHasPreffed {userId}
  #     @clearHasPegged {userId}
  #   ])
  #     .then (results) => log 'done', userId, results
  #
  # resetUser: ({userId}) ->
  #   unless userId.match PARSE_OBJECT_ID
  #     return @_error "Invalid user ID: #{userId}"
  #
  #   user = @_pointer '_User', userId
  #
  #   Promise.all([
  #     # XXX If we want to enable (optionally) resetting user to pristine state, como
  #     # recién nacido, then we'd include the following items:
  #     #
  #     # @_findAndDelete 'Activity', user: user
  #     # @_findAndDelete 'Activity', friend: user
  #     # @_findAndDelete 'Comment', author: user
  #     # @_findAndDelete 'Comment', peggee: user
  #     # @_findAndDelete 'Favorite', user: user
  #     # @_findAndDelete 'Flag', peggee: user
  #     # @_findAndDelete 'Flag', user: user
  #     # @_findAndDelete 'Frown', user: user
  #     # @_findAndDelete 'Pegg', user: user
  #     # @_findAndDelete 'Pegg', peggee: user
  #     # @_findAndDelete 'Pref', user: user
  #     # @_findAndDelete 'SupportComment', author: user
  #     # @_findAndDelete 'SupportComment', peggee: user
  #     # @_findAndDelete 'UserMood', user: user
  #     # @_findAndDelete 'UserSetting', user: user
  #     #
  #     # Also:
  #     # - find all cards made by user then @deleteCard
  #     # - if we wanted to be really thorough we'd collect IDs and counts for Peggs
  #     #   we delete and decrement PeggCounts
  #     #
  #     # To totally nuke the user, also include:
  #     #
  #     # @delete type: 'User', id: userId
  #     # @_findAndDelete 'Session', user: user
  #     # @_findAndDelete 'UserPrivates', user: user
  #     #
  #     @_findAndDelete 'Pref', user: user
  #     @_findAndDelete 'Pegg', user: user
  #     @_findAndDelete 'Pegg', peggee: user
  #     @clearHasPreffed {userId}
  #     @clearHasPegged {userId}
  #   ])
  #     .then (results) => log 'done', userId, results
  #
  # clearHasPreffed: ({userId}) =>
  #   # get all the cards, and return a promise
  #   @_getTable 'Card'
  #     .then (results) =>
  #       log 'message', "clearing hasPreffed from #{results.length} cards for user #{userId}"
  #       # make a bunch of sub-promises that resolve when the row is successfully cleared, and
  #       # return a promise that resolves iff all of the rows were cleared, otherwise fails
  #       Promise.all(
  #         for card in results
  #           if card.hasPreffed?.indexOf(userId) > -1
  #             card.hasPreffed = _.uniq(card.hasPreffed).splice userId, 1
  #             @_parse.updateAsync 'Card', card.objectId, card
  #               .then =>
  #                 log 'message', "cleared hasPreffed from card: #{card.objectId}"
  #       )
  #
  # clearHasPegged: ({userId}) =>
  #   # get all the cards, and return a promise
  #   @_getTable 'Pref'
  #     .then (results) =>
  #       log 'message', "clearing hasPegged from #{results.length} prefs for user #{userId}"
  #       # make a bunch of sub-promises that resolve when the row is successfully cleared, and
  #       # return a promise that resolves iff all of the rows were cleared, otherwise fails
  #       Promise.all(
  #         for pref in results
  #           if pref.hasPegged?.indexOf(userId) > -1
  #             pref.hasPegged = _.uniq(pref.hasPegged).splice userId, 1
  #             @_parse.updateAsync 'Pref', pref.objectId, pref
  #               .then =>
  #                 log 'message', "cleared hasPegged from pref: #{pref.objectId}"
  #       )
  #
  # updateBesties: =>
  #   @_getTable 'Pegg'
  #     .then (results) =>
  #       byUser = _.groupBy results, (pegg) => pegg.user.objectId
  #       for own userId, resultsByUser of byUser
  #         # console.log "results for user #{userId}"
  #         byPeggee = _.groupBy resultsByUser, (pegg) => pegg.peggee.objectId
  #         for own peggeeId, resultsByPeggee of byPeggee
  #           # console.log "results for peggee #{peggeeId}"
  #           byCard = _.groupBy resultsByPeggee, (pegg) => pegg.card.objectId
  #           cardsPlayed = 0
  #           score = 0
  #           for own cardId, resultsByCard of byCard
  #             # console.log "results for card #{cardId}"
  #             cardsPlayed++
  #             tryCount = _.reduce resultsByCard, ((sum) => sum+1), -1
  #             if tryCount > 3 then tryCount = 3
  #             score += 10 - 3 * tryCount
  #           console.log "create bestie: user: #{userId}, peggee: #{peggeeId}, cards: #{cardsPlayed}, score: #{score}"
  #           bestie =
  #             ACL:
  #               "#{userId}": read: true
  #               "role:#{userId}_Friends": read: true
  #             cards: cardsPlayed
  #             score: score
  #             user: @_pointer '_User', userId
  #             friend: @_pointer '_User', peggeeId
  #           @create type: 'Bestie', object: bestie
  #             .error (e) =>
  #               console.error e
  #               log 'error', e
  #
  # # migrateImagesToS3: ->
  # #   @_getTable 'Choice'
  # #     .then (results) =>
  # #       for item in results when not _.isEmpty(item.image)
  # #         urlFilePath = item.image.match( /[^\/]+(#|\?|$)/ ) or 'foo'
  # #         filename = "#{item.objectId}_#{urlFilePath[0]}"
  # #         item.original = item.image
  # #         # console.log "#{url}, #{id}, #{filename}"
  # #         @_storeImageFromUrl item, filename, "/premium/big/"
  # #           .then (results) =>
  # #             bigBlob = results.blob
  # #             item = results.item
  # #             console.log "bigBlob: ", bigBlob
  # #
  # #             try
  # # #              log 'message', "uploaded choiceId: #{id}, url: #{url}"
  # #               bigBlob = JSON.parse bigBlob
  # #             catch
  # #               message = bigBlob + ', choiceId: ' + item.objectId + ', url: ' + item.image
  # #               log 'error',
  # #                 message: message
  # #                 stack: new Error(message).stack
  # #
  # #             @_createThumbnail item, bigBlob
  # #               .error (error) =>
  # #                 log 'error', error
  # #               .then (results) =>
  # #                 console.log JSON.stringify(results)
  # #                 try
  # #                   smallBlob = JSON.parse results.blob
  # #                   item = results.item
  # #                   blob =
  # #                     small: smallBlob.key
  # #                     big: bigBlob.key
  # #                     meta:
  # #                       id: item.objectId
  # #                       url: item.image
  # #                       original: item.original
  # #                       source: item.imageSource
  # #                       credit: item.imageCredit
  # #                     type: 'premium'
  # #                   console.log "blob: ", blob
  # #                   choice = {blob}
  # #                   return @update type: 'Choice', id: item.objectId, object: choice
  # #                     .then (res) =>
  # #                       log 'message', "updated choice #{item.objectId}"
  # #                 catch error
  # #                   message = "#{error}, choiceId: #{item.objectId}, url: #{item.image}, smallBlob: #{JSON.stringify(smallBlob)}"
  # #                   log 'error',
  # #                     message: message
  # #                     stack: new Error(message).stack
  # #
  # # _storeImageFromUrl: (item, filename, path) ->
  # #   new Promise (resolve, reject) =>
  # #     command = "curl -X POST -d url='#{item.image}' 'https://www.filepicker.io/api/store/S3?key=#{@filePickerId}&path=#{path + filename}'"
  # #     console.log "command:", command
  # #     exec command, (error, stdout, stderr) =>
  # #       resolve { item: item, blob: stdout }
  # #
  # # _createThumbnail: (item, inkBlob) ->
  # #   new Promise (resolve, reject) =>
  # #     item.image = inkBlob.url + "/convert?format=jpg&w=375&h=667"
  # #     filename = "#{item.objectId}_#{inkBlob.filename}"
  # #     resolve @_storeImageFromUrl item, filename, "/premium/small/"
  #
  # _getTable: (type) ->
  #   log 'message', "getting table #{type}"
  #   @_getRows type, 1000, 0
  #
  # _getRows: (type, limit, skip, _res = []) ->
  #   @_parse.findManyAsync type, "?limit=#{limit}&skip=#{skip}"
  #     .then (data) =>
  #       console.log "Got records #{skip} - #{skip + limit} for #{type}"
  #       if data?.results?.length > 0
  #         for item in data.results
  #           _res.push item
  #         @_getRows type, limit, skip + limit, _res
  #       else
  #         _res
  #
  # _findAndDelete: (type, conditions) ->
  #   if _.isEmpty(conditions)
  #     return @_error "conditions should not be empty"
  #   # find items for these conditions, and return a promise
  #   @_parse.findAsync type, where: conditions
  #     .then (data) =>
  #       log 'message', "found #{data?.results?.length} #{type} items where #{@_pretty conditions}"
  #       # make a bunch of sub-promises that resolve when the row is successfully deleted, and
  #       # return a promise that resolves iff all of the rows were deleted, otherwise fails
  #       Promise.all(
  #         for item in data?.results
  #           @delete type: type, id: item.objectId
  #       )
  #
  #
  # _error: (message) ->
  #   error = { message: message, stack: new Error(message).stack }
  #   Promise.reject error

module.exports = new PeggParse
