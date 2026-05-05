#!/bin/bash
# Jednorazowy cleanup: doprowadza obieg-zero-dev do stanu, gdzie main = source+bundle (nie sam bundle).
# Force push lokalnego main + tagów dla 9 pluginów, default branch -> main, push CORE-HOST + packages,
# odtworzenie branch dev jako kopii main.

set -euo pipefail

PLUGINS=(plugin-brain-quest plugin-brain-quest-arena plugin-brain-quest-reader plugin-cosmos-bq plugin-darkmode plugin-data plugin-manager plugin-wibor-calc plugin-workflow-crm)
PLUGINS_DIR="/home/dadmor/code/obirg-zero/plugins"

echo "=== KROK 1/4: Force push source + tagi do obieg-zero-dev/plugin-X main ==="
for d in "${PLUGINS[@]}"; do
  echo "--- $d ---"
  cd "$PLUGINS_DIR/$d"
  git push --force-with-lease origin main --tags 2>&1 | sed 's/^/  /'
done

echo ""
echo "=== KROK 2/4: Default branch -> main ==="
for d in "${PLUGINS[@]}"; do
  gh repo edit "obieg-zero-dev/$d" --default-branch main 2>&1 | sed 's/^/  /' || echo "  $d: skip"
done

echo ""
echo "=== KROK 3/4: Odtworzenie branch dev jako kopia main ==="
for d in "${PLUGINS[@]}"; do
  cd "$PLUGINS_DIR/$d"
  git branch -f dev main 2>&1 | sed 's/^/  /'
  git push --force origin dev 2>&1 | sed 's/^/  /'
done

echo ""
echo "=== KROK 4/4: Push CORE-HOST + packages (lokalne commity) ==="
cd /home/dadmor/code/obirg-zero/CORE-HOST && git push origin master 2>&1 | sed 's/^/  CORE-HOST: /'
cd /home/dadmor/code/obirg-zero/packages && git push origin main 2>&1 | sed 's/^/  packages: /'

echo ""
echo "=== DONE ==="
