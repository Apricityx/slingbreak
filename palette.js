(() => {
  'use strict';
  // Colour theme. Loaded synchronously in <head> so the first paint already has
  // the right [data-theme]; CSS reads tokens.css, canvas code reads
  // SlingTheme.canvas. The preference ('system' | 'light' | 'dark') lives in its
  // own key so a game reset never changes how the page looks.
  const KEY = 'slingbreak-theme';
  const MODES = ['system', 'light', 'dark'];

  // Canvas palettes. Normal bricks sit in a quiet neutral so the lime accent
  // stays reserved for the core, the aim line and primary actions. Special
  // bricks are separated by hue *and* lightness (lightning is bright lemon,
  // gold is a deeper amber) so they stay distinct for colour-blind players.
  const CANVAS = {
    light: {
      pageMeta: '#f5f6f3',
      guide: '#e3e8da', label: '#6a7162',
      brick: {normal: '#dce2d0', bomb: '#f6a38f', lightning: '#f3e27a', frost: '#a9d8e6', prism: '#cbbbe9', gold: '#e9b85a', void: '#3a2d52', hydra: '#a3dcc4', shard: '#e4d7ff', anchor: '#5d5470', plate: '#6b6258', magma: '#f08a3c', scale: '#58b3bf', star: '#fff1b8', hour: '#e8d7a6'},
      brickEdge: {normal: '#c9d1bb', void: '#241b35', hydra: '#78b89d', shard: '#b9a5e8', anchor: '#433b53', plate: '#4a433c', magma: '#b85a1c', scale: '#3a8a95', star: '#d9c27a', hour: '#b89f62'},
      brickInk: {normal: '#4c5a3d', bomb: '#7e2f1f', lightning: '#6b5608', frost: '#1f5e70', prism: '#4f3a7c', gold: '#6a4506', void: '#e9ddff', hydra: '#1d5a43', shard: '#4a2f86', anchor: '#f3eefc', plate: '#fbf3ea', magma: '#4a1a04', scale: '#06262d', star: '#5a4308', hour: '#3d2e0c'},
      frozen: '#bfe2ec', frozenEdge: '#5d9fb3', crack: '#6f7d5c', flash: '#ffffff',
      obstacle: {shadow: '#4b514b', face: '#777f77', rim: '#a1aaa0', stripe: '#666f66', plate: '#535e51', slot: '#d5dfcc', rivet: '#cad3c4', flash: '#e7f5d3'},
      core: {line: '#8fcb45', ring: '#93c45c', glow: '#a2d865', face: '#b6ed66', frame: '#4f7a2a', heart: '#3f6320', label: '#56703a'},
      sling: {range: '#86a95d', pad: '#eaeee1', frame: '#2a3325', band: '#8fb06a', pouch: '#33462a', knob: '#b5d592', meterOn: '#6f9c41', meterOff: '#d9e1ce'},
      aim: {line: '#4f7d2d', glow: '#d8f3ae', dot: '#6f9c41', keyboard: '#6f9c41', charging: '#f67b65'},
      arrow: {shaft: '#2e3828', fletch: '#9dbc72', trail: '#86a660'},
      bolt: '#bea33e', pointer: '#11150f', coreFlash: '201,239,162',
      text: {float: '#48652c', outline: '#fafbf7', sub: '#5a6453', coreTitle: '#3b5d1f', coreBonus: '#4d7a26'},
      heat: ['#56703a', '#3a7f1c', '#a85f0c', '#c8431d'],
      sawDisc: '#f4f2e9',
      rift: {crack: '#140a24', crackEdge: '#9b6bff', sclera: '#f6f0ff', scleraShade: '#c9b6f2', iris: '#8a5cf0', irisDeep: '#34186e', irisRage: '#e0453a', pupil: '#0b0612', shield: '#8f68f5', chain: '#7d62b8', beam: '#b48cff', heal: '#2fb57e', well: '#0d0716', wellRim: '#8a5cf0', weak: '#e2493a', text: '#5b3aa6'},
      forge: {iron: '#3b342f', ironEdge: '#6b6258', ember: '#f08a3c', molten: '#ffb347', core: '#fff1c7', glow: '#e2562a', crack: '#ff7a2e', smoke: '#8a7f75', wind: '#b09a82', text: '#9a3f12', weak: '#d8401f'},
      serpent: {body: '#1f5f6b', bodyLight: '#58b3bf', belly: '#bfe9ee', head: '#16464f', eye: '#ffd166', glow: '#3ec8d6', star: '#e0a92e', spark: '#f2c14e', portal: '#0b2a30', text: '#12606b', weak: '#e2493a', twin: '#d9a53a', sky: '#8fb7c0', maw: '#3a0f1a', dark: '#06141c', horn: '#e8d9a8', nebula: '#7fc4d0', nebula2: '#c9a2e0', tether: '#e0a92e'},
      clock: {face: '#1b2340', rim: '#b8923a', brass: '#d9ae4f', brassDeep: '#7a5a1c', hand: '#2a2f45', handEdge: '#e8c870', gem: '#4fb3e8', gemDeep: '#1b4f8a', stop: '#6fa8d8', ward: '#e0a92e', ghost: '#6f9fd8', text: '#7a5a1c', weak: '#e2493a', tick: '#b8a574'},
      intro: {dot: '#cdd3c6', frame: '#343d2d', band: '#91bd55', trail: '#8fbd4f', blocks: ['#b6ed66', '#f67b65', '#dce4d4'], sheen: '#ffffff70'}
    },
    dark: {
      pageMeta: '#131711',
      guide: '#2a3224', label: '#8a947f',
      brick: {normal: '#323b2b', bomb: '#a2503e', lightning: '#c9ad2e', frost: '#2f7488', prism: '#6c5596', gold: '#9a5f1c', void: '#1c1528', hydra: '#2d6b55', shard: '#5b4a8a', anchor: '#3d3548', plate: '#4a443e', magma: '#b04a14', scale: '#1f6f7a', star: '#b8962a', hour: '#6e5c30'},
      brickEdge: {normal: '#232a1e', bomb: '#6e3327', lightning: '#86731c', frost: '#1f4e5c', prism: '#473865', gold: '#653d10', void: '#0e0a15', hydra: '#1e4a3b', shard: '#3d3163', anchor: '#27212f', plate: '#2e2a26', magma: '#6e2c0a', scale: '#134850', star: '#6f5a14', hour: '#56482a'},
      brickInk: {normal: '#c9d3bd', bomb: '#ffe1d8', lightning: '#2a2204', frost: '#dcf4fb', prism: '#efe7ff', gold: '#fff0d6', void: '#d9c7ff', hydra: '#e2fff3', shard: '#f4eeff', anchor: '#e9e2f5', plate: '#efe6dc', magma: '#fff0e0', scale: '#e0fbff', star: '#2a1f02', hour: '#fff6dc'},
      frozen: '#285f6f', frozenEdge: '#8fd0e2', crack: '#8d9a7c', flash: '#ffffff',
      obstacle: {shadow: '#0b0d0b', face: '#5a625a', rim: '#8b948a', stripe: '#4c544c', plate: '#3b4439', slot: '#aeb9a4', rivet: '#9ca69a', flash: '#dbeec3'},
      core: {line: '#a4d65e', ring: '#8ab852', glow: '#b6ed66', face: '#b6ed66', frame: '#4f7a2a', heart: '#3f6320', label: '#a3d465'},
      sling: {range: '#6f8f4c', pad: '#20271b', frame: '#c9d3bd', band: '#9dc26f', pouch: '#e0e8d4', knob: '#b5d592', meterOn: '#a3d465', meterOff: '#343d2c'},
      aim: {line: '#b6ed66', glow: '#6f9c41', dot: '#a3d465', keyboard: '#a3d465', charging: '#f67b65'},
      arrow: {shaft: '#e3eadb', fletch: '#9dc26f', trail: '#8fb06a'},
      bolt: '#f0d35a', pointer: '#eef3e7', coreFlash: '182,237,102',
      text: {float: '#c4f589', outline: '#131711', sub: '#a3ad98', coreTitle: '#c4f589', coreBonus: '#a3d465'},
      heat: ['#9fb98a', '#8fd14f', '#f0a13a', '#ff7043'],
      sawDisc: '#2a3124',
      rift: {crack: '#05020a', crackEdge: '#b58cff', sclera: '#efe6ff', scleraShade: '#a891dc', iris: '#9d72ff', irisDeep: '#3b1f7a', irisRage: '#ff5a4a', pupil: '#07030d', shield: '#a88bff', chain: '#9a84d0', beam: '#c7a8ff', heal: '#6fe3b0', well: '#07030d', wellRim: '#a07cff', weak: '#ff6b5a', text: '#cbb4ff'},
      forge: {iron: '#1a1512', ironEdge: '#4a443e', ember: '#ff8c3a', molten: '#ffc061', core: '#fff4d6', glow: '#ff6a33', crack: '#ff8a3d', smoke: '#6b625a', wind: '#8a7d70', text: '#ffb27a', weak: '#ff6a4a'},
      serpent: {body: '#1f6f7a', bodyLight: '#5fd0dc', belly: '#bff4f8', head: '#0e3a42', eye: '#ffd166', glow: '#4fe0ee', star: '#f5cf60', spark: '#fff4c4', portal: '#02141a', text: '#8fe6ee', weak: '#ff6b5a', twin: '#e8b54a', sky: '#5f8f99', maw: '#2a0610', dark: '#010a0e', horn: '#f2e6bf', nebula: '#2f7f8c', nebula2: '#6e4a8c', tether: '#ffe08a'},
      clock: {face: '#0a0f22', rim: '#d9ae4f', brass: '#e8c060', brassDeep: '#8a6a2a', hand: '#e8dcc0', handEdge: '#ffd878', gem: '#6fc8ff', gemDeep: '#2a63a8', stop: '#8fc0f0', ward: '#ffd060', ghost: '#a8cdf8', text: '#f0d38a', weak: '#ff6b5a', tick: '#8a7d5a'},
      intro: {dot: '#333b2d', frame: '#d6dfcb', band: '#9dc26f', trail: '#8fbd4f', blocks: ['#b6ed66', '#f67b65', '#3a4432'], sheen: '#ffffff30'}
    }
  };

  const store = (() => { try { return window.localStorage || null; } catch { return null; } })();
  const query = typeof matchMedia === 'function' ? matchMedia('(prefers-color-scheme: dark)') : null;
  const read = () => { try { const v = store?.getItem(KEY); return MODES.includes(v) ? v : 'system'; } catch { return 'system'; } };
  const resolve = mode => mode === 'system' ? (query?.matches ? 'dark' : 'light') : mode;

  const listeners = new Set();
  const theme = {
    modes: MODES,
    mode: read(),
    resolved: 'light',
    canvas: CANVAS.light,
    palettes: CANVAS,
    onChange(fn) { listeners.add(fn); return () => listeners.delete(fn); },
    set(mode) {
      if (!MODES.includes(mode)) return;
      theme.mode = mode;
      try { store?.setItem(KEY, mode); } catch {}
      apply();
    }
  };

  function apply() {
    const resolved = resolve(theme.mode), changed = resolved !== theme.resolved;
    theme.resolved = resolved;
    theme.canvas = CANVAS[resolved];
    const root = typeof document !== 'undefined' ? document.documentElement : null;
    if (root?.setAttribute) {
      root.setAttribute('data-theme', resolved);
      root.setAttribute('data-theme-mode', theme.mode);
      if (root.style) root.style.colorScheme = resolved;
    }
    const meta = typeof document !== 'undefined' ? document.querySelector?.('meta[name="theme-color"]') : null;
    meta?.setAttribute?.('content', theme.canvas.pageMeta);
    listeners.forEach(fn => { try { fn(theme, changed); } catch (error) { console.error(error); } });
  }

  query?.addEventListener?.('change', () => { if (theme.mode === 'system') apply(); });
  window.SlingTheme = theme;
  apply();
})();
