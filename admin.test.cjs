const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const Matter = require('./vendor/matter.min.js');
const gameSource = fs.readFileSync(__dirname + '/game.js', 'utf8');
const skillsSource = fs.readFileSync(__dirname + '/skills.js', 'utf8');
const adminSource = fs.readFileSync(__dirname + '/admin.js', 'utf8');

function boot(search = '?admin', storage = new Map(), historyState = null) {
  const query = new URLSearchParams(search);
  const key = query.has('admin') ? 'slingbreak-save-admin-v1' : query.has('boss') || historyState?.slingbreakSaveSlot === 'boss' ? 'slingbreak-save-boss-v1' : 'slingbreak-save-v1';
  const el = () => ({hidden: true, value: '', handlers: {}, children: [],
    append(child) { this.children.push(child); if (!this.value) this.value = child.value; },
    addEventListener(name, fn) { this.handlers[name] = fn; },
    close() { this.handlers.close?.(); }});
  const elements = Object.fromEntries(['admin-group', 'settings', 'settings-toggle', 'admin-level-form', 'admin-level', 'admin-status', 'admin-boss-form', 'admin-boss']
    .map(id => [id, el()]));
  const location = new URL('https://example.test/game/index.html' + search + '#battle');
  const history = {state: historyState, calls: [], replaceState(state, title, href) {
    this.calls.push({state, title, href});this.state = state;location.href = href;
  }};
  const context = {Matter, console, window: {history}, location, URL, URLSearchParams,
    matchMedia: () => ({matches: true, addEventListener() {}}),
    localStorage: {getItem: name => storage.get(name) ?? null, setItem: (name, value) => { storage.set(name, value); }},
    document: {documentElement: {classList: {toggle() {}}}, createElement: el, getElementById: id => elements[id] || null}};
  vm.createContext(context);
  vm.runInContext(gameSource, context);
  vm.runInContext(skillsSource, context);
  for (const file of ['boss-eye.js', 'boss-forge.js', 'boss-serpent.js', 'boss-clock.js', 'milestone.js']) {
    vm.runInContext(fs.readFileSync(__dirname + '/' + file, 'utf8'), context);
  }
  vm.runInContext(adminSource, context);
  return {game: context.window.Game, elements, read: () => JSON.parse(storage.get(key)), storage, location, history,
    submit: value => { elements['admin-level'].value = value; elements['admin-level-form'].handlers.submit({preventDefault() {}}); },
    submitBoss: value => { elements['admin-boss'].value = value; elements['admin-boss-form'].handlers.submit({preventDefault() {}}); }};
}

test('admin query reveals panel; normal pages cannot submit a level change', () => {
  const plain = boot('');
  assert.equal(plain.elements['admin-group'].hidden, true);
  assert.equal(plain.elements['admin-level-form'].handlers.submit, undefined);
  assert.equal(plain.elements['admin-boss-form'].handlers.submit, undefined);
  for (const query of ['?admin', '?admin=1', '?launcher=1&admin=1']) {
    const session = boot(query);
    assert.equal(session.elements['admin-group'].hidden, false);
    assert.equal(session.elements['admin-level'].value, '1');
  }
});

test('jumping levels rebuilds the board and draft without awarding completion or losing upgrades', () => {
  const {game, elements, read, submit} = boot();
  game.chooseSkill(game.state.draft.options[0]);
  game.state.coins = 2048;
  game.state.up.power = 2;
  game.state.total = 12;
  const owned = Object.keys(game.state.skills);
  submit('12');
  assert.equal(game.state.level, 12);
  assert.equal(game.state.coins, 2048);
  assert.equal(game.state.up.power, 2);
  assert.equal(game.state.total, 12);
  assert.deepEqual(Object.keys(game.state.skills), owned);
  assert.equal(game.phase, 'draft');
  assert.equal(game.state.draft.level, 12);
  assert.equal(game.state.board.level, 12);
  assert.equal(game.state.board.killed, 0);
  assert.equal(game.bricks.length, game.initial);
  assert.equal(read().level, 12);
  assert.equal(read().board.level, 12);
  assert.equal(elements['admin-status'].textContent, '已跳转至第 12 关。');
});

