const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(__dirname + '/settings.js', 'utf8');

function boot({userAgent = 'iPhone', platform = 'iPhone', maxTouchPoints = 5, standalone = false, displayMode = false, homeScreen} = {}) {
  const listeners = {};
  const el = (extra = {}) => ({textContent: '', handlers: {}, addEventListener(name, fn) { this.handlers[name] = fn; }, ...extra});
  const elements = {
    'settings-toggle': el(), settings: el({querySelectorAll: () => [], showModal() {}, close() {}}),
    'install-app': el(), 'install-status': el()
  };
  const window = {SlingTheme: {mode: 'system', resolved: 'light', onChange() {}},
    SlingHomeScreen: homeScreen,
    matchMedia: () => ({matches: displayMode}), addEventListener: (name, fn) => { listeners[name] = fn; }};
  vm.runInNewContext(source, {window, navigator: {userAgent, platform, maxTouchPoints, standalone},
    document: {getElementById: id => elements[id] || null}});
  return {elements, listeners};
}

test('iPhone Safari button explains the manual Share menu step', async () => {
  const {elements} = boot();
  await elements['install-app'].handlers.click();
  assert.match(elements['install-status'].textContent, /分享.*添加到主屏幕/);
  assert.match(elements['install-status'].textContent, /无法直接打开/);
});

test('iPad desktop-style user agent receives Safari instructions', async () => {
  const {elements} = boot({userAgent: 'Macintosh', platform: 'MacIntel'});
  await elements['install-app'].handlers.click();
  assert.match(elements['install-status'].textContent, /分享.*添加到主屏幕/);
});

test('the Apple install entry opens the visible guide and uses embedded-browser instructions', async () => {
  let opened = 0;
  const {elements} = boot({homeScreen: {
    instructions: () => '请在 Safari 中打开，再点分享 → 添加到主屏幕。',
    showGuide: () => opened++
  }});
  await elements['install-app'].handlers.click();
  assert.equal(opened, 1);
  assert.match(elements['install-status'].textContent, /Safari/);
});

test('an installed Apple page does not open the guide', async () => {
  let opened = 0;
  const {elements} = boot({standalone: true, homeScreen: {showGuide: () => opened++}});
  await elements['install-app'].handlers.click();
  assert.equal(opened, 0);
});

test('other iOS browsers and Android receive device-specific manual paths', async () => {
  const ios = boot({userAgent: 'Mozilla/5.0 (iPhone) CriOS/130', platform: 'iPhone'});
  await ios.elements['install-app'].handlers.click();
  assert.match(ios.elements['install-status'].textContent, /分享.*添加到主屏幕/);
  const android = boot({userAgent: 'Mozilla/5.0 (Linux; Android 15) Chrome/130', platform: 'Linux'});
  await android.elements['install-app'].handlers.click();
  assert.match(android.elements['install-status'].textContent, /浏览器菜单.*安装应用.*添加到主屏幕/);
});

test('desktop browsers explain their own install menu', async () => {
  const cases = [
    ['Mozilla/5.0 (Macintosh) Version/26 Safari/605', /文件.*添加到程序坞/],
    ['Mozilla/5.0 (Windows NT 10.0) Chrome/130', /地址栏.*安装.*浏览器菜单/],
    ['Mozilla/5.0 (Windows NT 10.0) Edg/130', /地址栏.*安装.*浏览器菜单/],
    ['Mozilla/5.0 (Windows NT 10.0) Firefox/130', /Firefox.*Chrome 或 Edge/]
  ];
  for (const [userAgent, instructions] of cases) {
    const {elements} = boot({userAgent, platform: 'Win32', maxTouchPoints: 0});
    await elements['install-app'].handlers.click();
    assert.match(elements['install-status'].textContent, instructions);
  }
});

test('installed pages do not offer to install again', async () => {
  for (const flags of [{standalone: true}, {displayMode: true}]) {
    const {elements} = boot(flags);
    await elements['install-app'].handlers.click();
    assert.match(elements['install-status'].textContent, /已从主屏幕打开/);
  }
});

test('uses a browser install prompt when one is available, with a manual fallback', async () => {
  const {elements, listeners} = boot({userAgent: 'Android', platform: 'Linux', maxTouchPoints: 1});
  let prompted = 0, prevented = 0;
  listeners.beforeinstallprompt({preventDefault() { prevented++; }, prompt() { prompted++; },
    userChoice: Promise.resolve({outcome: 'accepted'})});
  await elements['install-app'].handlers.click();
  assert.equal(prevented, 1);
  assert.equal(prompted, 1);
  assert.match(elements['install-status'].textContent, /安装请求已发送/);
  await elements['install-app'].handlers.click();
  assert.equal(prompted, 1, 'a deferred prompt can only be used once');
  assert.match(elements['install-status'].textContent, /浏览器菜单/);
  listeners.appinstalled();
  assert.equal(elements['install-status'].textContent, '已添加到主屏幕。');
});

test('cancelled install and failed prompts still show manual instructions', async () => {
  const {elements, listeners} = boot({userAgent: 'Android', platform: 'Linux', maxTouchPoints: 1});
  listeners.beforeinstallprompt({preventDefault() {}, prompt() {}, userChoice: Promise.resolve({outcome: 'dismissed'})});
  await elements['install-app'].handlers.click();
  assert.match(elements['install-status'].textContent, /浏览器菜单/);
  listeners.beforeinstallprompt({preventDefault() {}, prompt() { throw new Error('blocked'); }});
  await elements['install-app'].handlers.click();
  assert.match(elements['install-status'].textContent, /浏览器菜单/);
});

test('settings entry is hidden in both launcher states', () => {
  const html = fs.readFileSync(__dirname + '/index.html', 'utf8');
  const css = fs.readFileSync(__dirname + '/launcher-mode.css', 'utf8');
  assert.match(html, /class="settings-group install-group"[\s\S]*?id="install-app"/);
  assert.match(css, /\.launcher-mode \.install-group,\.launcher-mode-pending \.install-group\{display:none\}/);
});

test('install manifest and real icons work from a nested deployment path', () => {
  const manifest = JSON.parse(fs.readFileSync(__dirname + '/manifest.json', 'utf8'));
  const html = fs.readFileSync(__dirname + '/index.html', 'utf8');
  assert.match(html, /<link rel="manifest" href="manifest\.json">/);
  assert.match(html, /<link rel="apple-touch-icon" href="icons\/apple-touch-icon\.png">/);
  assert.equal(manifest.display, 'standalone');
  const base = 'https://example.test/games/slingbreak/manifest.json';
  assert.equal(new URL(manifest.start_url, base).href, 'https://example.test/games/slingbreak/index.html');
  assert.equal(new URL(manifest.scope, base).href, 'https://example.test/games/slingbreak/');
  assert.equal(new URL(manifest.id, base).href, 'https://example.test/games/slingbreak/index.html');
  for (const [src, size] of [['icons/apple-touch-icon.png', 180],
    ...manifest.icons.map(icon => [icon.src, parseInt(icon.sizes)])]) {
    const image = fs.readFileSync(__dirname + '/' + src);
    assert.equal(image.subarray(1, 4).toString(), 'PNG');
    assert.equal(image.readUInt32BE(16), size, src);
    assert.equal(image.readUInt32BE(20), size, src);
  }
  assert.deepEqual(manifest.icons.map(icon => icon.sizes), ['192x192', '512x512']);
});
