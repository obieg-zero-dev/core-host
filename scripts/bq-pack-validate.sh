#!/bin/bash
# Walidacja struktury paczki BQ przed publikacja.
# Sprawdza:
#  - bq-content/<name>/tree.json istnieje, jest valid JSON
#  - root.type === 'tree'
#  - branches/relations/edges parsowalne
#  - jesli extends: ostrzeza ze wymagana baza
#  - lexicon/content tylko dla istniejacych nodeId
#
# Uzycie: bash bq-pack-validate.sh <nazwa-paczki>

set -euo pipefail

name="${1:-}"
[ -z "$name" ] && { echo "Uzycie: $0 <nazwa-paczki>"; exit 1; }

ROOT="/home/dadmor/code/obirg-zero/bq-content"
dir="$ROOT/$name"

[ -d "$dir" ] || { echo "BLAD: brak katalogu $dir"; exit 1; }
[ -f "$dir/tree.json" ] || { echo "BLAD: brak $dir/tree.json"; exit 1; }

python3 <<PY
import json, os, sys
dir = "$dir"
with open(f"{dir}/tree.json") as f:
    seeds = json.load(f)
errors = []
warns = []
if not isinstance(seeds, list) or not seeds:
    errors.append("tree.json musi byc niepusta tablica seedow")
else:
    root = seeds[0]
    if root.get("type") != "tree":
        errors.append("root.type musi byc 'tree'")
    data = root.get("data", {})
    title = data.get("title", "")
    if not title:
        errors.append("root.data.title wymagany")

    extends_id = data.get("extends", "")
    own_id = data.get("id", "")
    if not extends_id and not own_id:
        warns.append("Baza bez 'id' — rozszerzenia beda musialy odwolywac sie po tytule")
    if extends_id:
        warns.append(f"Rozszerzenie wymaga zaladowanej bazy o tytule/id '{extends_id}' przed merge")

    # JSON-stringi: branches, relations, edges
    for f_name in ("branches", "relations", "edges"):
        v = data.get(f_name, "")
        if v == "":
            continue
        try:
            json.loads(v)
        except Exception as e:
            errors.append(f"data.{f_name} nie jest valid JSON: {e}")

    # NodeIds
    nodes = [c for c in root.get("children", []) if c.get("type") == "node"]
    nids = set()
    for n in nodes:
        nid = n.get("data", {}).get("nodeId", "")
        if not nid:
            errors.append(f"Node bez nodeId: {n.get('data')}")
        elif nid in nids:
            errors.append(f"Duplikat nodeId: {nid}")
        else:
            nids.add(nid)

    # Edges referuja istniejace nodeId (tylko ostrzezenie — w extension edges moga wskazywac na node z bazy)
    try:
        edges = json.loads(data.get("edges", "[]"))
        if not extends_id:
            for e in edges:
                for end in ("from", "to"):
                    if e.get(end) not in nids:
                        warns.append(f"Edge {e.get('from')}→{e.get('to')} ({e.get('type')}): '{e.get(end)}' nie ma w nodes (jesli to baza, to blad)")
    except Exception:
        pass

    # Lexicon i content tylko dla istniejacych nodeId
    for sub in ("lexicon", "content"):
        sub_dir = f"{dir}/{sub}"
        if not os.path.isdir(sub_dir):
            continue
        for fn in os.listdir(sub_dir):
            if not fn.endswith(".json"):
                continue
            nid = fn[:-5]
            if nid not in nids:
                warns.append(f"{sub}/{fn} dotyczy nieznanego nodeId '{nid}' (zostanie zignorowany przez plugin)")
            try:
                with open(f"{sub_dir}/{fn}") as f:
                    json.load(f)
            except Exception as e:
                errors.append(f"{sub}/{fn}: invalid JSON ({e})")

# pack.json (manifest) — wymagany przed publikacja
pack_path = f"{dir}/pack.json"
if not os.path.exists(pack_path):
    warns.append("Brak pack.json — wygeneruj 'bash bq-pack-manifest.sh <name>' (oz pack publish robi to automatycznie)")
else:
    try:
        m = json.load(open(pack_path))
    except Exception as e:
        errors.append(f"pack.json: invalid JSON ({e})")
        m = None
    if m is not None:
        for req in ("schemaVersion", "id", "title", "version", "provides", "stats"):
            if req not in m:
                errors.append(f"pack.json: brak wymaganego pola '{req}'")
        if m.get("id") and m["id"] != "$name":
            warns.append(f"pack.json.id='{m['id']}' rozni sie od nazwy katalogu '$name'")
        if not (m.get("author") or {}).get("name"):
            warns.append("pack.json.author.name pusty (skonfiguruj git config user.name)")
        if not m.get("license"):
            warns.append("pack.json.license pusty (rekomendowane: CC-BY-SA-4.0)")
        unmet = m.get("mentions") or []
        if unmet:
            warns.append(f"pack.json: {len(unmet)} mentions_unmet (terminy uzywane w content ale niezdefiniowane w paczce): {unmet[:5]}{'...' if len(unmet)>5 else ''}")

print(f"[$name] tree.json: tytul='{title}'", end="")
if extends_id: print(f" extends='{extends_id}'", end="")
elif own_id: print(f" id='{own_id}'", end="")
print(f" ({len(nodes)} wezlow)")

if warns:
    print("OSTRZEZENIA:")
    for w in warns: print(f"  ! {w}")
if errors:
    print("BLEDY:")
    for e in errors: print(f"  X {e}")
    sys.exit(1)
else:
    print("OK")
PY
