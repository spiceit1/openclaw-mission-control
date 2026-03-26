#!/bin/bash
# Set up Gmail push notifications via Google Pub/Sub
#
# Prerequisites:
#   1. GCP project with Gmail API and Pub/Sub API enabled
#   2. OAuth 2.0 credentials (client ID, secret, refresh token)
#   3. Pub/Sub topic created and Gmail granted publish access
#
# Required env vars:
#   GMAIL_CLIENT_ID
#   GMAIL_CLIENT_SECRET
#   GMAIL_REFRESH_TOKEN
#   GCP_PROJECT_ID
#   PUBSUB_TOPIC (defaults to "gmail-push")
#
# Setup steps:
#   1. Create GCP project at console.cloud.google.com
#   2. Enable Gmail API + Pub/Sub API
#   3. Create OAuth consent screen + credentials
#   4. Get refresh token via OAuth playground or gcloud CLI
#   5. Create Pub/Sub topic: gcloud pubsub topics create $PUBSUB_TOPIC
#   6. Grant Gmail publish access:
#      gcloud pubsub topics add-iam-policy-binding $PUBSUB_TOPIC \
#        --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" \
#        --role="roles/pubsub.publisher"
#   7. Create Pub/Sub subscription pointing to your webhook URL
#   8. Run this script to activate the watch
#   9. Set up cron to run gmail-watch-renew.sh daily (watch expires every 7 days)

: "${GMAIL_CLIENT_ID:?Set GMAIL_CLIENT_ID}"
: "${GMAIL_CLIENT_SECRET:?Set GMAIL_CLIENT_SECRET}"
: "${GMAIL_REFRESH_TOKEN:?Set GMAIL_REFRESH_TOKEN}"
: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"
PUBSUB_TOPIC="${PUBSUB_TOPIC:-gmail-push}"

echo "Setting up Gmail push notifications..."
echo "  Project: $GCP_PROJECT_ID"
echo "  Topic:   $PUBSUB_TOPIC"

GMAIL_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$GMAIL_CLIENT_ID" \
  -d "client_secret=$GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))")

if [ -z "$GMAIL_TOKEN" ]; then
  echo "ERROR: Could not get access token."
  exit 1
fi

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
    print(f'Gmail watch activated! Expires: {exp}')
    print('Remember to set up daily cron for gmail-watch-renew.sh')
else:
    print('Error:', d.get('error', {}).get('message', str(d)))
    sys.exit(1)
"
