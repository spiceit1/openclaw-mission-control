#!/bin/bash
# Complete Google Cloud OAuth setup for Gmail push notifications
#
# Required env vars:
#   GMAIL_CLIENT_ID
#   GMAIL_CLIENT_SECRET
#   GMAIL_REFRESH_TOKEN
#   GCP_PROJECT_ID
#
# Run this after setting up a GCP project with Gmail API + Pub/Sub enabled.
# See README.md for full setup instructions.

: "${GMAIL_CLIENT_ID:?Set GMAIL_CLIENT_ID}"
: "${GMAIL_CLIENT_SECRET:?Set GMAIL_CLIENT_SECRET}"
: "${GMAIL_REFRESH_TOKEN:?Set GMAIL_REFRESH_TOKEN}"
: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"

echo "Testing OAuth token refresh..."
GMAIL_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$GMAIL_CLIENT_ID" \
  -d "client_secret=$GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))")

if [ -z "$GMAIL_TOKEN" ]; then
  echo "ERROR: Could not get access token. Check your credentials."
  exit 1
fi

echo "Token obtained. Testing Gmail API access..."
PROFILE=$(curl -s -H "Authorization: Bearer $GMAIL_TOKEN" \
  "https://gmail.googleapis.com/gmail/v1/users/me/profile")

echo "$PROFILE" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'emailAddress' in d:
    print(f'Authenticated as: {d[\"emailAddress\"]}')
    print(f'Messages total: {d.get(\"messagesTotal\", \"?\")}')
else:
    print('Error:', d.get('error', {}).get('message', str(d)))
    sys.exit(1)
"
