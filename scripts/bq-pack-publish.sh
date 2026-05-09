#!/bin/bash
# Publikacja paczki BQ na GitHub: walidacja + commit lokalny + push do origin/main z tagiem.
# Uzywa OBIEG_PROMOTE=1 zeby ominac pre-push guard.
#
# Wywoluje WYLACZNIE wlasciciel recznie. LLM ma zakaz uruchamiania (pcha do shared infra).
#
# Uzycie:
#   bash bq-pack-publish.sh <nazwa-paczki> [vX.Y.Z | --bump patch|minor|major] [--message "..."]
# Przyklady:
#   bash bq-pack-publish.sh bq-polski-matura-mit v0.1.0 --message "Dodano 3 konteksty"
#   bash bq-pack-publish.sh bq-polski-matura-mit --bump patch    # auto-inkrement z ostatniego taga

set -euo pipefail

name="${1:-}"
[ -z "$name" ] && { echo "Uzycie: $0 <nazwa-paczki> [vX.Y.Z] [--message \"...\"]"; exit 1; }
shift

tag=""
bump=""
message="Update $name"

while [ $# -gt 0 ]; do
  case "$1" in
    v[0-9]*) tag="$1"; shift ;;
    --bump) bump="$2"; shift 2 ;;
    --message) message="$2"; shift 2 ;;
    *) echo "Nieznana opcja: $1"; exit 1 ;;
  esac
done

if [ -n "$tag" ] && [ -n "$bump" ]; then
  echo "BLAD: --bump i jawny tag (vX.Y.Z) sa wzajemnie wykluczajace."; exit 1
fi

# Walidacja --bump
if [ -n "$bump" ] && ! [[ "$bump" =~ ^(patch|minor|major)$ ]]; then
  echo "BLAD: --bump musi byc 'patch'/'minor'/'major' (otrzymano: '$bump')"; exit 1
fi

# Walidacja taga (jesli podany)
if [ -n "$tag" ] && ! [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "BLAD: tag '$tag' nie jest semver (oczekiwane: vMAJOR.MINOR.PATCH)"
  exit 1
fi

ROOT="/home/dadmor/code/obirg-zero/bq-content"
HOOK_SRC="$(dirname "$(realpath "$0")")/git-hooks/pre-push"
dir="$ROOT/$name"
[ -d "$dir" ] || { echo "BLAD: brak katalogu $dir"; exit 1; }

cd "$dir"

# Auto-init git jesli to pierwsze publish (dzieki temu --bump moze przeczytac taga juz w pierwszym publish)
if [ ! -d .git ]; then
  echo "[$name] Pierwsze publish — inicjalizacja git repo..."
  git init -q -b main
  [ -f "$HOOK_SRC" ] && install -m 0755 "$HOOK_SRC" .git/hooks/pre-push
fi

# --bump: wylicz nowy tag z ostatniego semver (tag tworzony PO commit, ponizej)
if [ -n "$bump" ]; then
  last=$(git tag --list 'v*' --sort=-v:refname 2>/dev/null | head -1 | sed 's/^v//' || true)
  [ -z "$last" ] && last="0.0.0"
  IFS='.' read -r maj min pat <<< "$last"
  case "$bump" in
    major) maj=$((maj+1)); min=0; pat=0 ;;
    minor) min=$((min+1)); pat=0 ;;
    patch) pat=$((pat+1)) ;;
  esac
  tag="v${maj}.${min}.${pat}"
  echo "[$name] --bump $bump: v$last → $tag"
fi

# Auto-gen pack.json (manifest). Z tagiem (--bump lub jawnym): manifest dostaje czysta wersje przez OZ_PACK_VERSION
# — bez tego pisalby "X.Y.Z-dev.N+sha" (HEAD po tagu, mylace dla swiezo bumpowanej paczki).
if [ -n "$tag" ]; then
  OZ_PACK_VERSION="${tag#v}" bash "$(dirname "$(realpath "$0")")/bq-pack-manifest.sh" "$name"
else
  bash "$(dirname "$(realpath "$0")")/bq-pack-manifest.sh" "$name"
fi

# Walidacja struktury (deleguj do bq-pack-validate.sh — exit 1 jesli bledy)
bash "$(dirname "$(realpath "$0")")/bq-pack-validate.sh" "$name"

# Jesli sa zmiany, commit
if [ -z "$(git log --oneline 2>/dev/null)" ] || ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  git add -A
  git commit -m "$message"
fi

# Auto-tworzenie repa na GitHub jesli nie istnieje
if ! git remote get-url origin >/dev/null 2>&1; then
  if gh repo view "BQ-content/$name" >/dev/null 2>&1; then
    echo "[$name] Repo BQ-content/$name istnieje — dodaje remote..."
    git remote add origin "git@github.com:BQ-content/$name.git"
  else
    # Wez tytul/description z tree.json (jezeli istnieje)
    desc=$(python3 -c "import json; print(json.load(open('tree.json'))[0]['data'].get('title', '$name'))" 2>/dev/null || echo "$name")
    echo "[$name] Tworzenie repa BQ-content/$name na GitHub: '$desc'"
    gh repo create "BQ-content/$name" --public --source=. --remote=origin --description "$desc" >/dev/null
    gh repo edit "BQ-content/$name" --add-topic brainquest >/dev/null
  fi
fi

# Push main + tag
echo "[$name] push origin/main"
OBIEG_PROMOTE=1 git push -u origin main

if [ -n "$tag" ]; then
  git tag -f "$tag"
  OBIEG_PROMOTE=1 git push -f origin "$tag"
  echo "[$name] PROD: tag $tag"
fi

# Upewnij sie ze topic brainquest jest na repie
gh repo edit "BQ-content/$name" --add-topic brainquest >/dev/null 2>&1 || true

echo "[$name] OK — opublikowano. Powinno byc widoczne w RepoPicker po refreshu."
