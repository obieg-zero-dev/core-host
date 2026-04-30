# Obieg Zero — Core Host

Browser-native document flow engine. Zero backend, zero config, zero barrier.

## Architecture

**WordPress pattern in the browser:**

- One `posts` table (id, type, parentId, data) — like `wp_posts` + `wp_postmeta`
- Plugins register types (`registerType`) — like `register_post_type`
- Plugins register views in slots (`registerView`) — like WordPress hooks
- Zustand everywhere — host store, plugin stores, shared state, persistence
- Sandbox: plugins get `{ store, sdk, ui, icons }` — no fetch, no DOM, no import

## Stack

| Layer | Tech | Purpose |
|-------|------|---------|
| State | Zustand + persist | All state, synced to IndexedDB |
| UI | React + DaisyUI/Tailwind | Component kit in `@obieg-zero/sdk` |
| Plugins | ES modules (sandboxed) | Business logic, loaded from GitHub or local |
| Files | OPFS | Attachments per record |
| Packages | `workflow-engine`, `doc-*` | Reusable logic (NPM-ready) |

## Project structure

```
core-host/src/
  store.ts      241 LOC  — Zustand post store (CRUD, queries, types, persist)
  plugin.ts     194 LOC  — Plugin loader, TOFU, contribution points
  ui.tsx         58 LOC  — Shell layout (imports UI kit from SDK)
  main.tsx      113 LOC  — Bootstrap, config, SDK wiring
  Shell.tsx      61 LOC  — 3-column layout with plugin routing

packages/
  sdk/           — Plugin contract: types + UI components + README
  workflow-engine/ — Stage views, graph, workflow logic
  doc-pipeline/  — OCR + AI extraction (optional)
  doc-reader/    — PDF/image OCR worker
  doc-search/    — Embeddings + vector search

plugins/
  plugin-workflow-crm/  — CRM for law firms (demo)
  plugin-wibor-calc/    — WIBOR loan calculator (demo)
  plugin-data/          — Generic CRUD admin
  plugin-manager/       — Install/uninstall plugins at runtime
  plugin-darkmode/      — Theme switcher
```

## Data model

```
PostRecord {
  id: string           — UUID
  type: string         — post type (case, client, opponent, event, ...)
  parentId: string     — parent record (cascade delete)
  data: {}             — key-value fields (like wp_postmeta in JSON)
  createdAt: number
  updatedAt: number
}
```

Relationships: `parentId` for parent-child (opponent → template, case → event). Foreign keys by convention: `case.data.opponentId → opponent.id`.

## Plugin system

Plugins are ES modules loaded from GitHub (`org/repo@branch`) or local (`./plugin-name`).

Each plugin is a factory function:

```tsx
const plugin: PluginFactory = ({ store, sdk, ui, icons }) => {
  store.registerType('task', [{ key: 'title', label: 'Tytuł', required: true }], 'Zadania')
  sdk.registerView('tasks.center', { slot: 'center', component: TaskList })
  return { id: 'tasks', label: 'Zadania', icon: icons.CheckSquare }
}
```

See [`@obieg-zero/sdk` README](../packages/sdk/README.md) for the full plugin API.

## Commands

```bash
npm run dev      # Dev server (Vite)
npm run build    # Production build
npm run test     # Run tests (vitest)
```

Plugin build (from /plugins):
```bash
npm run build    # Builds all plugin-*/src/index.tsx → plugin-*/index.mjs
```

## Config

`public/config.json` — plugin loading order, seed data, default options:

```json
[
  { "pluginUri": "obieg-zero/plugin-darkmode@main", "defaultOptions": { "theme": "dracula" } },
  { "pluginUri": "obieg-zero/plugin-workflow-crm@main", "importData": ["workflows.json", "opponents.json"] },
  { "pluginUri": "obieg-zero/plugin-data@main" }
]
```

## Tests

30 tests covering store (CRUD, cascade delete, type registry, validation, importJSON) and plugin system (contribution points, log, unregister).

```
npm run test
```



 │  #  │           Feature           │                                                   Co robi (1 zdanie)                                                    │  LOC  │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 1   │ Connection challenges       │ Po przeczytaniu lektury reader pyta "gdzie jeszcze spotkasz hybris?" i pokazuje 3 lektury do wyboru.                    │ 130   │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤
  │ 2   │ Markdown bullets/headings   │ W slajdzie czytnika linie zaczynające się od - są listą, ## są nagłówkami.                                              │ 60    │   
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 3   │ Whack-def                   │ Drugi tryb areny: pokazany termin, wybierasz definicję (zamiast: pokazana definicja, wybierasz termin).                 │ 30    │   
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 4   │ Combo + 3 poziomy trudności │ W arenie za serię trafień rośnie mnożnik, można kliknąć "łatwiejsze" za mniej punktów.                                  │ 50    │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 5   │ Sonar + glow + kamera SVG   │ Mapa się płynnie scrolluje do klikniętego węzła, "co dalej" pulsuje falami, krawędzie świecą.                           │ 80    │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 6   │ NodeDetail 3 kroki          │ Po kliknięciu węzła okienko z "Krok 1: Przeczytaj / Krok 2: Odkryj terminy / Krok 3: Wygraj arenę" z ✓ przy zrobionych. │ 50    │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 7   │ Progress widget             │ Prawy panel z procentami: gęstość połączeń, ile odkryte/opanowane, ostatnie aktywności, sugestia "co dalej".            │ 70    │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 8   │ bqFlash złota linia         │ Po dobrej odpowiedzi w reader connection challenge, na mapie zapala się złota linia między dwoma lekturami.             │ 40    │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 9   │ Mastery ring (gwiazdka)     │ Po 5 trafieniach na węźle pojawia się gwiazdka i pierścień zamiast liczby.                                              │ 50    │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 10  │ RepoPicker z org GitHub     │ Lista wszystkich repo z org BrainEduPlay z topikiem brainquest, klikasz wybierasz przedmiot.                            │ 30    │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 11  │ CheatSheet shared           │ Lewy panel pokazuje terminy odkryte w bieżącym kontekście, klik "czytaj" wraca do readera.                              │ 30+30 │
  ├─────┼─────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────┤   
  │ 12  │ Multi-repo lexicon          │ Funkcja dociągania leksykonu z innego repo do tego samego drzewa.                                                       │ 15    │