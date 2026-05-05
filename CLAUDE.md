# Obieg Zero — core-host

Platforma pluginowa w przeglądarce. Zustand + IndexedDB + OPFS, zero backendu.

## Model promocji (FUNDAMENT — przeczytaj zanim cokolwiek zrobisz)

Standardowy git flow z trzema warstwami: **local → dev → prod**.

```
LOCAL (Twój dysk)              DEV (obieg-zero-dev/X:dev)        PROD (obieg-zero-dev/X:main)
   ↓                                ↓                                  ↓
LLM edytuje source           kopia z LOCAL gdy user da sygnał    kopia z DEV gdy user da sygnał
LLM commituje LOKALNIE       (user pcha: git push origin dev)    (user pcha: git push origin main)
LLM nie pcha                 LLM nie tyka                        LLM nie tyka
```

**LLM (Ty):**
- Edytuje source code w `plugins/plugin-X/src/`, `packages/*/src/`, `CORE-HOST/src/`.
- Buduje lokalnie (`plugin_build` MCP albo `npm run build`).
- Commituje LOKALNIE przez `*_commit_local` MCP (`plugin_commit_local`, `core_host_commit_local`, `packages_commit_local`).
- **NIGDY nie pcha do `obieg-zero-dev`** — ani przez bash `git push`, ani przez MCP deploy.
- Te narzędzia są usunięte z MCP whitelisty (od v0.2.0): `plugin_deploy_*`, `app_deploy_*`, `push_core_host`, `package_publish`, `bq_pack_publish`, `plugin_config_*`. Przed v0.2.0 LLM mógł je wywołać i robił bałagan (pchał bundle bez source, nadpisywał `public/config.json`).

**Użytkownik (właściciel):** pcha przez skrypty z `CORE-HOST/scripts/` (hook gita wymaga skryptów .sh):
- `bash scripts/promote-to-dev.sh <plugin-X|core-host|packages>` — LOCAL → DEV (force-push lokalnego HEAD na zdalny branch dev).
- `bash scripts/promote-to-prod.sh <target> [vX.Y.Z]` — DEV → PROD (ff dev → main + opcjonalny tag semver).

**Reguła kontekstu:** `obieg-zero-dev` to JEDYNE źródło kodu projektu. Każde repo ma source + bundle + meta razem na każdej gałęzi. Nie istnieją osobne "release-only" repozytoria. Jeśli czegoś nie ma na `obieg-zero-dev`, to nie istnieje.

## Zanim cokolwiek zrobisz

1. `check_sync` — stan pluginów, paczek, aplikacji.
2. Przeczytaj MEMORY.md — kontekst z poprzednich rozmów.
3. Plan zmian → edycja → build → `*_commit_local` → STOP. User decyduje co dalej.

## Zasady

- Polskie znaki diakrytyczne w UI.
- **LLM ma BEZWZGLĘDNY ZAKAZ pchania kodu** na `obieg-zero-dev` (ani bash `git push`, ani MCP `*_deploy_*`/`*_publish`/`push_core_host`). Każda taka operacja jest wykonywana wyłącznie ręcznie przez właściciela.
- LLM wolno (whitelist): `plugin_build`, `plugin_status`, `app_status`, `check_sync`, `package_status`, `plugin_commit_local`, `core_host_commit_local`, `packages_commit_local`, `bq_pack_status`. Plus `gh` CLI tylko read-only (`gh api`, `gh repo view`, `gh pr view`).
- Build pluginów po każdej edycji: `plugin_build` (regeneruje `index.mjs`). Bundle `index.mjs` jest commitowany razem ze źródłem — to jeden artefakt repo.
- Nie uruchamiaj dev servera bez pytania.
- Nie duplikuj logiki między pluginami — deleguj przez `sdk.shared` i `activeId`.
- Sprawdź `store.registerType()` dla WSZYSTKICH typów z seed data.

## Monorepo

```
obirg-zero/
├── CORE-HOST/              ← TU JESTEŚ (Vite + React 19)
├── plugins/                ← plugin-*/src/index.tsx → plugin-*/index.mjs
└── packages/               ← @obieg-zero/* (sdk, mcp-deploy, workflow-engine, doc-*, text-pl)
```

## MCP `obieg-deploy` (v0.2.0)

