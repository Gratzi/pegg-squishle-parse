# Squishle <-> Parse

Move cards from squishle.me to pegg-parse-server

This app originally forked from: https://github.com/LonnyGomes/node-ssl-demo

## Development

```
heroku plugins:install heroku-pipelines
heroku git:remote -a pegg-squishle-parse
```

Run it like:

```
PARSE_APP_ID='asdf' PARSE_MASTER_KEY='asdf' PARSE_SERVER_URL='qwer' CLIENT_SECRET='asdf' PORT=3003 DEBUG='app:*' npm run start
```
