#!/bin/bash

set -euo pipefail

if [[ -z "${BUILDKITE_API_ACCESS_TOKEN:-}" ]]; then
  echo "You must set the BUILDKITE_API_ACCESS_TOKEN environment variable (e.g. BUILDKITE_API_ACCESS_TOKEN = \"xyz\")"
  exit 1
fi

if [[ -z "${PIPELINE:-}" ]]; then
  echo "You must set the PIPELINE environment variable (e.g. PIPELINE = \"my-org/my-pipeline\")"
  exit 1
fi

ORG_SLUG=$(echo "${PIPELINE}" | cut -d'/' -f1)
PIPELINE_SLUG=$(echo "${PIPELINE}" | cut -d'/' -f2)

COMMIT="${COMMIT:-${GITHUB_SHA}}"
BRANCH="${BRANCH:-${GITHUB_REF#"refs/heads/"}}"
MESSAGE="${MESSAGE:-}"

NAME=$(jq -r ".pusher.name" "$GITHUB_EVENT_PATH")
EMAIL=$(jq -r ".pusher.email" "$GITHUB_EVENT_PATH")

COMMIT=$(jq -r ".pull_request.head.sha" "$GITHUB_EVENT_PATH")
BRANCH=$(jq -r ".pull_request.head.ref" "$GITHUB_EVENT_PATH")
PR_NUMBER=$(jq -r ".number" "$GITHUB_EVENT_PATH")

echo "Triggering build on branch $BRANCH for commit $COMMIT and PR $PR_NUMBER"

# Use jq’s --arg properly escapes string values for us
JSON=$(
  jq -c -n \
    --arg COMMIT  "$COMMIT" \
    --arg BRANCH  "$BRANCH" \
    --arg MESSAGE "$MESSAGE" \
    --arg NAME    "$NAME" \
    --arg EMAIL   "$EMAIL" \
    --arg PR_NUMBER "$PR_NUMBER" \
    '{
      "commit": $COMMIT,
      "branch": $BRANCH,
      "message": $MESSAGE,
      "author": {
        "name": $NAME,
        "email": $EMAIL
      },
      "env": {
        "BUILDKITE_PULL_REQUEST": $PR_NUMBER
      }
    }'
)

curl \
  -X POST \
  -H "Authorization: Bearer ${BUILDKITE_API_ACCESS_TOKEN}" \
  "https://api.buildkite.com/v2/organizations/${ORG_SLUG}/pipelines/${PIPELINE_SLUG}/builds" \
  -d "$JSON"
