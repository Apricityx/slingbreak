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
      brick: {normal: '#dce2d0', bomb: '#f6a38f', lightning: '#f3e27a', frost: '#a9d8e6', prism: '#cbbbe9', gold: '#e9b85a'},
      brickEdge: {normal: '#c9d1bb'},
      brickInk: {normal: '#4c5a3d', bomb: '#7e2f1f', lightning: '#6b5608', frost: '#1f5e70', prism: '#4f3a7c', gold: '#6a4506'},
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
      intro: {dot: '#cdd3c6', frame: '#343d2d', band: '#91bd55', trail: '#8fbd4f', blocks: ['#b6ed66', '#f67b65', '#dce4d4'], sheen: '#ffffff70'}
    },
    dark: {
      pageMeta: '#131711',
      guide: '#2a3224', label: '#8a947f',
      brick: {normal: '#323b2b', bomb: '#a2503e', lightning: '#c9ad2e', frost: '#2f7488', prism: '#6c5596', gold: '#9a5f1c'},
      brickEdge: {normal: '#232a1e', bomb: '#6e3327', lightning: '#86731c', frost: '#1f4e5c', prism: '#473865', gold: '#653d10'},
      brickInk: {normal: '#c9d3bd', bomb: '#ffe1d8', lightning: '#2a2204', frost: '#dcf4fb', prism: '#efe7ff', gold: '#fff0d6'},
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
