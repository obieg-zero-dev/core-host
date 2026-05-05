#!/bin/bash
# Promocja LOCAL -> DEV: pcha lokalne HEAD na zdalny dev (staging).
# Walidacja: working tree clean (lub --allow-dirty), build aktualny (dla pluginow).
# Bypass guarda pre-push przez OBIEG_PROMOTE=1.
# Wywoluje WYLACZNIE wlasciciel recznie. LLM ma zakaz uruchamiania.

set -euo pipefail
target="${1:-}"
flag="${2:-}"
[ -z "$target" ] && { echo "Uzycie: $0 <plugin-X|core-host|packages> [--allow-dirty]"; exit 1; }

case "$target" in
  core-host)  dir=/home/dadmor/code/obirg-zero/CORE-HOST ;;
  packages)   dir=/home/dadmor/code/obirg-zero/packages ;;
  plugin-*)   dir="/home/dadmor/code/obirg-zero/plugins/$target" ;;
  *) echo "Nieznany target: $target"; exit 1 ;;
esac

cd "$dir"

# Walidacja 1: working tree clean
if [ "$flag" != "--allow-dirty" ]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "BLAD: $target ma niezacommitowane zmiany. Zacommituj lokalnie albo --allow-dirty."
    git status --short
    exit 1
  fi
fi

# Walidacja 2: dla pluginu — build vs source timestamp
if [[ "$target" == plugin-* ]]; then
  if [ -f src/index.tsx ] && [ -f index.mjs ]; then
    if [ src/index.tsx -nt index.mjs ]; then
      echo "BLAD: $target/src/index.tsx jest nowszy niz index.mjs. Najpierw 'npm run build' w plugins/."
      exit 1
    fi
  fi
fi

branch=$(git symbolic-ref --short HEAD)
echo "[$target] $branch -> origin/dev"
OBIEG_PROMOTE=1 git push --force origin "$branch:dev"
echo "[$target] DEV zaktualizowany. Po walidacji: bash $(dirname "$0")/promote-to-prod.sh $target [vX.Y.Z]"
