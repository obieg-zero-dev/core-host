#!/bin/bash
# Lokalny commit BEZ push. Argumenty: $1 = ścieżka katalogu z .git, $2 = "file1 file2 ...", $3 = wiadomość
# Użycie:
#   bash scripts/commit-local.sh /home/dadmor/code/obirg-zero/CORE-HOST "public/config.json CLAUDE.md" "msg"
#   bash scripts/commit-local.sh /home/dadmor/code/obirg-zero/plugins/plugin-cosmos-bq "src/index.tsx index.mjs" "msg"
set -euo pipefail
DIR="$1"
FILES="$2"
MSG="$3"
cd "$DIR"
# shellcheck disable=SC2086
git add $FILES
git commit -m "$MSG"
echo "OK: commit lokalny w $DIR"