test('invalid or active-round changes leave progress intact', () => {
  const {game, elements, read, submit} = boot();
  game.chooseSkill(game.state.draft.options[0]);
  const board = read().board;
  for (const raw of ['0', '-1', '1.5', '1e2', '100001', '']) {
    submit(raw);
    assert.equal(game.state.level, 1);
    assert.equal(read().board.level, board.level);
  }
  submit('1');
  assert.match(elements['admin-status'].textContent, /无需调整/);
  game.phase = 'flying';
  submit('4');
  assert.equal(game.state.level, 1);
  assert.match(elements['admin-status'].textContent, /结束当前射击/);
});

test('admin progress is independent of existing normal saves across reloads, clearing, and reset', () => {
  const storage = new Map();
  const normal = boot('', storage);
  normal.game.state.coins = 500;
  normal.game.state.up.arrow = 2;
  normal.game.save();
  const oldNormal = storage.get('slingbreak-save-v1');

  const admin = boot('?admin=1', storage);
  assert.equal(admin.game.state.coins, 0, 'first admin visit must not import player progress');
  assert.equal(admin.game.state.up.arrow, 0);
  admin.game.chooseSkill(admin.game.state.draft.options[0]);
  admin.submit('12');
  assert.equal(storage.get('slingbreak-save-v1'), oldNormal);
  assert.equal(boot('', storage).game.state.coins, 500);
  assert.equal(boot('?admin', storage).game.state.level, 12);

  const adminReloaded = boot('?admin', storage);
  adminReloaded.game.chooseSkill(adminReloaded.game.state.draft.options[0]);
  adminReloaded.game.clear();
  assert.equal(adminReloaded.read().level, 13, 'level completion uses the admin key too');
  assert.equal(storage.get('slingbreak-save-v1'), oldNormal);
  adminReloaded.game.reset();
  assert.equal(adminReloaded.read().level, 1);
  assert.equal(boot('', storage).game.state.up.arrow, 2);
  assert.equal(storage.get('slingbreak-save-v1'), oldNormal);
});

test('admin boss selector settles the current level and replaces the next one', () => {
  const {game, elements, read, submitBoss} = boot();
  assert.deepEqual(elements['admin-boss'].children.map(o => o.value), ['eye', 'forge', 'serpent', 'clock']);
  game.chooseSkill(game.state.draft.options[0]);
  game.state.coins = 2048;
  game.state.up.power = 2;
  const owned = Object.keys(game.state.skills);
  const bonus = game.bonus();
  submitBoss('serpent');
  assert.equal(game.state.level, 2);
  assert.equal(game.phase, 'clearing');
  assert.equal(game.state.coins, 2048 + bonus);
  assert.equal(read().bossOverride.boss, 'serpent');
  for (let i = 0; i < 180; i++) game.tick(1 / 60);
  assert.equal(game.boss().boss, 'serpent');
  assert.equal(game.boss().phase, 1);
  assert.equal(game.phase, 'ready');
  assert.equal(game.state.coins, 2048 + bonus);
  assert.equal(game.state.up.power, 2);
  assert.deepEqual(Object.keys(game.state.skills), owned);
  assert.equal(read().milestone.boss, 'serpent');
  assert.equal(elements['admin-level'].value, '2');
  assert.match(elements['admin-status'].textContent, /星渊巨蟒.*第一阶段/);
  game.boss().hp = 1;
  submitBoss('serpent');
  assert.equal(game.state.level, 3, 'same-boss entry settles this fight and advances one level');
  for (let i = 0; i < 180; i++) game.tick(1 / 60);
  assert.equal(game.boss().hp, game.boss().max);
  assert.equal(game.boss().phase, 1);
});

test('admin boss jump rejects invalid IDs, active shots and paused games', () => {
  const {game, elements, submitBoss} = boot();
  for (const id of ['missing', '__proto__']) {
    submitBoss(id);
    assert.equal(game.state.level, 1);
    assert.match(elements['admin-status'].textContent, /有效/);
  }
  game.phase = 'flying';
  submitBoss('eye');
  assert.equal(game.state.level, 1);
  assert.match(elements['admin-status'].textContent, /结束当前射击/);
  game.phase = 'ready';game.paused = true;
  submitBoss('eye');
  assert.equal(game.state.level, 1);
});

