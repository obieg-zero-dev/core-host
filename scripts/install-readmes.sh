#!/bin/bash
# Generuje README.md dla kazdego pluginu z templatu i commituje LOKALNIE (bez push).
# Po commicie: bash promote-to-dev.sh plugin-X i promote-to-prod.sh plugin-X.

set -euo pipefail

TEMPLATE="$(dirname "$(realpath "$0")")/templates/PLUGIN_README.md"
[ -f "$TEMPLATE" ] || { echo "BLAD: brak $TEMPLATE"; exit 1; }

PLUGINS=(plugin-brain-quest plugin-brain-quest-arena plugin-brain-quest-reader plugin-cosmos-bq plugin-darkmode plugin-data plugin-manager plugin-wibor-calc plugin-workflow-crm)
PLUGINS_DIR="/home/dadmor/code/obirg-zero/plugins"

echo "=== Generowanie README.md per plugin ==="
for d in "${PLUGINS[@]}"; do
  cd "$PLUGINS_DIR/$d"
  sed "s/{{PLUGIN_NAME}}/$d/g" "$TEMPLATE" > README.md
  if git diff --quiet README.md && ! git ls-files --error-unmatch README.md >/dev/null 2>&1; then
    git add README.md
    git commit -m "docs: README z workflow LOCAL->DEV->PROD" 2>&1 | sed 's/^/  '"$d"': /'
  elif ! git diff --quiet README.md; then
    git add README.md
    git commit -m "docs: aktualizacja README (workflow LOCAL->DEV->PROD)" 2>&1 | sed 's/^/  '"$d"': /'
  else
    echo "  $d: README bez zmian"
  fi
done
echo ""
echo "DONE. README zacommitowane lokalnie. Push:"
echo "  for d in ${PLUGINS[*]}; do bash $(dirname "$(realpath "$0")")/promote-to-dev.sh \$d; done"
echo "  for d in ${PLUGINS[*]}; do bash $(dirname "$(realpath "$0")")/promote-to-prod.sh \$d; done"
