#!/bin/bash
# Instaluje pre-push guard w kazdym lokalnym repo (CORE-HOST, packages, 9 pluginow).
# Idempotentne — bezpieczne do wielokrotnego uruchamiania.

set -euo pipefail

HOOK_SRC="$(dirname "$(realpath "$0")")/git-hooks/pre-push"
[ -f "$HOOK_SRC" ] || { echo "BLAD: brak $HOOK_SRC"; exit 1; }

install_hook() {
  local dir="$1"
  if [ ! -d "$dir/.git" ]; then
    echo "  skip: $dir (nie git repo)"
    return
  fi
  install -m 0755 "$HOOK_SRC" "$dir/.git/hooks/pre-push"
  echo "  ok:   $dir"
}

echo "=== Instalacja pre-push guard ==="
install_hook /home/dadmor/code/obirg-zero/CORE-HOST
install_hook /home/dadmor/code/obirg-zero/packages
for d in /home/dadmor/code/obirg-zero/plugins/plugin-*; do
  install_hook "$d"
done
# Paczki kontentowe BQ — kazda to osobny git repo
if [ -d /home/dadmor/code/obirg-zero/bq-content ]; then
  for d in /home/dadmor/code/obirg-zero/bq-content/*/; do
    [ -d "$d" ] && install_hook "${d%/}"
  done
fi
echo ""
echo "Guard aktywny. Direct 'git push' w tych repo zostanie zablokowany."
echo "Promocja kodu:    bash CORE-HOST/scripts/promote-to-{dev,prod}.sh <target>"
echo "Publikacja paczki: bash CORE-HOST/scripts/bq-pack-publish.sh <nazwa>"
