#!/bin/bash
# Sends a pipeline notification to Telegram.
# Usage: notify.sh "message text"
#
# Credentials come from the environment (GitLab CI/CD variables, masked + protected).
# Fallback: a file on the runner, readable only by gitlab-runner (chmod 600),
# for GitLab instances where project CI/CD variables are not available.
set -euo pipefail

MESSAGE="${1:-}"
if [ -z "$MESSAGE" ]; then
  echo "Usage: $0 \"message text\"" >&2
  exit 1
fi

SECRETS_FILE="${TELEGRAM_SECRETS_FILE:-/home/gitlab-runner/.secrets/telegram.env}"
if { [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; } && [ -f "$SECRETS_FILE" ]; then
  # shellcheck disable=SC1090
  source "$SECRETS_FILE"
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "ERROR: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not set" >&2
  exit 1
fi

# --data-urlencode: message text may contain &, + or # from commit data
RESPONSE=$(curl -sS --max-time 10 -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MESSAGE}" \
  --data-urlencode "parse_mode=HTML")

# Telegram answers HTTP 200/4xx with {"ok":true|false,...}; a bad token must fail the job
if ! printf '%s' "$RESPONSE" | grep -q '"ok":true'; then
  echo "ERROR: Telegram API rejected the message: ${RESPONSE}" >&2
  exit 1
fi

echo "Notification sent: ${MESSAGE}"
