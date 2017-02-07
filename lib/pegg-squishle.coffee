{ fail, pretty, debug, log, errorLog } = require '../lib/common'
_ = require 'lodash'
Promise = require('parse/node').Promise
request = require 'request-promise'
WP = require 'wpapi' # https://github.com/WP-API/node-wpapi
Entities = require('html-entities').AllHtmlEntities # https://www.npmjs.com/package/html-entities
parse = require '../lib/pegg-parse'
AWS = require 'aws-sdk'

entities = new Entities()

SQUISHLE_USERNAME = process.env.SQUISHLE_USERNAME or fail "cannot have an empty SQUISHLE_USERNAME"
SQUISHLE_PASSWORD = process.env.SQUISHLE_PASSWORD or fail "cannot have an empty SQUISHLE_PASSWORD"

wp = new WP (
  endpoint: 'http://squishle.me/wp-json'
  username: SQUISHLE_USERNAME
  password: SQUISHLE_PASSWORD
  auth: true
)

gifIdPattern = /[\/-]([^\/?-]+)($|\?)/

class PeggSquishle
  #card =
  #  question: 'Some question'
  #  deck: 'Throwback'
  #  choices: [
  #    {text: "first choice", image: {source:"https://media1.giphy.com/media/lppjX4teaSUnu/giphy.gif", url:""}},
  #    {text: "second choice", image:{source:"https://media1.giphy.com/media/lppjX4teaSUnu/giphy.gif", url:""}},
  #    {text:"third choice", image:{source:"https://media1.giphy.com/media/lppjX4teaSUnu/giphy.gif", url:""}},
  #    {text:"fourth choice", image:{source:"https://media1.giphy.com/media/lppjX4teaSUnu/giphy.gif", url:""}}
  #  ]
  processCard: (postId, categories) =>
    log "creating card from post: #{postId}"
    post = null
    @fetchPostData postId
    .then (_post) => post = _post
    .then @fetchImageData
    .catch (errors) =>
      errorLog errors.toString()
      content = post.content
      if content?.choices?
        if errors.isArray
          for error in errors
            if error?.choice?.num?
              squishleChoice = _.find content.choices, (c) -> c.num is error.choice.num
              squishleChoice.error = error.message
        else
          content.error = errors.toString()
      else
        content = error: errors.toString()
      debug "updating post with error", content
      @updatePost postId, JSON.stringify content
      throw errors
    .then (card) =>
      if categories?
        card.deck = JSON.parse(categories)?[0]
      if card.id?
        @updateCard card
          .then (result) =>
            log "card updated: ", pretty result
            @updatePost postId, JSON.stringify result
            @backupImages card.choices
      else
        @createCard card
          .then (result) =>
            log "card created: ", pretty result
            @updatePost postId, JSON.stringify result
            @backupImages card.choices
            @incrementDeck card.deck

  backupImages: (choices) =>
    s3 = new AWS.S3()
    for own id, choice of choices
      do (id, choice) =>
        # download image to buffer
        request.get uri: choice.image.url, encoding: null
        .then (body) =>
          log "downloaded image for choice", choice.id
          # upload to s3
          s3.putObject {
            Bucket: 'images.pegg.us'
            Key: choice.id + '.mp4'
            Metadata:
              sourceUrl: choice.image.url
            Body: body
          }, (error, data) =>
            if error? then errorLog "aws error", error, error.stack
            else log "aws success", data
        .catch errorLog

  fetchPostData: (postId) =>
    log "fetching squishle post details for #{postId}"
    wp.posts().id(postId).get()
    .catch (err) => console.log err
    .then (result) =>
      console.log result
      post = {}
      post.choices = []
      post.post = postId
      post.question = entities.decode result.title.rendered
      unless _.isEmpty result.content?.rendered
        defuckedRenderedContent = entities.decode(result.content.rendered.replace(/<(?:.|\n)*?>/gm, '')).replace(/[“”″]/gm, '"')
        content = JSON.parse(defuckedRenderedContent)
        if content?
          post.content = content
        if content?.cardId?
          post.id = content.cardId
        if content?.choices?
          content.choices = _.sortBy content.choices, 'num'
          _.each content.choices, (c) -> delete c.error if c.error
      for i in [1..4]
        choice = {}
        choice.gifUrl = result["gif#{i}"]
        choice.text = result["answer#{i}"]
        choice.num = i
        if content?.choices?[i-1]?.id?
          choice.id = content.choices[i-1].id
        post.choices.push choice
      console.log JSON.stringify post
      return post

  fetchImageData: (card) =>
    Promise.when(
      for choice in card.choices then do (choice) =>
        if choice.gifUrl.indexOf("imgur.com/a/") > -1
          @fetchImgurAlbumData choice
        else if choice.gifUrl.indexOf("imgur.com/gallery/") > -1
          @fetchImgurGalleryData choice
        else if choice.gifUrl.indexOf("imgur.com/") > -1
          @fetchImgurImageData choice
        else
          error = new Error "Invalid URL for gif #{choice.gifUrl}"
          errorLog error
          error.choice = choice
          throw error
    ).then (choices) =>
      console.log pretty choices
      card.choices = choices
      card

  fetchImgurAlbumData: (choice) =>
    log "fetching imgur details for album #{choice.gifUrl}"
    albumId = gifIdPattern.exec(choice.gifUrl)?[1]
    console.log "albumId: #{albumId}"
    props =
      url: 'https://api.imgur.com/3/album/' + albumId
      headers:
        Authorization: 'Client-ID f2400da11df9695'
      json: true
    request props
      .catch (error) => errorLog error
      .then (result) =>
        debug "IMGUR: " + pretty result
        unless result?.data?.images?[0]?
          error = new Error "No result from imgur for album [#{albumId}]"
          errorLog error
          error.choice = choice
          throw error
        choice.image =
          url: result.data.images[0].mp4
          source: choice.gifUrl
        unless choice.image.url?
          error = new Error "Invalid Imgur URL for gif #{choice.image.source}"
          errorLog error
          error.choice = choice
          throw error
        choice

  fetchImgurGalleryData: (choice) =>
    log "fetching imgur details for gallery image #{choice.gifUrl}"
    imageOrAlbumId = gifIdPattern.exec(choice.gifUrl)?[1]
    console.log "imageOrAlbumId: #{imageOrAlbumId}"
    props =
      url: 'https://api.imgur.com/3/gallery/' + imageOrAlbumId
      headers:
        Authorization: 'Client-ID f2400da11df9695'
      json: true
    request props
      .catch (error) => errorLog error
      .then (result) =>
        debug "IMGUR: " + pretty result
        unless result?
          error = new Error "No result from imgur for gif [#{imageOrAlbumId}]"
          errorLog error
          error.choice = choice
          throw error
        if result.data.is_album
          choice.image =
            url: result.data.images[0].mp4
            source: choice.gifUrl
        else
          choice.image =
            url: result.data.mp4
            source: choice.gifUrl
        unless choice.image.url?
          error = new Error "Invalid Imgur URL for gif #{choice.image.source}"
          errorLog error
          error.choice = choice
          throw error
        choice

  fetchImgurImageData: (choice) =>
    log "fetching imgur details for image #{choice.gifUrl}"
    imageId = gifIdPattern.exec(choice.gifUrl)?[1]
    console.log "imageId: #{imageId}"
    props =
      url: 'https://api.imgur.com/3/image/' + imageId
      headers:
        Authorization: 'Client-ID f2400da11df9695'
      json: true
    request props
      .catch (error) => errorLog error
      .then (result) =>
        debug "IMGUR: " + pretty result
        unless result?.data?
          error = new Error "No result from imgur for album [#{imageId}]"
          errorLog error
          error.choice = choice
          throw error
        choice.image =
          url: result.data.mp4
          source: choice.gifUrl
        unless choice.image.url?
          error = new Error "Invalid Imgur URL for gif #{choice.image.source}"
          errorLog error
          error.choice = choice
          throw error
        choice

  # fetchGiphyData: (choice) =>
  #   log "fetching giphy details for #{choice.gifId}"
  #   props =
  #     url: 'http://api.giphy.com/v1/gifs/' + choice.gifId
  #     qs:
  #       api_key: 'dc6zaTOxFJmzC'
  #     json: true
  #   request props
  #     .catch (error) => errorLog error
  #     .then (result) =>
  #       choice.image =
  #         url: result.data.images.original.url
  #         source: result.data.source_post_url
  #       choice

  incrementDeck: (deck) =>
    parse.getBy {type: "Deck", field: "name", value: deck}
    .then (parseDeck) =>
      parse.increment {type: "Deck", id: parseDeck.id, field: "count", num: 1}
    .then (result) =>
      console.log "#{deck} deck incremented"

  createCard: (post) =>
    card = {}
    cardId = null
    parseCard = null
    card.choices = undefined
    card.deck = post.deck
    card.question = post.question
    card.ACL = "*": read: true
    card.publishDate = new Date()
    parse.create type: 'Card', object: card
    .then (result) =>
      parseCard = result
      cardId = parseCard.id
      Promise.when(
        for choice in post.choices then do (choice, cardId) =>
          choice.card = parse.pointer type: 'Card', id: cardId
          choice.ACL = "*": read: true
          parse.create type: 'Choice', object: choice
      )
    .then (parseChoices) =>
      for choice, i in post.choices
        choice.id = parseChoices[i].id
        choice.cardId = cardId
        choice.card = undefined
        choice.ACL = undefined
      card.choices = _.keyBy post.choices, 'id'
      prunedChoices = _.cloneDeep card.choices
      for own id, choice of prunedChoices
        if _.isEmpty choice.text
          delete prunedChoices[id]
      parseCard.set 'choices', prunedChoices
      parseCard.save null, { useMasterKey: true }
    .then =>
      debug pretty parseCard
      result =
        cardId: cardId
        choices: _.map card.choices, (choice) => id: choice.id, num: choice.num
      result

  updatePost: (postId, content) =>
    log "updating post: #{postId} #{content}"
    wp.posts().id(postId).update(content: content)
      .catch (err) => console.log err
      .then (result) =>
        console.log result

  updateCard: (card) =>
    cardId = card.id
    console.log "updating card #{cardId}"
    debug pretty card
    choices = card.choices
    Promise.when(
      for choice, i in choices then do (choice, i, cardId) =>
        choice.card = parse.pointer type: 'Card', id: cardId
        choice.ACL = "*": read: true
        # if _.isEmpty choice.id
        #   parse.create type: 'Choice', object: choice
        #   .then (result) =>
        #     choice.id = result.id
        #     choice.cardId = cardId
        #     choice.card = undefined
        #     choice.ACL = undefined
        # else if _.isEmpty choice.text
        #   delete choices[i]
        #   parse.delete type: 'Choice', id: choice.id
        # else
        parse.update type: 'Choice', id: choice.id, object: choice
        .then (result) =>
          choice.cardId = cardId
          choice.card = undefined
          choice.ACL = undefined
    ).then =>
      card.choices = _.keyBy choices, 'id'
      card.ACL = "*": read: true
      parse.update type: 'Card', id: cardId, object: card
    .then =>
      result =
        cardId: cardId
        choices: _.map card.choices, (choice) => id: choice.id, num: choice.num
      result


module.exports = new PeggSquishle
