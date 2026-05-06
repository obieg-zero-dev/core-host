# obieg-zero / core-host

Platforma pluginowa w przeglądarce. React 19 + Zustand + IndexedDB + OPFS. Zero backendu. Pluginy ładowane runtime z CDN/OPFS.

## Layout

```
obieg-zero/
├── CORE-HOST/      Vite + React 19, host pluginów   ← TUTAJ
├── plugins/        plugin-*/src/index.tsx → plugin-*/index.mjs (bundle)
├── packages/       @obieg-zero/* (sdk, mcp-deploy, workflow-engine, ...)
└── bq-content/     lokalny mirror paczek BQ → push do org BQ-content
```

Każde z `core-host`, `packages`, `plugin-*` to osobny git repo w org `obieg-zero-dev`. Każde trzyma source + bundle + meta na każdej gałęzi (brak osobnych "release-only" repo).

## Pętla pracy LLM

```
1. Czytaj MEMORY.md
2. Edit src/
3. oz build                # regeneruje plugin-*/index.mjs
4. *_commit_local (MCP)    # plugin_commit_local / core_host_commit_local / packages_commit_local
5. STOP. Raport. User decyduje czy promować.
```

LLM **nie pcha** — ani `git push`, ani MCP `*_deploy_*`. Push wyłącznie user przez `oz`.

## Promocja: LOCAL → DEV → PROD

```
LOCAL (dysk)        DEV (origin/dev)        PROD (origin/main + tag vX.Y.Z)
     ↓                    ↓                          ↓
oz promote dev    oz promote prod        oz promote prod <target> vX.Y.Z
```

Wszystko (user) przez `oz` (dispatcher nad skryptami). Pełna lista: `oz help`.

```bash
oz promote dev  <plugin-X|core-host|packages>
oz promote prod <target> [vX.Y.Z]
oz pack init    <name> [--extends "<tytul>"] [--description "..."]
oz pack publish <name> [vX.Y.Z]      # auto-init git+remote+gh repo create
oz pack list                          # lokalne + remote BQ-content
oz build / oz guards / oz status
```

Alias raz, w `.bashrc`/`.zshrc`:
```bash
alias oz='bash /home/dadmor/code/obirg-zero/CORE-HOST/scripts/oz'
```

## Niezawodność (3 warstwy ochrony)

| Warstwa | Blokuje | Bypass |
|---------|---------|--------|
| `.git/hooks/pre-push` w każdym repo | direct `git push` (bash + klient git) | `OBIEG_PROMOTE=1` (skrypty `promote-*.sh`) |
| `block-direct-git.sh` (Claude Code hook) | bash `git push/add/commit` w sesji LLM | komenda zawiera `.sh` (przez skrypt) |
| MCP `obieg-deploy` whitelista | brak narzędzi push | n/d |

Setup w nowym klonie: `oz guards`.

## Reguły LLM

| Wolno (whitelist) | Zakaz |
|-------------------|-------|
| MCP read+commit-local: `plugin_build`, `plugin_status`, `app_status`, `check_sync`, `package_status`, `bq_pack_status`, `*_commit_local` | MCP push: `*_deploy_*`, `*_publish`, `push_*` (usunięte z whitelisty od v0.2.0) |
| `gh` CLI read-only: `gh api`, `gh repo view`, `gh pr view` | `gh repo create`, `gh pr merge`, `gh repo edit` |
| Edycja plików w `bq-content/<name>/` | `oz pack publish` (push do shared GitHub org) |

Pozostałe:
- Polskie diakrytyki w UI.
- Build pluginu po każdej edycji (`oz build` lub `plugin_build` MCP) — bundle `index.mjs` jest commitowany razem ze źródłem.
- Nie duplikuj logiki między pluginami — deleguj przez `sdk.shared` + `sdk.useHostStore.activeId`.
- `store.registerType()` dla WSZYSTKICH typów z seed data (bez tego dane lecą do `unknown`).
- Dev server tylko na żądanie.

## Store API (sync CRUD)

