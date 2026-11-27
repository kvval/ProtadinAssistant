#!/usr/bin/env bash
# Show what the packager did for a release tag (CurseForge upload result etc.).
# Usage: tools/release_log.sh v1.0.5
# Uses the GitHub login stored in Git Credential Manager (job logs need repo admin).
set -euo pipefail
TAG="${1:?tag, e.g. v1.0.5}"
REPO=kvval/ProtadinAssistant
TOK=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>/dev/null | sed -n 's/^password=//p')
[ -n "$TOK" ] || { echo "no GitHub credentials"; exit 1; }
RUN=$(curl -s "https://api.github.com/repos/$REPO/actions/runs?per_page=20" \
  | python3 -c "import sys,json; r=[w for w in json.load(sys.stdin)['workflow_runs'] if w['head_branch']=='$TAG']; print(r[0]['id'] if r else '')")
[ -n "$RUN" ] || { echo "no workflow run for $TAG"; exit 1; }
JOB=$(curl -s "https://api.github.com/repos/$REPO/actions/runs/$RUN/jobs" | python3 -c "import sys,json; j=json.load(sys.stdin)['jobs'][0]; print(j['id'], j['conclusion'])")
echo "run $RUN, job ${JOB% *}: ${JOB#* }"
curl -sL -H "Authorization: Bearer $TOK" "https://api.github.com/repos/$REPO/actions/jobs/${JOB% *}/logs" \
  | sed -E 's/^[0-9T:.-]+Z //' | grep -i -E "game version|curseforge|uploading|success|error|fail" || true
