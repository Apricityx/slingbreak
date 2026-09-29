(() => {
  'use strict';
  // Fullscreen toggle in the header, left of the wallet. It is a standalone-page
  // affordance, so launcher-mode.css hides it while the native shell is in use.
  const button = document.getElementById('fullscreen-toggle');
  if (!button) return;

  const fullscreenElement = () => document.fullscreenElement || document.webkitFullscreenElement;
  // `icon:` keys are how vendor/build-lucide-subset.cjs discovers dynamic icons.
  const ICONS = { inactive: {icon: 'maximize'}, active: {icon: 'minimize'} };

  const render = () => {
    const active = !!fullscreenElement();
    const icon = button.querySelector('[data-lucide]');
    const name = (active ? ICONS.active : ICONS.inactive).icon;
    if (icon && icon.getAttribute('data-lucide') !== name) {
      icon.setAttribute('data-lucide', name);
      window.lucide?.createIcons?.();
    }
    const label = active ? '退出全屏' : '进入全屏';
    if (button.getAttribute('aria-label') !== label) button.setAttribute('aria-label', label);
    button.title = label;
    button.setAttribute('aria-pressed', String(active));
  };

  const requestFullscreen = () => {
    const root = document.documentElement;
    return root.requestFullscreen ? root.requestFullscreen() : root.webkitRequestFullscreen?.();
  };
  const exitFullscreen = () => document.exitFullscreen ? document.exitFullscreen() : document.webkitExitFullscreen?.();

  button.addEventListener('click', () => {
    const action = fullscreenElement() ? exitFullscreen() : requestFullscreen();
    // Browsers reject untrusted requests; swallow the rejection so the button stays usable.
    Promise.resolve(action).catch(() => {});
  });

  document.addEventListener('fullscreenchange', render);
  document.addEventListener('webkitfullscreenchange', render);
  render();
})();
