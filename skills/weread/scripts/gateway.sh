#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <flat-json-body>\n' "$0" >&2
  exit 2
fi

for required_command in curl jq sed; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$required_command" >&2
    exit 127
  fi
done

skill_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
skill_version=$(sed -nE 's/^[[:space:]]*version:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$/\1/p' "$skill_directory/SKILL.md")

if [[ -z "$skill_version" ]]; then
  printf 'Unable to read the skill version from SKILL.md\n' >&2
  exit 2
fi

if [[ -z "${WEREAD_TOKEN:-}" ]]; then
  printf 'WEREAD_TOKEN is not available\n' >&2
  exit 3
fi

request_body=$(jq -ce --arg version "$skill_version" '
  if type != "object" then
    error("request body must be a JSON object")
  elif ((.api_name? | type) != "string") or (.api_name | length) == 0 then
    error("api_name must be a non-empty string")
  else
    .skill_version = $version
  end
' <<< "$1")

response=$(curl --fail-with-body -sS -X POST \
  "https://i.weread.qq.com/api/agent/gateway" \
  -H "Authorization: Bearer ${WEREAD_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "$request_body")

printf '%s\n' "$response"

if jq -e '(.upgrade_info? // null) != null' >/dev/null <<< "$response"; then
  exit 42
fi

if jq -e '(.errcode? // 0) != 0' >/dev/null <<< "$response"; then
  exit 1
fi
