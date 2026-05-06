# obieg-zero / core-host

Host pluginowy w przeglądarce. Zero backendu, zero bazy danych, zero serwera.

CORE-HOST to cienki wrapper Vite + React 19 (`src/main.tsx` woła `bootRuntime` z `@obieg-zero/runtime`). Cała logika hosta — store, plugin loader, shell, OPFS — żyje w `../packages/runtime/`.

## Jak to działa

```
config.json (lista pluginów)        →  bootRuntime
                                          ↓
                   IndexedDB store ←→  Zustand                     OPFS cache pluginów
                                          ↓
                                    Shell + sloty (left/center/right/footer)
                                          ↓
                              plugin-* ładowane z CDN/OPFS przez TOFU
```

Pluginy = ES modules sandboxowane z whitelistą `{ React, store, sdk, ui, icons }`. Bez `fetch`, `className`, `import()`, `localStorage`. Pełen kontrakt: [`packages/sdk/README.md`](../packages/sdk/README.md).

Dane = jeden Zustand `posts` (id, type, parentId, data, createdAt, updatedAt) — wzorzec WordPressa. Pluginy rejestrują typy (`store.registerType`) i widoki (`sdk.registerView`).

## Quickstart

```bash
git clone https://github.com/obieg-zero-dev/core-host
cd core-host && npm install && npm run dev   # :5173

# Instalacja `oz` (raz — symlink, dziala w kazdym shellu):
ln -sf /home/dadmor/code/obirg-zero/CORE-HOST/scripts/oz ~/.local/bin/oz
oz help                                       # cała lista komend
oz guards                                     # zainstaluj pre-push hooki w lokalnych repo
```

## Layout monorepo

```
obieg-zero/
├── CORE-HOST/      Vite + React 19, host pluginów                ← TUTAJ
├── plugins/        plugin-*/src/ → plugin-*/index.mjs (bundle CDN)
├── packages/       @obieg-zero/* (runtime, sdk, mcp-deploy, ...)
└── bq-content/     lokalne paczki BQ → push do org BQ-content
```

Każde repo (`core-host`, `packages`, `plugin-*`) jest osobnym git repo w org `obieg-zero-dev`. Każda paczka kontentowa BQ to osobne repo w org `BQ-content`.

## Promocja: LOCAL → DEV → PROD

```bash
oz promote dev  <plugin-X|core-host|packages>     # → origin/dev
oz promote prod <target> [vX.Y.Z]                  # → origin/main + tag
```

LLM edytuje + commituje lokalnie + STOP. Push wyłącznie user. Mechanizm: 3 warstwy ochrony (pre-push hook + Claude Code hook + brak push tools w MCP).

## Dokumentacja

| Plik | Dla kogo |
|------|----------|
| [`CLAUDE.md`](CLAUDE.md) | LLM/maintainer — reguły, API, konwencje, pętla pracy |
| [`packages/sdk/README.md`](../packages/sdk/README.md) | Autor pluginu — kontrakt SDK, lista UI komponentów |
| [`bq-content/README.md`](../bq-content/README.md) | Autor paczek BQ — format, mechanizm rozszerzeń |
| `oz help` | Każdy — lista komend |

## Stack

| Warstwa | Tech |
|---------|------|
| State | Zustand + persist → IndexedDB |
| UI | React 19 + DaisyUI/Tailwind (komponenty `ui.*` z `@obieg-zero/sdk`) |
| Pluginy | ES modules sandboxowane, ładowane z GitHub (`org/repo@branch`) lub lokalnie |
| Pliki | OPFS — załączniki per `PostRecord` |
| Runtime | `@obieg-zero/runtime` — boot, store, loader, Shell |
