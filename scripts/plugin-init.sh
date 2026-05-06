#!/bin/bash
# Inicjalizacja nowego pluginu obieg-zero:
#  1. sprawdza plugins/<name>/ ma src/index.tsx + package.json
#  2. git init + pre-push hook
#  3. initial commit
#  4. gh repo create obieg-zero-dev/<name> --private --source=. --remote=origin
#  5. push origin/main + origin/dev (przez OBIEG_PROMOTE=1)
#
# Wywoluje WYLACZNIE wlasciciel recznie. LLM ma zakaz uruchamiania.
#
# Uzycie: bash plugin-init.sh <plugin-name>
# Przyklad: bash plugin-init.sh plugin-bq-loader

set -euo pipefail

name="${1:-}"
[ -z "$name" ] && { echo "Uzycie: $0 <plugin-name>"; exit 1; }
[[ "$name" == plugin-* ]] || { echo "BLAD: plugin musi miec prefiks 'plugin-' (jest: $name)"; exit 1; }

ROOT="/home/dadmor/code/obirg-zero/plugins"
HOOK_SRC="$(dirname "$(realpath "$0")")/git-hooks/pre-push"
dir="$ROOT/$name"

[ -d "$dir" ] || { echo "BLAD: brak katalogu $dir (najpierw stworz pliki pluginu)"; exit 1; }
[ -f "$dir/src/index.tsx" ] || { echo "BLAD: brak $dir/src/index.tsx"; exit 1; }
[ -f "$dir/package.json" ] || { echo "BLAD: brak $dir/package.json"; exit 1; }

cd "$dir"

if [ ! -d .git ]; then
  echo "[$name] git init"
  git init -q -b main
  [ -f "$HOOK_SRC" ] && install -m 0755 "$HOOK_SRC" .git/hooks/pre-push
fi

# Initial commit jesli brak commits albo sa zmiany
if ! git log --oneline -1 >/dev/null 2>&1; then
  git add -A
  git commit -q -m "Init: $name"
elif ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  git add -A
  git commit -q -m "Update: $name (init phase)"
fi

# Description z package.json (lub nazwa)
desc=$(node -p "require('./package.json').description || '$name'" 2>/dev/null || echo "$name")

# gh repo create jesli nie istnieje
if ! gh repo view "obieg-zero-dev/$name" >/dev/null 2>&1; then
  echo "[$name] tworze repo obieg-zero-dev/$name (private)"
  gh repo create "obieg-zero-dev/$name" --private --source=. --remote=origin --description "$desc" >/dev/null
elif ! git remote get-url origin >/dev/null 2>&1; then
  echo "[$name] dodaje remote origin"
  git remote add origin "git@github.com:obieg-zero-dev/$name.git"
fi

echo "[$name] push origin/main"
OBIEG_PROMOTE=1 git push -u origin main

echo "[$name] push origin/dev"
OBIEG_PROMOTE=1 git push -f origin main:dev

echo "[$name] OK — plugin opublikowany. Kolejne zmiany przez 'oz promote dev $name'."
