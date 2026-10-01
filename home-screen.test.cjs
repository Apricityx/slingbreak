const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(__dirname + '/home-screen.js', 'utf8');

function boot({userAgent = 'iPhone', platform = 'iPhone', maxTouchPoints = 5, standalone = false,
  displayMode = false, clipboard, withDialog = true} = {}) {
  const elements = {};
  for (const id of ['home-screen-guide', 'home-screen-status', 'home-screen-url', 'home-screen-step-open',
    'home-screen-step-add', 'home-screen-step-launch', 'close-home-screen-guide', 'copy-home-screen-url']) {
    elements[id] = {textContent: '', value: '', handlers: {}, addEventListener(name, fn) { this.handlers[name] = fn; }};
  }
  let shows = 0, focused = 0, selected = 0;
  const dialog = elements['home-screen-guide'];
  Object.assign(dialog, {open: false, showModal() { shows++; this.open = true; }, close() { this.open = false; }});
  Object.assign(elements['home-screen-url'], {focus() { focused++; }, select() { selected++; }, setSelectionRange() {}});
  const window = {location: {href: 'https://example.test/games/slingbreak/index.html?test=1'},
    matchMedia: () => ({matches: displayMode})};
  vm.runInNewContext(source, {window, navigator: {userAgent, platform, maxTouchPoints, standalone, clipboard},
    document: {getElementById: id => id === 'home-screen-guide' && !withDialog ? null : elements[id]}});
  return {api: window.SlingHomeScreen, elements, shows: () => shows, focused: () => focused, selected: () => selected};
}

test('iPhone opens a three-step guide with honest fullscreen limitations', () => {
  const {api, elements, shows} = boot();
  assert.equal(api.isAppleMobile(), true);
  api.showGuide();
  assert.equal(elements['home-screen-guide'].open, true);
  assert.match(elements['home-screen-step-add'].textContent, /分享.*添加到主屏幕/);
  assert.match(elements['home-screen-step-launch'].textContent, /作为网页 App 打开/);
  assert.equal(elements['home-screen-url'].value, 'https://example.test/games/slingbreak/index.html?test=1');
  api.showGuide();
  assert.equal(shows(), 1, 'do not reopen an already open modal');
  const html = fs.readFileSync(__dirname + '/index.html', 'utf8');
  assert.match(html, /不等同于原生全屏/);
  assert.ok(html.indexOf('src="home-screen.js"') < html.indexOf('src="fullscreen.js"'));
});

test('iPad desktop user agent is recognized, but desktop Mac is not', () => {
  assert.equal(boot({userAgent: 'Macintosh', platform: 'MacIntel'}).api.isAppleMobile(), true);
  const mac = boot({userAgent: 'Macintosh', platform: 'MacIntel', maxTouchPoints: 0});
  assert.equal(mac.api.isAppleMobile(), false);
  mac.api.showGuide();
  assert.equal(mac.shows(), 0);
});

test('WeChat and other embedded browsers explain how to open Safari', () => {
  for (const token of ['MicroMessenger', 'QQ/9', 'Weibo', 'FBAV', 'Instagram', 'Line/']) {
    const {api, elements} = boot({userAgent: 'iPhone ' + token});
    api.showGuide();
    assert.match(elements['home-screen-step-open'].textContent, /右上角.*Safari.*复制/);
    assert.match(elements['home-screen-status'].textContent, /Safari/);
  }
});

test('standalone launch is detected through either Apple or standard flags', () => {
  for (const flags of [{standalone: true}, {displayMode: true}]) {
    const {api, elements} = boot(flags);
    assert.equal(api.isStandalone(), true);
    api.showGuide();
    assert.match(elements['home-screen-status'].textContent, /无需重复添加/);
  }
});

test('copy uses the clipboard when available', async () => {
  let copied;
  const {api, elements} = boot({clipboard: {writeText: async value => { copied = value; }}});
  api.showGuide();
  await elements['copy-home-screen-url'].handlers.click();
  assert.equal(copied, elements['home-screen-url'].value);
  assert.match(elements['home-screen-status'].textContent, /链接已复制/);
});

test('missing or denied clipboard selects the link and offers manual copying', async () => {
  for (const clipboard of [undefined, {writeText: async () => { throw new Error('denied'); }}]) {
    const {api, elements, focused, selected} = boot({clipboard});
    api.showGuide();
    await elements['copy-home-screen-url'].handlers.click();
    assert.equal(focused(), 1);
    assert.equal(selected(), 1);
    assert.match(elements['home-screen-status'].textContent, /长按链接/);
  }
});

test('guide closes by button or backdrop', () => {
  const {api, elements} = boot();
  const dialog = elements['home-screen-guide'];
  api.showGuide();
  elements['close-home-screen-guide'].handlers.click();
  assert.equal(dialog.open, false);
  api.showGuide();
  dialog.handlers.click({target: elements['home-screen-step-open']});
  assert.equal(dialog.open, true);
  dialog.handlers.click({target: dialog});
  assert.equal(dialog.open, false);
});

test('missing guide markup is harmless', () => {
  assert.doesNotThrow(() => boot({withDialog: false}).api.showGuide());
});
