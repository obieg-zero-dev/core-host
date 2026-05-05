#!/bin/bash
# Promocja DEV -> PROD: ff-merge dev na main + tag vX.Y.Z + push.
# Użycie: bash scripts/promote-to-prod.sh <plugin-X|core-host|packages> [vX.Y.Z]
# Wywołuje WYŁĄCZNIE właściciel ręcznie. LLM ma zakaz uruchamiania tego skryptu.

set -euo pipefail
target="${1:-}"
tag="${2:-}"
[ -z "$target" ] && { echo "Użycie: $0 <plugin-X|core-host|packages> [vX.Y.Z]"; exit 1; }

case "$target" in
  core-host)  dir=/home/dadmor/code/obirg-zero/CORE-HOST ;;
  packages)   dir=/home/dadmor/code/obirg-zero/packages ;;
  plugin-*)   dir="/home/dadmor/code/obirg-zero/plugins/$target" ;;
  *) echo "Nieznany target: $target"; exit 1 ;;
esac

cd "$dir"
git fetch origin
git push --force-with-lease origin "origin/dev:main"
if [ -n "$tag" ]; then
  git tag -f "$tag" "origin/dev"
  git push --force origin "$tag"
  echo "[$target] dev -> main, tag $tag"
else
  echo "[$target] dev -> main (bez taga)"
fi
