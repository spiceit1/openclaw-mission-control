#!/bin/bash
# Renew Gmail push watch (expires every 7 days)
# Called by cron daily
#
# Required env vars (set these before running):
#   GMAIL_CLIENT_ID
#   GMAIL_CLIENT_SECRET
#   GMAIL_REFRESH_TOKEN
#   GCP_PROJECT_ID
#   PUBSUB_TOPIC (defaults to "gmail-push")

: "${GMAIL_CLIENT_ID:?Set GMAIL_CLIENT_ID}"
: "${GMAIL_CLIENT_SECRET:?Set GMAIL_CLIENT_SECRET}"
: "${GMAIL_REFRESH_TOKEN:?Set GMAIL_REFRESH_TOKEN}"
: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"
PUBSUB_TOPIC="${PUBSUB_TOPIC:-gmail-push}"

GMAIL_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$GMAIL_CLIENT_ID" \
  -d "client_secret=$GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))")

RESULT=$(curl -s -X POST "https://gmail.googleapis.com/gmail/v1/users/me/watch" \
  -H "Authorization: Bearer $GMAIL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"topicName\": \"projects/$GCP_PROJECT_ID/topics/$PUBSUB_TOPIC\",
    \"labelIds\": [\"INBOX\"]
  }")

echo "$RESULT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'historyId' in d:
    import datetime
    exp = datetime.datetime.fromtimestamp(int(d['expiration'])/1000)
    print(f'Gmail watch renewed! Expires: {exp}')
else:
    print('Error:', d.get('error', {}).get('message', str(d)))
    exit(1)
"
