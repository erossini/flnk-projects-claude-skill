#!/usr/bin/env bash
# flnk-plan.sh — POSIX mirror of flnk-plan.ps1. Same seven subcommands, same env.
# Use on macOS / Linux / WSL where PowerShell isn't installed.
#
# Env: FLNKIT_API_KEY (required), FLNKIT_API_BASE (default https://flnk.it),
#      FLNKIT_AGENT_ID (default claude-code), FLNKIT_INSECURE=1 (curl -k for dev)

set -euo pipefail

API_KEY="${FLNKIT_API_KEY:-}"
API_BASE="${FLNKIT_API_BASE:-https://flnk.it}"
API_BASE="${API_BASE%/}"
AGENT_ID="${FLNKIT_AGENT_ID:-claude-code}"

if [ -z "$API_KEY" ]; then
    echo >&2 "FLNKIT_API_KEY not set. Generate one at $API_BASE/Account/Manage/ApiKeys with the 'projects' scope ticked."
    exit 2
fi

CURL_OPTS=(--silent --show-error --fail-with-body
           -H "X-Api-Key: $API_KEY"
           -H "Accept: application/json"
           -H "Content-Type: application/json; charset=utf-8")

if [ "${FLNKIT_INSECURE:-}" = "1" ] || echo "$API_BASE" | grep -q localhost; then
    CURL_OPTS+=(--insecure)
fi

call() {
    # Usage: call METHOD PATH [BODY]
    local method=$1 path=$2 body=${3:-}
    if [ -n "$body" ]; then
        curl "${CURL_OPTS[@]}" -X "$method" --data "$body" "$API_BASE$path"
    else
        curl "${CURL_OPTS[@]}" -X "$method" "$API_BASE$path"
    fi
}

# Tiny JSON escaper for primitives. For multi-line / structured bodies
# (the plan endpoint), we cat the file in directly.
json_escape() {
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

cmd=${1:-}
shift || true

case "$cmd" in
    list)
        call GET /api/projects
        ;;
    context)
        proj=${1:?Usage: context <projectId>}
        call GET "/api/projects/$proj/context"
        ;;
    plan)
        proj=${1:?Usage: plan <projectId> <planJsonPath>}
        plan=${2:?Usage: plan <projectId> <planJsonPath>}
        [ -f "$plan" ] || { echo >&2 "Plan file not found: $plan"; exit 2; }
        call POST "/api/projects/$proj/plan" "$(cat "$plan")"
        ;;
    start)
        proj=${1:?Usage: start <projectId> <workItemId> [summary]}
        wi=${2:?Usage: start <projectId> <workItemId> [summary]}
        summary=${3:-}
        body="{\"agentId\":$(json_escape "$AGENT_ID"),\"summary\":$(json_escape "$summary")}"
        call POST "/api/projects/$proj/work-items/$wi/agent-run/start" "$body"
        ;;
    complete)
        proj=${1:?Usage: complete <projectId> <workItemId> <runId> [narrativePath]}
        wi=${2:?Usage: complete <projectId> <workItemId> <runId> [narrativePath]}
        run=${3:?Usage: complete <projectId> <workItemId> <runId> [narrativePath]}
        narr_path=${4:-}
        if [ -n "$narr_path" ]; then
            [ -f "$narr_path" ] || { echo >&2 "Narrative file not found: $narr_path"; exit 2; }
            narr=$(cat "$narr_path")
            body="{\"narrative\":$(json_escape "$narr"),\"skipReview\":false}"
        else
            body='{"skipReview":false}'
        fi
        call POST "/api/projects/$proj/work-items/$wi/agent-run/$run/complete" "$body"
        ;;
    block)
        proj=${1:?Usage: block <projectId> <workItemId> <runId> <reason>}
        wi=${2:?Usage: block <projectId> <workItemId> <runId> <reason>}
        run=${3:?Usage: block <projectId> <workItemId> <runId> <reason>}
        reason=${4:?reason is required}
        body="{\"reason\":$(json_escape "$reason")}"
        call POST "/api/projects/$proj/work-items/$wi/agent-run/$run/block" "$body"
        ;;
    assigned)
        proj=${1:?Usage: assigned <projectId> [agentId]}
        # Default to the configured agent identifier when the caller doesn't override.
        whose=${2:-$AGENT_ID}
        # urlencode the assignee — agent ids may contain dashes / dots that are
        # safe but a future "claude/sonnet/4.5" form wouldn't be. Use python's
        # urllib.parse.quote since coreutils doesn't ship a portable encoder.
        whose_encoded=$(printf '%s' "$whose" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')
        call GET "/api/projects/$proj/context?assignee=$whose_encoded&recentItems=200"
        ;;
    attach)
        wi=${1:?Usage: attach <workItemId> <filePath>}
        file=${2:?Usage: attach <workItemId> <filePath>}
        [ -f "$file" ] || { echo >&2 "File not found: $file"; exit 2; }

        # Multipart upload — curl -F handles the boundary + multipart/form-data
        # encoding. We can't reuse the JSON-only call() helper because it sets
        # Content-Type: application/json which would clash with the multipart
        # type curl sets via -F.
        attach_opts=(--silent --show-error --fail-with-body
                     -H "X-Api-Key: $API_KEY"
                     -H "Accept: application/json")
        if [ "${FLNKIT_INSECURE:-}" = "1" ] || echo "$API_BASE" | grep -q localhost; then
            attach_opts+=(--insecure)
        fi
        curl "${attach_opts[@]}" -X POST -F "file=@$file" \
             "$API_BASE/api/projects/work-items/$wi/attachments"
        ;;
    *)
        echo >&2 "Unknown command '$cmd'. Subcommands: list, context, plan, start, complete, block, attach, assigned"
        exit 2
        ;;
esac
