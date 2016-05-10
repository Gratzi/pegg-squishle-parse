# Squishle <-> Parse

When actions by a user spawns notifications to multiple other users, we use this tool to update Firebase.

E.g. when a user creates a card, all that user's friends must be notified.

This app originally forked from: https://github.com/LonnyGomes/node-ssl-demo

## Development

```
heroku plugins:install heroku-pipelines
heroku git:remote -a pegg-squishle-parse
```

Run it like:

```
PARSE_APP_ID='asdf' PARSE_MASTER_KEY='asdf' CLIENT_SECRET='asdf' PORT=3003 DEBUG='app:*' npm run start
```
