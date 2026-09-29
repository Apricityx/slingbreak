(() => {
  'use strict';
  // Settings dialog, opened from the gear button beside the fullscreen toggle.
  // Unlike the fullscreen toggle it stays visible in launcher mode.
  const theme = window.SlingTheme;
  const game = window.Game;
  const button = document.getElementById('settings-toggle');
  const dialog = document.getElementById('settings');
  if (!theme || !button || !dialog) return;

  const close = document.getElementById('close-settings');
  const hint = document.getElementById('theme-hint');
  const radios = [...dialog.querySelectorAll('input[name="theme"]')];
  const volume = document.getElementById('sound-volume');
  const volumeValue = document.getElementById('sound-volume-value');
  const reduced = () => typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
  const HINTS = {
    system: resolved => `当前跟随系统 · ${resolved === 'dark' ? '深色' : '亮色'}`,
    light: () => '始终使用亮色',
    dark: () => '始终使用深色'
  };

  const render = () => {
    for (const radio of radios) radio.checked = radio.value === theme.mode;
    if (hint) hint.textContent = HINTS[theme.mode](theme.resolved);
  };

  // Colours cross-fade for one beat instead of snapping; the canvas repaints on
  // its next frame, so a short transition keeps the page and board in step.
  let fadeTimer = 0;
  const choose = mode => {
    if (mode === theme.mode) return;
    const root = document.documentElement;
    if (!reduced()) {
      root.classList.add('theme-switching');
      clearTimeout(fadeTimer);
      fadeTimer = setTimeout(() => root.classList.remove('theme-switching'), 320);
    }
    theme.set(mode);
  };

  for (const radio of radios) radio.addEventListener('change', () => { if (radio.checked) choose(radio.value); });
  theme.onChange(render);

  if (game && volume && volumeValue) {
    const showVolume = () => { volume.value = String(game.state.volume); volumeValue.textContent = `${game.state.volume}%`; };
    volume.addEventListener('input', () => {
      game.state.volume = Number(volume.value);
      game.state.sound = game.state.volume > 0;
      volumeValue.textContent = `${game.state.volume}%`;
      game.audio.sync();
      if (game.state.sound) game.audio.unlock();
      game.save();
    });
    showVolume();
    button.addEventListener('click', showVolume);
  }

  button.addEventListener('click', () => { render(); dialog.showModal(); });
  close?.addEventListener('click', () => dialog.close());
  dialog.addEventListener('cancel', event => { event.preventDefault(); dialog.close(); });
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  render();
})();
