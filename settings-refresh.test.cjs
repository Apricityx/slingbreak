const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(__dirname + '/settings.js', 'utf8');

function boot({href = 'https://example.test/index.html?launcher=1#game', fail = false} = {}) {
  const requests = [], navigations = [], saves = [], warnings = [];
  const el = (extra = {}) => ({disabled: false, textContent: '', handlers: {}, addEventListener(name, fn) { this.handlers[name] = fn; }, ...extra});
  const radios = ['system', 'light', 'dark'].map(value => el({value}));
  const elements = {
    'settings-toggle': el(), settings: el({querySelectorAll: () => radios, showModal() {}, close() {}}),
    'close-settings': el(), 'theme-hint': el(), 'refresh-page': el(), 'refresh-status': el()
  };
  const game = {phase: 'ready', save: () => saves.push('save')};
  const fetch = async (url, options) => {
    requests.push({url, options});
    if (fail && url.endsWith('fresh.js')) throw new Error('offline');
    return url.includes('index.html')
      ? {ok: true, text: async () => '<link rel="stylesheet" href="fresh.css"><script src="fresh.js"></script>'}
      : {ok: true, arrayBuffer: async () => new ArrayBuffer(0)};
  };
  class DOMParser {
    parseFromString(html) {
      const nodes = [...html.matchAll(/(?:src|href)="([^"]+)"/g)]
        .map(match => ({getAttribute: name => name === 'src' || name === 'href' ? match[1] : null}));
      return {querySelectorAll: () => nodes};
    }
  }
  vm.runInNewContext(source, {
    window: {Game: game, SlingTheme: {mode: 'system', resolved: 'light', onChange() {}}},
    document: {getElementById: id => elements[id] || null},
    location: {href, replace: url => navigations.push(url)}, URL, fetch, DOMParser,
    console: {warn: (...args) => warnings.push(args)}
  });
  return {elements, game, requests, navigations, saves, warnings};
}

test('settings update button downloads fresh document assets then navigates without clearing saves', async () => {
  const {elements, requests, navigations, saves} = boot();
  const refresh = elements['refresh-page'];
  await refresh.handlers.click();
  assert.equal(requests.length, 3);
  assert.deepEqual(requests.map(r => r.options.cache), ['reload', 'reload', 'reload']);
  assert.deepEqual(requests.slice(1).map(r => r.url).sort(), ['https://example.test/fresh.css', 'https://example.test/fresh.js']);
  assert.equal(navigations.length, 1);
  const next = new URL(navigations[0]);
  assert.equal(next.searchParams.get('launcher'), '1');
  assert.ok(next.searchParams.get('_refresh'));
  assert.equal(next.hash, '#game');
  assert.deepEqual(saves, ['save']);
});

test('failed download keeps current page and allows retry', async () => {
  const {elements, requests, navigations, saves, warnings} = boot({fail: true});
  const refresh = elements['refresh-page'];
  await refresh.handlers.click();
  assert.equal(refresh.disabled, false);
  assert.match(elements['refresh-status'].textContent, /失败/);
  assert.equal(requests.length, 3);
  assert.deepEqual(navigations, []);
  assert.deepEqual(saves, []);
  assert.equal(warnings.length, 1);
});

test('file pages reload without fetch and preserve existing query flags', async () => {
  const {elements, requests, navigations} = boot({href: 'file:///android_asset/index.html?launcher=1'});
  await elements['refresh-page'].handlers.click();
  assert.deepEqual(requests, []);
  assert.equal(new URL(navigations[0]).searchParams.get('launcher'), '1');
});
