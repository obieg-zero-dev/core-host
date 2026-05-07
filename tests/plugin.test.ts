import 'fake-indexeddb/auto'
import { describe, it, expect, beforeEach } from 'vitest'
import {
  useHostStore, log, clearLog, getAllPlugins, registerView, registerParser, registerAction,
  getViews, getParsers, getActions, unregisterPlugin, _resetRegistries, checkIntegrity,
} from '../../packages/runtime/src/plugin'
import { createStore, _resetForTests } from '../../packages/runtime/src/store'
import type { Store } from '../../packages/runtime/src/store'

beforeEach(() => {
  useHostStore.setState({ plugins: [], logs: [], activeId: null, leftOpen: false, progress: false }, true)
  _resetRegistries()
})

// ── Log ─────────────────────────────────────────────────────────────

describe('log', () => {
  it('appends log entries', () => {
    log('hello')
    log('error msg', 'error')
    const logs = useHostStore.getState().logs
    expect(logs.length).toBe(2)
    expect(logs[0].text).toBe('hello')
    expect(logs[0].level).toBe('info')
    expect(logs[1].level).toBe('error')
  })

  it('clearLog empties logs', () => {
    log('x'); log('y')
    clearLog()
    expect(useHostStore.getState().logs).toEqual([])
  })

  it('keeps max 200 entries', () => {
    for (let i = 0; i < 210; i++) log(`msg-${i}`)
    expect(useHostStore.getState().logs.length).toBe(200)
  })
})

// ── Contribution points ─────────────────────────────────────────────

describe('contribution points', () => {
  it('registerView + getViews', () => {
    const Comp = () => null
    registerView('test.center', { pluginId: 'test', slot: 'center', component: Comp })
    const views = getViews()
    expect(views.length).toBe(1)
    expect(views[0].slot).toBe('center')
    expect(views[0].pluginId).toBe('test')
  })

  it('getViews filters by pluginId', () => {
    const Comp = () => null
    registerView('a.left', { pluginId: 'a', slot: 'left', component: Comp })
    registerView('b.left', { pluginId: 'b', slot: 'left', component: Comp })
    expect(getViews('a').length).toBe(1)
    expect(getViews('b').length).toBe(1)
    expect(getViews().length).toBe(2)
  })

  it('registerParser + getParsers', () => {
    registerParser('test.csv', { pluginId: 'test', accept: '.csv', targetType: 'rate', parse: () => [] })
    expect(getParsers().length).toBe(1)
    expect(getParsers('rate').length).toBe(1)
    expect(getParsers('other').length).toBe(0)
  })

  it('registerAction + getActions', () => {
    registerAction('test.export', { pluginId: 'test', node: 'button' as any })
    expect(getActions().length).toBe(1)
  })
})

// ── Plugin registry ─────────────────────────────────────────────────

describe('unregisterPlugin', () => {
  it('removes plugin and its contribution points', () => {
    const Comp = () => null
    registerView('x.center', { pluginId: 'x', slot: 'center', component: Comp })
    registerParser('x.csv', { pluginId: 'x', accept: '.csv', targetType: 't', parse: () => [] })
    registerAction('x.btn', { pluginId: 'x', node: 'b' as any })
    useHostStore.setState({ plugins: [{ id: 'x', label: 'X' }] })

    unregisterPlugin('x')

    expect(getAllPlugins().length).toBe(0)
    expect(getViews().length).toBe(0)
    expect(getParsers().length).toBe(0)
    expect(getActions().length).toBe(0)
  })

  it('does not affect other plugins', () => {
    const Comp = () => null
    registerView('a.center', { pluginId: 'a', slot: 'center', component: Comp })
    registerView('b.center', { pluginId: 'b', slot: 'center', component: Comp })
    useHostStore.setState({ plugins: [{ id: 'a', label: 'A' }, { id: 'b', label: 'B' }] })

    unregisterPlugin('a')

    expect(getAllPlugins().length).toBe(1)
    expect(getAllPlugins()[0].id).toBe('b')
    expect(getViews().length).toBe(1)
    expect(getViews()[0].pluginId).toBe('b')
  })
})

// ── TOFU integrity ──────────────────────────────────────────────────

describe('checkIntegrity (TOFU)', () => {
  let store: Store
  beforeEach(async () => { _resetForTests(); store = await createStore() })

  it('zapisuje hash przy pierwszym pobraniu wersjonowanego pluginu', () => {
    checkIntegrity('org/p@v1.0.0', 'h1', store)
    expect(store.get('integrity:org/p@v1.0.0')?.data.hash).toBe('h1')
  })

  it('blokuje gdy hash sie zmienil', () => {
    checkIntegrity('org/p@v1.0.0', 'h1', store)
    expect(() => checkIntegrity('org/p@v1.0.0', 'h2', store)).toThrow(/zostal zmodyfikowany|został zmodyfikowany/)
  })

  it('przepuszcza gdy hash ten sam', () => {
    checkIntegrity('org/p@v1.0.0', 'h1', store)
    expect(() => checkIntegrity('org/p@v1.0.0', 'h1', store)).not.toThrow()
  })

  it('pomija lokalne pluginy (./)', () => {
    checkIntegrity('./local', 'h1', store)
    expect(store.get('integrity:./local')).toBeUndefined()
  })

  it('pomija nie-wersjonowane @main', () => {
    checkIntegrity('org/p@main', 'h1', store)
    expect(store.get('integrity:org/p@main')).toBeUndefined()
  })

  it('chroni store:// specs', () => {
    checkIntegrity('store://abc', 'h1', store)
    expect(() => checkIntegrity('store://abc', 'h2', store)).toThrow()
  })
})

