express = require 'express'
path = require 'path'
favicon = require 'serve-favicon'
logger = require 'morgan'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'
require('dotenv').config()
routes = require './routes/index'

app = express()

### redirect to HTTPS in production ###
forceSsl = (req, res, next) ->
  if req.headers['x-forwarded-proto'] != 'https'
    res.redirect(['https://', req.get('Host'), req.url].join(''))
  else
    next()

if app.get('env') == 'production'
  app.use forceSsl

# view engine setup
app.set 'views', path.join __dirname, 'views'
app.set 'view engine', 'jade'

# uncomment after placing your favicon in /public
#app.use(favicon(__dirname + '/public/favicon.ico'));
app.use logger 'dev'
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: false
app.use cookieParser()
app.use express.static path.join(__dirname, 'public')
app.use '/', routes

# error handlers

# catch 404 and forward to error handler
app.use (req, res, next) ->
  err = new Error 'Not Found'
  err.status = 404
  next err

# development error handler
# will print stacktrace
# if app.get('env') == 'development'
#   app.use (err, req, res, next) ->
#     res.setHeader 'Content-Type', 'application/json'
#     res.status err.status or 500
#     res.send
#       message: err.message
#       error: err
#
# production error handler
# no stacktraces leaked to user
app.use (err, req, res, next) ->
  res.setHeader 'Content-Type', 'application/json'
  res.status err.status or 500
  res.send err.message

module.exports = app
