#!/bin/bash
set -euo pipefail

# Query the Delinea Secret Server API for a specific secret and extract
# the username and password field values.
#
# Prerequisites:
#   - curl and jq installed
#   - A valid API bearer token supplied via the BEARER_TOKEN environment variable
#
# Configuration (override via environment variables):
#   SECRET_SERVER_URL - base URL of the Secret Server (no trailing slash)
#   SECRET_ID         - numeric ID of the secret to retrieve
#   BEARER_TOKEN      - OAuth2 bearer token for API authentication

SECRET_SERVER_URL="${SECRET_SERVER_URL:-https://norwood.secretservercloud.com}"
SECRET_ID="${SECRET_ID:-75}"
: "${BEARER_TOKEN:?Set BEARER_TOKEN to the external API bearer token before running}"

# BEARER TOKEN is supplied via environment, NOT this file!
# Configure before running.
#   export BEARER_TOKEN="<out-of-band bearer token>"

# Retrieve the secret. e.g. https://{{SecretServerURL}}/api/v2/secrets/75
RESPONSE="$(curl -fsSL \
  -H "Authorization: Bearer ${BEARER_TOKEN}" \
  -H "Accept: application/json" \
  "${SECRET_SERVER_URL}/api/v2/secrets/${SECRET_ID}")"

# Secret Server returns the field values in the "items" array, each item
# identified by its "slug" (e.g. "username", "password").
AWS_ACCESS_KEY_ID="$(echo "$RESPONSE" | jq -r '.items[] | select(.slug == "access-key") | .itemValue')"
AWS_SECRET_ACCESS_KEY="$(echo "$RESPONSE" | jq -r '.items[] | select(.slug == "secret-key") | .itemValue')"

if [[ -z "$AWS_ACCESS_KEY_ID" || "$AWS_ACCESS_KEY_ID" == "null" ]]; then
  echo "Error: could not extract AWS_ACCESS_KEY_ID from secret ${SECRET_ID}" >&2
  exit 1
fi
if [[ -z "$AWS_SECRET_ACCESS_KEY" || "$AWS_SECRET_ACCESS_KEY" == "null" ]]; then
  echo "Error: could not extract AWS_SECRET_ACCESS_KEY from secret ${SECRET_ID}" >&2
  exit 1
fi

echo "Retrieved secret ${SECRET_ID}"
echo "Configuring AWS CLI options using AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}..."

# Configure AWS CLI with provided credentials and region
AWS_REGION="${AWS_REGION:-us-east-1}"
#AWS_ACCESS_KEY_ID="<access-key-value-foo>"
#AWS_SECRET_ACCESS_KEY="<secret-key-value-foo>"

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set region "$AWS_REGION"

# Validate AWS CLI credentials
echo "Validating AWS CLI credentials..."
aws sts get-caller-identity