#!/bin/bash
# Promocja DEV -> PROD: ff-merge dev na main + opcjonalny tag vX.Y.Z + push.
# Wymaga ze origin/dev istnieje (musi byc wczesniej promote-to-dev).
# Bypass guarda pre-push przez OBIEG_PROMOTE=1.
# Wywoluje WYLACZNIE wlasciciel recznie. LLM ma zakaz uruchamiania.

set -euo pipefail
target="${1:-}"
tag="${2:-}"
[ -z "$target" ] && { echo "Uzycie: $0 <plugin-X|core-host|packages> [vX.Y.Z]"; exit 1; }

case "$target" in
  core-host)  dir=/home/dadmor/code/obirg-zero/CORE-HOST ;;
  packages)   dir=/home/dadmor/code/obirg-zero/packages ;;
  plugin-*)   dir="/home/dadmor/code/obirg-zero/plugins/$target" ;;
  *) echo "Nieznany target: $target"; exit 1 ;;
esac

cd "$dir"
git fetch origin --no-tags

# Walidacja: tag musi byc semver
if [ -n "$tag" ] && ! [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "BLAD: tag '$tag' nie jest semver (oczekiwane: vMAJOR.MINOR.PATCH)"
  exit 1
fi

# Walidacja: origin/dev istnieje
if ! git show-ref --verify --quiet refs/remotes/origin/dev; then
  echo "BLAD: $target nie ma origin/dev. Najpierw promote-to-dev.sh."
  exit 1
fi

echo "[$target] origin/dev -> origin/main"
OBIEG_PROMOTE=1 git push --force origin "refs/remotes/origin/dev:refs/heads/main"

if [ -n "$tag" ]; then
  git tag -f "$tag" "origin/dev"
  OBIEG_PROMOTE=1 git push --force origin "$tag"
  echo "[$target] PROD: tag $tag"
else
  echo "[$target] PROD (bez taga)"
fi
