#!/bin/bash
# Auto-generuje pack.json (manifest paczki BQ).
# Wywolywane przez bq-pack-publish.sh przed walidacja, ale mozna tez recznie.
#
# Co generuje:
#   - schemaVersion, id, title (z tree.json), version (z git tag) — auto
#   - author (z git config), description, license — preserve z istniejacego pack.json
#   - extends — z tree.json[0].data.extends (preserve override)
#   - provides.terms[]  — unique terms z lexicon/*.json + terms.json
#   - provides.nodes[]  — unique nodeId z tree.json
#   - mentions[]        — {{...}} w content/*.json minus provides (norm: lowercase+bez diacritics)
#   - stats             — counts
#
# Uzycie:
#   bash bq-pack-manifest.sh <nazwa-paczki>

set -euo pipefail

name="${1:-}"
[ -z "$name" ] && { echo "Uzycie: $0 <nazwa-paczki>"; exit 1; }

ROOT="/home/dadmor/code/obirg-zero/bq-content"
dir="$ROOT/$name"
[ -d "$dir" ] || { echo "BLAD: brak katalogu $dir"; exit 1; }

cd "$dir"

# Author z git config (lokalny override globalny)
author_name=$(git config user.name 2>/dev/null || git config --global user.name 2>/dev/null || echo "")
author_email=$(git config user.email 2>/dev/null || git config --global user.email 2>/dev/null || echo "")

# Wersja:
#   - $OZ_PACK_VERSION (env override) — uzywane przez 'oz pack publish --bump' przed utworzeniem taga
#   - inaczej: ostatni semver tag + sufiks gdy HEAD po tagu (semver pre-release).
#     git describe --long zwraca v0.4.0-3-ga1b2c3d  ↔ v0.4.0-0-g... (HEAD == tag).
#     Gdy commits_since > 0: "0.4.0-dev.3+a1b2c3d" — jasny sygnal "po tagu".
#   - brak tagow: "0.0.0"
if [ -n "${OZ_PACK_VERSION:-}" ]; then
  version="$OZ_PACK_VERSION"
else
  desc=$(git describe --tags --long --match 'v*' 2>/dev/null || true)
  if [ -n "$desc" ]; then
    base=$(echo "$desc" | sed -E 's/^v//; s/-[0-9]+-g[0-9a-f]+$//')
    commits_since=$(echo "$desc" | sed -E 's/^.*-([0-9]+)-g[0-9a-f]+$/\1/')
    sha=$(echo "$desc" | sed -E 's/^.*-g([0-9a-f]+)$/\1/')
    if [ "$commits_since" = "0" ]; then
      version="$base"
    else
      version="${base}-dev.${commits_since}+${sha}"
    fi
  else
    version="0.0.0"
  fi
fi

NAME="$name" AUTHOR_NAME="$author_name" AUTHOR_EMAIL="$author_email" VERSION="$version" \
python3 <<'PY'
import json, os, re, sys, unicodedata
from glob import glob

dir = os.getcwd()
name = os.environ["NAME"]
author_name = os.environ["AUTHOR_NAME"]
author_email = os.environ["AUTHOR_EMAIL"]
version = os.environ["VERSION"]

# Preserve nauczyciel-edytowane pola z istniejacego pack.json
preserved = {}
if os.path.exists("pack.json"):
    try:
        preserved = json.load(open("pack.json"))
    except: preserved = {}

# tree.json
seeds = json.load(open("tree.json"))
root = seeds[0] if seeds else {}
data = root.get("data") or {}
title = str(data.get("title") or name)
extends_raw = str(data.get("extends") or "")

def jparse(s, fallback):
    if isinstance(s, list) or isinstance(s, dict): return s
    if not s: return fallback
    try: return json.loads(s)
    except: return fallback

edges = jparse(data.get("edges"), [])

children = root.get("children") or []
node_ids = sorted({str(c["data"].get("nodeId")) for c in children if c.get("type") == "node" and c.get("data", {}).get("nodeId")})

# Terminy + warianty fleksyjne: lexicon/*.json (per-node) + terms.json (alt format bazy)
# forms moze byc JSON-stringiem (legacy) lub array
def _read_forms(d):
    f = d.get("forms")
    if not f: return []
    if isinstance(f, list): return f
    try: return json.loads(f) if isinstance(f, str) else []
    except: return []

terms = set()      # canonical (do provides.terms)
all_forms = set()  # term + warianty (do mention matching)

def _ingest_lex(entry):
    d = entry.get("data") or {}
    t = d.get("term")
    if not t: return
    terms.add(str(t))
    all_forms.add(str(t))
    for v in _read_forms(d):
        if v: all_forms.add(str(v))

if os.path.isdir("lexicon"):
    for f in sorted(glob("lexicon/*.json")):
        try:
            for x in json.load(open(f)): _ingest_lex(x)
        except: pass
# UWAGA: terms.json to LEGACY format ze starego BRAIN-QUEST, plugin-bq-loader go NIE
# czyta przy load. Liczenie termow z tego pliku falszowalo statystyki manifest
# (np. baza pokazywala 99 terminow zamiast 40 ladowanych do store).

# Mentions: {{...}} w content/*.json (text + answer + question)
mention_re = re.compile(r"\{\{([^}]+)\}\}")
mentions = set()
if os.path.isdir("content"):
    for f in glob("content/*.json"):
        try:
            for x in json.load(open(f)):
                d = x.get("data") or {}
                for field in ("text", "answer", "question"):
                    val = d.get(field) or ""
                    for m in mention_re.findall(val):
                        mentions.add(m.strip())
        except: pass

def norm(s):
    s = unicodedata.normalize("NFD", str(s).lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")

provides_terms = sorted(terms)
# Mention matchuje jesli jego norm jest w norm(any term-form) — formy fleksyjne pokrywaja "Ikara"→"Ikar"
known = {norm(f) for f in all_forms}
mentions_unmet = sorted({m for m in mentions if norm(m) not in known})

manifest = {
    "schemaVersion": "1.0",
    "id": name,
    "title": title,
    "description": preserved.get("description") or title,
    "author": preserved.get("author") or {"name": author_name, "email": author_email},
    "license": preserved.get("license") or "CC-BY-SA-4.0",
    "version": version,
    "extends": preserved.get("extends") if "extends" in preserved else (
        {"title": extends_raw} if extends_raw else None
    ),
    "provides": {
        "nodes": node_ids,
        "terms": provides_terms,
    },
    "mentions": mentions_unmet,
    "stats": {
        "nodes": len(node_ids),
        "terms": len(provides_terms),
        "edges": len(edges) if isinstance(edges, list) else 0,
        "mentions_unmet": len(mentions_unmet),
    },
}

with open("pack.json", "w") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"[{name}] pack.json: {len(provides_terms)} terms, {len(node_ids)} nodes, {len(mentions_unmet)} mentions_unmet, v{version}")
PY
