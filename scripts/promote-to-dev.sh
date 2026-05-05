#!/bin/bash
# Promocja LOCAL -> DEV: pcha lokalne main na zdalny dev (staging).
# Użycie: bash scripts/promote-to-dev.sh <plugin-X|core-host|packages>
# Wywołuje WYŁĄCZNIE właściciel ręcznie. LLM ma zakaz uruchamiania tego skryptu.

set -euo pipefail
target="${1:-}"
[ -z "$target" ] && { echo "Użycie: $0 <plugin-X|core-host|packages>"; exit 1; }

case "$target" in
  core-host)  cd /home/dadmor/code/obirg-zero/CORE-HOST ;;
  packages)   cd /home/dadmor/code/obirg-zero/packages ;;
  plugin-*)   cd "/home/dadmor/code/obirg-zero/plugins/$target" ;;
  *) echo "Nieznany target: $target"; exit 1 ;;
esac

branch=$(git symbolic-ref --short HEAD)
echo "[$target] $branch -> origin/dev"
git push --force-with-lease origin "$branch:dev"
