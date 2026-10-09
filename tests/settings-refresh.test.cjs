const ROOT=require('node:path').resolve(__dirname,'..');
const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(ROOT + '/game/src/ui/settings.js', 'utf8');

function boot({href = 'https://example.test/index.html?launcher=1#game', fail = false, navigationFail = false} = {}) {
  const requests = [], navigations = [], saves = [], warnings = [];
  const el = (extra = {}) => ({disabled: false, textContent: '', handlers: {}, addEventListener(name, fn) { this.handlers[name] = fn; }, ...extra});
  const radios = ['system', 'light', 'dark'].map(value => el({value}));
  const elements = {
    'settings-toggle': el(), settings: el({querySelectorAll: () => radios, showModal() {}, close() {}}),
    'close-settings': el(), 'theme-hint': el(), 'refresh-page': el(), 'refresh-status': el(), 'home-link': el(), 'client-options': el({hidden: true})
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
    location: {href, search: new URL(href).search, replace: url => navigations.push(url), assign: url => {
      if (navigationFail) throw new Error('navigation denied');
      navigations.push(url);
    }}, URL, URLSearchParams, fetch, DOMParser,
    console: {warn: (...args) => warnings.push(args)}
  });
  return {elements, game, requests, navigations, saves, warnings};
}

test('client mode changes page refresh into a native update-check request', async () => {
  const {elements, requests, navigations, saves} = boot({href: 'resource://android/assets/game/index.html?client=1'});
  const refresh = elements['refresh-page'];
  assert.equal(refresh.textContent, '检查更新');
  assert.equal(elements['home-link'].href, './index.html?client=1');
  assert.match(elements['refresh-status'].textContent, /客户端更新/);
  await refresh.handlers.click();
  assert.deepEqual(requests, []);
  assert.deepEqual(navigations, ['slingbreak://check-update']);
  assert.deepEqual(saves, []);
  assert.equal(refresh.disabled, false);
  await refresh.handlers.click();
  assert.deepEqual(navigations, ['slingbreak://check-update', 'slingbreak://check-update']);
  assert.match(elements['refresh-status'].textContent, /客户端提示/);
});

test('client mode in a browser or another resource document never reloads or sends native commands', async () => {
  for (const href of ['https://example.test/?client=1', 'file:///android_asset/index.html?client=1',
    'resource://other/assets/game/index.html?client=1', 'resource://android/assets/other.html?client=1']) {
    const {elements, requests, navigations} = boot({href});
    await elements['refresh-page'].handlers.click();
    assert.match(elements['refresh-status'].textContent, /Android 客户端/);
    assert.equal(elements['refresh-page'].disabled, false);
    assert.deepEqual(requests, []);
    assert.deepEqual(navigations, []);
  }
});

test('X5 fixed HTTPS origin supports update commands without exposing them to lookalike hosts', async () => {
  const trusted=boot({href:'https://appassets.androidplatform.net/assets/game/index.html?client=1'});
  trusted.elements['refresh-page'].handlers.click();
  trusted.elements['client-options'].handlers.click();
  assert.deepEqual(trusted.navigations,['slingbreak://check-update','slingbreak://client-options']);
  assert.deepEqual(trusted.requests,[]);
  for(const href of ['http://appassets.androidplatform.net/assets/game/index.html?client=1',
    'https://appassets.androidplatform.net.evil.test/assets/game/index.html?client=1',
    'https://appassets.androidplatform.net/assets/game/other.html?client=1',
    'https://appassets.androidplatform.net:444/assets/game/index.html?client=1']){
    const denied=boot({href});
    denied.elements['refresh-page'].handlers.click();
    assert.deepEqual(denied.navigations,[]);
  }
});

test('a failed client navigation remains retryable without the removed toolbar', async () => {
  const {elements, requests, navigations, warnings} = boot({href: 'resource://android/assets/game/index.html?client=1', navigationFail: true});
  await elements['refresh-page'].handlers.click();
  assert.match(elements['refresh-status'].textContent, /稍后重试/);
  assert.equal(elements['refresh-page'].disabled, false);
  assert.deepEqual(requests, []);
  assert.deepEqual(navigations, []);
  assert.equal(warnings.length, 1);
});

test('only client=1 activates the native update action', async () => {
  const {elements, requests, navigations} = boot({href: 'https://example.test/index.html?client=0&launcher=1'});
  await elements['refresh-page'].handlers.click();
  assert.equal(requests.length, 3);
  assert.equal(new URL(navigations[0]).searchParams.get('client'), '0');
});

test('client options move native update settings into the page, not a persistent toolbar',async()=>{
  const {elements,navigations}=boot({href:'resource://android/assets/game/index.html?client=1'});
  assert.equal(elements['client-options'].hidden,false);
  elements['client-options'].handlers.click();
  assert.deepEqual(navigations,['slingbreak://client-options']);
  const browser=boot();
  assert.equal(browser.elements['client-options'].hidden,true);
  assert.equal(browser.elements['client-options'].handlers.click,undefined);
});

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
