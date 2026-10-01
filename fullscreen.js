(() => {
  'use strict';
  // Fullscreen toggle in the header, left of the wallet. It is a standalone-page
  // affordance, so launcher-mode.css hides it while the native shell is in use.
  const button = document.getElementById('fullscreen-toggle');
  if (!button) return;

  const fullscreenElement = () => document.fullscreenElement || document.webkitFullscreenElement;
  const homeScreen = window.SlingHomeScreen;
  const canFullscreen = () => !!(document.documentElement.requestFullscreen || document.documentElement.webkitRequestFullscreen);
  const appleFallback = () => homeScreen?.isAppleMobile() && !canFullscreen();
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
    // An installed iPhone web app already hides browser chrome. Do not offer a
    // nonfunctional fullscreen toggle, or ask it to install itself again.
    button.hidden = !!(appleFallback() && homeScreen.isStandalone());
    const label = active ? '退出全屏' : appleFallback() ? '添加到主屏幕，隐藏浏览器工具栏' : '进入全屏';
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
    if (appleFallback()) {
      if (!homeScreen.isStandalone()) homeScreen.showGuide();
      return;
    }
    const failed = () => {
      if (homeScreen?.isAppleMobile() && !homeScreen.isStandalone()) homeScreen.showGuide();
      else button.title = '全屏请求被浏览器阻止，请检查浏览器权限。';
    };
    try {
      const action = fullscreenElement() ? exitFullscreen() : requestFullscreen();
      Promise.resolve(action).catch(failed);
    } catch {
      failed();
    }
  });

  document.addEventListener('fullscreenchange', render);
  document.addEventListener('webkitfullscreenchange', render);
  window.addEventListener?.('pageshow', render);
  render();
})();
