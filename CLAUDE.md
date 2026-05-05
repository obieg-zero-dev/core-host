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
- **Nigdy nie wywołuje:** `plugin_deploy_dev`, `plugin_deploy_prod`, `app_deploy_dev`, `app_deploy_prod`, `push_core_host`, `package_publish`, `bq_pack_publish`.

**Użytkownik (właściciel):**
- Pcha `LOCAL → DEV`: `git push origin dev` (gdy daje sygnał "kod ma iść na dev").
- Pcha `DEV → PROD`: po sygnale "na dev jest dobrze" → `git merge --ff dev && git push origin main` (lub `gh pr create dev → main`).
- Tagi semver na main (`vX.Y.Z`) tworzy ręcznie przy promocji prod.

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

## MCP `obieg-deploy`

GitHub org: **obieg-zero-dev** (jedyne źródło). Branchy w każdym repo: `dev` = staging, `main` = prod + tagi semver.

Cykl pluginu:
- **LLM:** edycja `src/` → `plugin_build` → `plugin_commit_local` → STOP, raport.
- **Właściciel ręcznie:** `git push origin dev` (sygnał: kod na dev) → walidacja → `git push origin main` + `git tag vX.Y.Z && git push --tags` (sygnał: dev OK, prod).

> Stare narzędzia `plugin_deploy_*`, `app_deploy_*`, `package_publish`, `push_core_host` są zachowane w MCP, ale **wyłącznie do ręcznego użytku właściciela**. LLM ich nie wywołuje pod żadnym pozorem (psuły model: pchały built bundle bez source, robiły nieoczekiwane bumpe wersji, nadpisywały `public/config.json`).

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
