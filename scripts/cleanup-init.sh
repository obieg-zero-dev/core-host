#!/bin/bash
# Jednorazowy cleanup: doprowadza obieg-zero-dev do stanu, gdzie main = source+bundle (nie sam bundle).
# 1) Ujednolicenie lokalnego brancha do `main` (rename master->main jeśli trzeba)
# 2) Force push main + tagów dla 9 pluginów
# 3) Default branch -> main (przez gh repo edit)
# 4) Odtworzenie branch dev jako kopia main
# 5) Push lokalnych commitów CORE-HOST + packages
#
# DESTRUKCYJNE — force-push do 9 plugin repo. Tylko jednorazowo.

set -euo pipefail

[ "${CONFIRM_DESTRUCTIVE_CLEANUP:-}" = "yes-i-really-want-this" ] || {
  echo "BLAD: destrukcyjny one-shot. Force-push do 9 plugin repo + push CORE-HOST/packages."
  echo "Aby uruchomic: CONFIRM_DESTRUCTIVE_CLEANUP=yes-i-really-want-this bash $0"
  exit 1
}

PLUGINS=(plugin-brain-quest plugin-brain-quest-arena plugin-brain-quest-reader plugin-cosmos-bq plugin-darkmode plugin-data plugin-manager plugin-wibor-calc plugin-workflow-crm)
PLUGINS_DIR="/home/dadmor/code/obirg-zero/plugins"

echo "=== KROK 1/5: Lokalny branch -> main (rename master->main jeśli trzeba) ==="
for d in "${PLUGINS[@]}"; do
  cd "$PLUGINS_DIR/$d"
  br=$(git symbolic-ref --short HEAD)
  if [ "$br" != "main" ]; then
    git branch -m "$br" main
    echo "  $d: $br -> main"
  else
    echo "  $d: main (bez zmian)"
  fi
done

echo ""
echo "=== KROK 2/5: Force push source + tagi do obieg-zero-dev/plugin-X main ==="
for d in "${PLUGINS[@]}"; do
  echo "--- $d ---"
  cd "$PLUGINS_DIR/$d"
  git fetch origin --no-tags --prune 2>&1 | sed 's/^/  fetch: /'
  git push --force origin main 2>&1 | sed 's/^/  push main: /'
  git push --force origin --tags 2>&1 | sed 's/^/  push tags: /'
done

echo ""
echo "=== KROK 3/5: Default branch -> main ==="
for d in "${PLUGINS[@]}"; do
  gh repo edit "obieg-zero-dev/$d" --default-branch main 2>&1 | sed 's/^/  /' || echo "  $d: skip"
done

echo ""
echo "=== KROK 4/5: Odtworzenie branch dev jako kopia main ==="
for d in "${PLUGINS[@]}"; do
  cd "$PLUGINS_DIR/$d"
  git branch -f dev main
  git push --force origin dev 2>&1 | sed 's/^/  '"$d"': /'
done

echo ""
echo "=== KROK 5/5: Push CORE-HOST + packages (lokalne commity) ==="
cd /home/dadmor/code/obirg-zero/CORE-HOST && git push origin master 2>&1 | sed 's/^/  CORE-HOST: /'
cd /home/dadmor/code/obirg-zero/packages && git push origin main 2>&1 | sed 's/^/  packages: /'

echo ""
echo "=== DONE ==="
