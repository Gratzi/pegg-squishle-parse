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
PARSE_APP_ID='asdf' PARSE_MASTER_KEY='asdf' PARSE_SERVER_URL='qwer' CLIENT_SECRET='asdf' SQUISHLE_USERNAME='xxx' SQUISHLE_PASSWORD='xxx'  AWS_ACCESS_KEY_ID='xxx' AWS_SECRET_ACCESS_KEY='xxx' PORT=3003 DEBUG='app:*' npm run start
```

Or copy `.env.example` to `.env`, enter your deets, and run it like:

```
npm run start
```

Test locally:
```
curl -X POST http://localhost:3000/card --data "post_id=603&categories=[\"Naughty\"]"
```

## Scripts

```
DEBUG=* coffee bin/[whatever]
```
