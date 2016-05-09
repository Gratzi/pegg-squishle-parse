debug = require 'debug'
log = debug 'app:log'
errorLog = debug 'app:error'
fail = (msg) ->
  errorLog msg
  throw new Error msg

Firebase = require 'firebase'
FirebaseTokenGenerator = require 'firebase-token-generator'

FIREBASE_SECRET = process.env.FIREBASE_SECRET or fail "cannot have an empty FIREBASE_SECRET"
FIREBASE_UID = process.env.FIREBASE_UID or fail "cannot have an empty FIREBASE_UID"
FIREBASE_URL = process.env.FIREBASE_URL or fail "cannot have an empty FIREBASE_URL"

class PeggFirebaseClient extends Firebase
  constructor: ->
    super FIREBASE_URL
    tokenGenerator = new FirebaseTokenGenerator FIREBASE_SECRET
    token = tokenGenerator.createToken {uid: FIREBASE_UID} #, {admin: true, expires: 2272147200}
    @authWithCustomToken token, (error, auth) =>
      if error?
        errorLog error, auth
      else
        log 'Login to Firebase successful'

module.exports = new PeggFirebaseClient