test('URL boss entry uses a separate save; admin+boss keeps using the admin slot', () => {
  const storage = new Map();
  const normal = boot('', storage);
  normal.game.state.coins = 500;normal.game.save();
  const admin = boot('?admin', storage);
  admin.game.state.coins = 800;admin.game.save();
  const oldNormal = storage.get('slingbreak-save-v1');
  const oldAdmin = storage.get('slingbreak-save-admin-v1');
  const boss = boot('?boss=forge', storage);
  assert.equal(boss.game.state.level, 2);
  assert.equal(boss.game.phase, 'clearing');
  assert.equal(boss.game.state.coins, boss.game.bonus(1));
  for (let i = 0; i < 180; i++) boss.game.tick(1 / 60);
  assert.equal(boss.game.boss().boss, 'forge');
  assert.equal(boss.elements['admin-group'].hidden, true);
  boss.game.state.coins = 100;boss.game.save();boss.game.reset();
  assert.equal(storage.get('slingbreak-save-v1'), oldNormal);
  assert.equal(storage.get('slingbreak-save-admin-v1'), oldAdmin);
  const combined = boot('?launcher=1&admin=1&boss=clock', storage);
  for (let i = 0; i < 180; i++) combined.game.tick(1 / 60);
  assert.equal(combined.game.boss().boss, 'clock');
  assert.equal(combined.game.state.coins, 800 + combined.game.bonus(1));
  assert.equal(combined.read().milestone.boss, 'clock');
  assert.equal(storage.get('slingbreak-save-v1'), oldNormal);
});

test('boss URLs skip the opening animation and reveal the game immediately', () => {
  const classes = new Set(['intro-pending']);
  let updates = 0;
  const intro = {active: true};
  const context = {Game: {reduced: false, ui: () => updates++}, window: {SlingBreakIntro: intro},
    URLSearchParams, location: {search: '?boss=eye'}, matchMedia: () => ({matches: false}),
    document: {getElementById: () => null, documentElement: {classList: {remove: c => classes.delete(c)}}}};
  vm.runInNewContext(fs.readFileSync(__dirname + '/intro.js', 'utf8'), context);
  assert.equal(intro.active, false);
  assert.equal(classes.has('intro-pending'), false);
  assert.equal(updates, 1);
});

test('successful boss requests remove only the boss parameter without navigation', () => {
  const session = boot('?admin=1&launcher=1&boss=eye&boss=forge&audioDebug=1', new Map(), {existing: 42});
  assert.equal(session.game.phase, 'clearing');
  assert.equal(session.location.pathname, '/game/index.html');
  assert.equal(session.location.search, '?admin=1&launcher=1&audioDebug=1');
  assert.equal(session.location.hash, '#battle');
  assert.equal(session.history.calls.length, 1);
  assert.equal(session.history.state.existing, 42);
  const reload = boot(session.location.search, session.storage, session.history.state);
  assert.equal(reload.game.state.level, 2);
  assert.equal(reload.game.state.coins, session.game.state.coins);
  assert.equal(reload.game.boss().boss, 'eye');
  assert.equal(reload.history.calls.length, 0);
});

test('cleaned boss-only URLs retain the isolated test slot on refresh', () => {
  const storage = new Map();
  const normal = boot('', storage);
  normal.game.state.coins = 500;normal.game.save();
  const oldNormal = storage.get('slingbreak-save-v1');
  const session = boot('?boss=serpent', storage, {existing: 'keep'});
  assert.equal(session.location.search, '');
  assert.equal(session.history.state.slingbreakSaveSlot, 'boss');
  assert.equal(session.history.state.existing, 'keep');
  const reload = boot(session.location.search, storage, session.history.state);
  assert.equal(reload.game.state.level, 2);
  assert.equal(reload.game.boss().boss, 'serpent');
  assert.equal(reload.game.state.coins, session.game.state.coins);
  const resume = boot('?boss=serpent', storage, session.history.state);
  assert.equal(resume.location.search, '', 'an already-requested fight also consumes the parameter');
  assert.equal(resume.game.state.level, 2);
  assert.equal(resume.game.state.coins, session.game.state.coins);
  assert.equal(resume.history.calls.length, 1);
  assert.equal(storage.get('slingbreak-save-v1'), oldNormal);
  assert.equal(boot('', storage).game.state.coins, 500, 'a fresh ordinary visit still uses the player slot');
});

test('invalid boss requests leave the URL and history unchanged', () => {
  const session = boot('?admin=1&boss=missing');
  assert.equal(session.location.search, '?admin=1&boss=missing');
  assert.equal(session.history.calls.length, 0);
  assert.equal(session.game.state.level, 1);
});
