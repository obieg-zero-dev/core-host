#!/bin/bash
# Inicjalizacja nowej paczki kontentowej BQ:
#  1. tworzy katalog bq-content/<nazwa>/ ze szkieletem tree.json
#  2. git init + instalacja pre-push hooka
#  3. gh repo create BQ-content/<nazwa> --public --source=. --remote=origin -t brainquest
#
# LLM moze tworzyc/edytowac pliki w bq-content/, ale uruchamianie tego skryptu (gh repo create)
# nalezy do wlasciciela — to operacja na shared infrastructure.
#
# Uzycie:
#   bash bq-pack-init.sh <nazwa-paczki> [--extends "<tytul-bazy>"] [--description "..."]
# Przyklad:
#   bash bq-pack-init.sh bq-polski-matura-fil --extends "Polski — matura (mini)" \
#                                             --description "Konteksty filozoficzne (rozszerzenie)"

set -euo pipefail

name="${1:-}"
[ -z "$name" ] && { echo "Uzycie: $0 <nazwa-paczki> [--extends \"<tytul\"] [--description \"...\"]"; exit 1; }
shift

extends_title=""
description="$name"

while [ $# -gt 0 ]; do
  case "$1" in
    --extends) extends_title="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    *) echo "Nieznana opcja: $1"; exit 1 ;;
  esac
done

ROOT="/home/dadmor/code/obirg-zero/bq-content"
HOOK_SRC="$(dirname "$(realpath "$0")")/git-hooks/pre-push"
dir="$ROOT/$name"

[ -d "$dir" ] && { echo "BLAD: $dir juz istnieje."; exit 1; }
mkdir -p "$dir/lexicon" "$dir/content"

# Szkielet tree.json — albo bazowy (z branches+nodes minimalnymi) albo extension (z extends)
if [ -n "$extends_title" ]; then
  tree_json=$(cat <<EOF
[
  {
    "type": "tree",
    "data": {
      "title": "$description",
      "extends": "$extends_title",
      "edges": "[]"
    },
    "children": []
  }
]
EOF
)
else
  tree_json=$(cat <<EOF
[
  {
    "type": "tree",
    "data": {
      "id": "$name",
      "title": "$description",
      "branches": "{}",
      "relations": "{\"progression\":{\"label\":\"Następstwo\",\"color\":\"primary\"},\"branch\":{\"label\":\"Przynależność\",\"color\":\"neutral\"},\"kontekst\":{\"label\":\"Kontekst\",\"color\":\"warning\"}}",
      "edges": "[]"
    },
    "children": []
  }
]
EOF
)
fi
echo "$tree_json" > "$dir/tree.json"

# README per paczka
cat > "$dir/README.md" <<EOF
# $name

$description

## Struktura

\`\`\`
tree.json              — drzewo: branches + relations + nodes + edges (seed format)
lexicon/<nodeId>.json  — terminy z definicjami i quizem (per wezel)
content/<nodeId>.json  — slajdy + quizy do readera (per wezel)
\`\`\`

## Publikacja

\`\`\`bash
bash CORE-HOST/scripts/bq-pack-validate.sh $name
bash CORE-HOST/scripts/bq-pack-publish.sh  $name
\`\`\`
EOF

# git init + remote + hook
cd "$dir"
git init -q -b main
[ -f "$HOOK_SRC" ] && install -m 0755 "$HOOK_SRC" .git/hooks/pre-push

# Auto-gen pack.json (manifest) — w pierwszym commicie
bash "$(dirname "$(realpath "$0")")/bq-pack-manifest.sh" "$name"

git add -A
git commit -q -m "Init: $description"

# Tworzenie repa na GitHub (z topikiem brainquest, public)
if ! gh repo view "BQ-content/$name" >/dev/null 2>&1; then
  echo "[$name] Tworzenie repa BQ-content/$name na GitHub..."
  gh repo create "BQ-content/$name" --public --source=. --remote=origin \
    --description "$description" >/dev/null
  gh repo edit "BQ-content/$name" --add-topic brainquest >/dev/null
  OBIEG_PROMOTE=1 git push -u origin main
  echo "[$name] OK — repo utworzone i opublikowane."
else
  echo "[$name] Repo BQ-content/$name juz istnieje na GitHub. Skonfiguruj remote recznie:"
  echo "  cd $dir"
  echo "  git remote add origin git@github.com:BQ-content/$name.git"
  echo "  bash CORE-HOST/scripts/bq-pack-publish.sh $name"
fi
