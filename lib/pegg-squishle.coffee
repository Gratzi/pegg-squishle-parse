{ fail, pretty, debug, log, errorLog } = require '../lib/common'
_ = require 'lodash'
Promise = require('parse/node').Promise
request = require 'request-promise'
WP = require 'wpapi' # https://github.com/WP-API/node-wpapi
Entities = require('html-entities').AllHtmlEntities # https://www.npmjs.com/package/html-entities
parse = require '../lib/pegg-parse'

entities = new Entities()

SQUISHLE_USERNAME = process.env.SQUISHLE_USERNAME or fail "cannot have an empty SQUISHLE_USERNAME"
SQUISHLE_PASSWORD = process.env.SQUISHLE_PASSWORD or fail "cannot have an empty SQUISHLE_PASSWORD"

wp = new WP (
  endpoint: 'http://squishle.me/wp-json'
  username: SQUISHLE_USERNAME
  password: SQUISHLE_PASSWORD
  auth: true
)

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
        for error in errors
          if error?.choice?.num?
            squishleChoice = _.find content.choices, (c) -> c.num is error.choice.num
            squishleChoice.error = error.message
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
      else
        @createCard card
          .then (result) =>
            log "card created: ", pretty result
            @updatePost postId, JSON.stringify result
            @incrementDeck card.deck

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
    gifIdPattern = /[\/-]([^\/?-]+)($|\?)/
    Promise.when(
      for choice in card.choices then do (choice) =>
        choice.gifId = gifIdPattern.exec(choice.gifUrl)?[1]
        console.log "gifId: #{choice.gifId}"
        if choice.gifUrl.indexOf("giphy.com") > -1
          @fetchGiphyData choice
        else if choice.gifUrl.indexOf("imgur.com") > -1
          @fetchImgurData choice
        else
          Promise.as choice
    ).then (choices) =>
      console.log pretty choices
      card.choices = choices
      card

  fetchImgurData: (choice) =>
    log "fetching imgur details for #{choice.gifId}"
    props =
      url: 'https://api.imgur.com/3/gallery/' + choice.gifId
      headers:
        Authorization: 'Client-ID f2400da11df9695'
      json: true
    request props
      .catch (error) => errorLog error
      .then (result) =>
#        console.log "IMGUR: " + pretty result
        if result.data.is_album
          choice.image =
            url: result.data.images[0].mp4
            source: result.data.link
        else
          choice.image =
            url: result.data.mp4
            source: "http://imgur.com/#{choice.gifId}"
        unless choice.image.url?
          error = new Error "ERROR: Invalid Imgur URL for gif #{choice.image.source}"
          errorLog error
          error.choice = choice
          throw error
        choice

  fetchGiphyData: (choice) =>
    log "fetching giphy details for #{choice.gifId}"
    props =
      url: 'http://api.giphy.com/v1/gifs/' + choice.gifId
      qs:
        api_key: 'dc6zaTOxFJmzC'
      json: true
    request props
      .catch (error) => errorLog error
      .then (result) =>
        choice.image =
          url: result.data.images.original.url
          source: result.data.source_post_url
        choice

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