GitHub org: **obieg-zero-dev** (jedyne źródło). Branchy w każdym repo: `dev` = staging, `main` = prod + tagi semver.

Wystawione narzędzia (read + lokalny commit, zero pchania):
- `check_sync`, `plugin_status`, `package_status`, `app_status` — audyty.
- `plugin_build` — buduje wszystkie pluginy (`plugins/plugin-*/index.mjs`).
- `plugin_commit_local`, `core_host_commit_local`, `packages_commit_local` — commit lokalny w odpowiednim repo, bez push.
- `bq_pack_status` — status paczki kontentu BQ.
- `setup_creem` — sync z Creem (płatności).

Cykl pluginu:
- **LLM:** edycja `src/` → `plugin_build` → `plugin_commit_local` → STOP, raport.
- **Właściciel:** `bash scripts/promote-to-dev.sh plugin-X` → walidacja → `bash scripts/promote-to-prod.sh plugin-X vX.Y.Z`.

## Store API — synchroniczny CRUD

```ts
store.add(type, data, opts?)     // → PostRecord, opts: { id?, parentId? }
store.get(id)                    // sync
store.update(id, data)           // sync merge
store.remove(id)                 // sync, cascade children
store.usePosts(type)             // hook → PostRecord[]
store.usePost(id)                // hook
store.useChildren(parentId, type?)
store.registerType(type, schema, label, { strict? })
store.importJSON(nodes)          // bulk: [{ type, data, children? }]
store.setOption(key, value) / store.useOption(key)
store.writeFile(postId, name, data) / store.readFile / store.listFiles
```

Relacje: `parentId` (cascade delete), `data.XId` (foreign key). Wartości w `data` to stringi — parsuj JSON ręcznie.

## SDK API

```ts
sdk.registerView(id, { slot: 'left'|'center'|'right'|'footer', component })
sdk.shared(selector) / sdk.shared.setState(partial) / sdk.shared.getState()
sdk.create(() => initialState)   // lokalny Zustand store
sdk.useForm(defaults, { isComplete? })  // → { form, bind, set, submit, toggle, reset }
sdk.useHostStore                 // pluginy, logi, activeId, leftOpen
sdk.log(text, level?)
sdk.uploadFile(parentId) / sdk.downloadFile(postId, filename)
sdk.installPlugin(spec, label?) / sdk.uninstallPlugin(spec)
```

**UI:** `Page, Stack, Row, Box, Button, Input, Select, Field, Tabs, Cell, Table, Card, Badge, Heading, Text, Value, ListItem, CheckItem, Spinner, Divider, RemoveButton`

**Ikony:** react-feather, np. `icons.Map`, `icons.BookOpen`, `icons.Zap`

**ZAKAZANE w pluginach:** `fetch`, `className`, `import()`, `localStorage`, `await` na store

## Plugin — wzorzec

```tsx
import type { PluginFactory } from '@obieg-zero/sdk'
const plugin: PluginFactory = ({ React, store, sdk, ui, icons }) => {
  store.registerType('task', [{ key: 'title', label: 'Tytuł', required: true }], 'Zadania')
  sdk.registerView('tasks.center', { slot: 'center', component: MyComponent })
  return { id: 'tasks', label: 'Zadania', icon: icons.CheckSquare }
}
export default plugin
```

Komunikacja: `sdk.shared.setState({ bqHelpers: {...} })` + `sdk.shared(s => s?.bqHelpers)`
Przełączanie pluginu: `sdk.useHostStore.setState({ activeId: 'other-id' })`

## Architektura src/

```
main.tsx         → bootstrap: config → store → SDK → Shell → load plugins
store.ts         → Zustand + IndexedDB, CRUD, pliki OPFS
plugin.ts        → useHostStore, loader, registries, SDK factory
opfs.ts          → cache pluginów, meta.json (specs, labels, licenseKey)
Shell.tsx        → hooki → filtruje widoki → props do ShellLayout
themes/default/  → czyste JSX komponenty (zero hooków, dane z props)
```

## Build

```bash
npm run dev       # CORE-HOST: Vite :5173, middleware serwuje ../plugins/
npm run build     # CORE-HOST: produkcja → dist/
# plugins/
npm run build     # Vite: plugin-*/src/index.tsx → plugin-*/index.mjs
```

Czytaj README paczek (`../packages/*/README.md`) przed ich użyciem.
