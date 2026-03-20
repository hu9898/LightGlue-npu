#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/codex_auto_commit.sh [-m "summary"] "prompt"
  cat prompt.txt | scripts/codex_auto_commit.sh [-m "summary"]

Description:
  Run one non-interactive Codex task for this repository and create at most
  one local Git commit when files change.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command not found: $1"
  fi
}

sanitize_summary() {
  local raw="$1"
  local sanitized
  sanitized="$(
    printf '%s' "$raw" \
      | tr '\n' ' ' \
      | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
  )"

  if [[ -z "$sanitized" ]]; then
    sanitized="update from codex"
  fi

  printf '%.72s' "$sanitized"
}

derive_summary_from_prompt() {
  local prompt="$1"
  local first_line
  first_line="$(
    printf '%s\n' "$prompt" \
      | sed -n '/[^[:space:]]/ { s/^[[:space:]]*//; p; q; }'
  )"
  sanitize_summary "$first_line"
}

MESSAGE=""
POSITIONAL_PROMPT=""

while (($# > 0)); do
  case "$1" in
    -m|--message)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      MESSAGE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      if (($# > 0)); then
        POSITIONAL_PROMPT="$*"
      fi
      break
      ;;
    *)
      POSITIONAL_PROMPT="${POSITIONAL_PROMPT:+$POSITIONAL_PROMPT }$1"
      shift
      ;;
  esac
done

require_command git

CODEX_BIN="${CODEX_BIN:-codex}"
require_command "$CODEX_BIN"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$REPO_ROOT" ]] || fail "unable to resolve repository root from script location"

if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "this script must run inside a Git working tree"
fi

if [[ -n "$POSITIONAL_PROMPT" ]]; then
  PROMPT_CONTENT="$POSITIONAL_PROMPT"
elif [[ ! -t 0 ]]; then
  PROMPT_CONTENT="$(cat)"
else
  usage
  fail "provide a prompt as an argument or via stdin"
fi

[[ -n "$PROMPT_CONTENT" ]] || fail "prompt is empty"

if [[ -z "$MESSAGE" ]]; then
  MESSAGE="$(derive_summary_from_prompt "$PROMPT_CONTENT")"
else
  MESSAGE="$(sanitize_summary "$MESSAGE")"
fi

STATUS_BEFORE="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)"
if [[ -n "$STATUS_BEFORE" ]]; then
  printf 'Repository is not clean. Resolve the following entries before using automatic commit:\n' >&2
  printf '%s\n' "$STATUS_BEFORE" >&2
  exit 1
fi

PROMPT_FILE="$(mktemp /tmp/codex-auto-commit.XXXXXX)"
cleanup() {
  rm -f "$PROMPT_FILE"
}
trap cleanup EXIT
printf '%s' "$PROMPT_CONTENT" > "$PROMPT_FILE"

printf 'Repository: %s\n' "$REPO_ROOT"
printf 'Summary: %s\n' "$MESSAGE"
printf 'Running: %s exec -C %s -\n' "$CODEX_BIN" "$REPO_ROOT"

set +e
"$CODEX_BIN" exec -C "$REPO_ROOT" - < "$PROMPT_FILE"
CODEX_STATUS=$?
set -e

STATUS_AFTER="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)"
if [[ -z "$STATUS_AFTER" ]]; then
  printf 'No file changes detected; no commit created.\n'
  exit "$CODEX_STATUS"
fi

if [[ "$CODEX_STATUS" -eq 0 ]]; then
  COMMIT_TITLE="codex: $MESSAGE"
else
  COMMIT_TITLE="codex-wip: $MESSAGE"
fi

git -C "$REPO_ROOT" add -A
git -C "$REPO_ROOT" commit -m "$COMMIT_TITLE"
COMMIT_HASH="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
printf 'Created commit: %s (%s)\n' "$COMMIT_HASH" "$COMMIT_TITLE"

exit "$CODEX_STATUS"