```ts
store.add(type, data, opts?)     // → PostRecord, opts: { id?, parentId? }
store.get(id)
store.update(id, data)           // merge
store.remove(id)                 // cascade children
store.usePosts(type)             // hook → PostRecord[]
store.usePost(id)
store.useChildren(parentId, type?)
store.registerType(type, schema, label, { strict? })
store.importJSON(nodes)          // bulk: [{ type, data, children? }]
store.setOption(key, value) / store.useOption(key)
store.writeFile(postId, name, data) / readFile / listFiles   // OPFS
```

Relacje: `parentId` (cascade delete) lub `data.XId` (foreign key).
**Wartości w `data` to stringi** — JSON parsuj ręcznie (`jparse(s, fallback)`).

## SDK API

```ts
sdk.registerView(id, { slot: 'left'|'center'|'right'|'footer', component })
sdk.shared(selector) / sdk.shared.setState(partial) / sdk.shared.getState()
sdk.create(() => initialState)             // lokalny Zustand store pluginu
sdk.useForm(defaults, { isComplete? })     // { form, bind, set, submit, toggle, reset }
sdk.useHostStore                           // pluginy, logi, activeId, leftOpen
sdk.log(text, level?)
sdk.uploadFile(parentId) / sdk.downloadFile(postId, filename)
sdk.installPlugin(spec, label?) / sdk.uninstallPlugin(spec)
```

**UI** (`ui.*`): `Page, Stack, Row, Box, Button, Input, Select, Field, Tabs, Cell, Table, Card, Badge, Heading, Text, Value, ListItem, CheckItem, Spinner, Divider, RemoveButton`
**Ikony**: react-feather (`icons.Map`, `icons.BookOpen`, `icons.Zap`, ...)

**Zakazane w pluginach**: `fetch`, `className`, dynamic `import()`, `localStorage`, `await` na store (store jest sync).

## Plugin — wzorzec

```tsx
import type { PluginFactory } from '@obieg-zero/sdk'

const plugin: PluginFactory = ({ React, store, sdk, ui, icons }) => {
  store.registerType('task', [
    { key: 'title', label: 'Tytuł', required: true },
  ], 'Zadania')
  sdk.registerView('tasks.center', { slot: 'center', component: MyComponent })
  return { id: 'tasks', label: 'Zadania', icon: icons.CheckSquare }
}
export default plugin
```

Komunikacja między pluginami:
```ts
sdk.shared.setState({ bqHelpers: { discover, edgeStr, ... } })   // wystawienie
const helpers = sdk.shared(s => s?.bqHelpers)                     // konsumpcja
sdk.useHostStore.setState({ activeId: 'plugin-other' })           // przełączenie
```

## Paczki kontentowe BQ (`bq-content/`)

GitHub org: **`BQ-content`** (osobny od `obieg-zero-dev`). Topic: `brainquest`. Wykrywane przez `RepoPicker` w `plugin-brain-quest`.

Lokalnie każda paczka = osobny git repo:
```
bq-content/<name>/
├── tree.json              seed format dla importTreeSeed (drzewo / rozszerzenie)
├── lexicon/<nodeId>.json  terminy + quiz
└── content/<nodeId>.json  slajdy do readera
```

**Rozszerzenia**: `tree.json` z polem `extends: "<id-bazy>"` (lub tytuł) → merge w istniejące drzewo, dedupe po `nodeId` / `from:to:type` / `branch.key` / `relType.key`. Implementacja: `plugin-brain-quest/src/index.tsx :: importTreeSeed`.

Workflow: `oz pack init/validate/publish/list`. LLM edytuje pliki, user pcha. Pełny opis: `bq-content/README.md`.

## src/

```
main.tsx         bootstrap: config → store → SDK → Shell → load plugins
store.ts         Zustand + IndexedDB, CRUD, pliki OPFS
plugin.ts        useHostStore, loader, registries, SDK factory
opfs.ts          cache pluginów, meta.json (specs, labels, licenseKey)
Shell.tsx        hooki → filtruje widoki → props do ShellLayout
themes/default/  czyste JSX (zero hooków, dane z props)
```

## Build

```bash
oz build          # plugins/: plugin-*/src/index.tsx → plugin-*/index.mjs
npm run dev       # CORE-HOST: Vite :5173 + middleware ../plugins/
npm run build     # CORE-HOST: produkcja → dist/
```

Przed użyciem paczki z `packages/` — przeczytaj jej `README.md`.
