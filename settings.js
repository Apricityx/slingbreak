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
  const performanceMode = document.getElementById('performance-mode');
  const reduced = () => game?.reduced ?? (typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches);
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

  if (game && performanceMode) {
    const showPerformanceMode = () => { performanceMode.checked = game.state.performanceMode; };
    performanceMode.addEventListener('change', () => game.setPerformanceMode(performanceMode.checked));
    showPerformanceMode();
    button.addEventListener('click', showPerformanceMode);
  }

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

  const installButton = document.getElementById('install-app');
  const installStatus = document.getElementById('install-status');
  if (installButton && installStatus) {
    let installPrompt;
    const installed = () => window.matchMedia?.('(display-mode: standalone)').matches ||
      (typeof navigator !== 'undefined' && navigator.standalone === true);
    const instructions = () => {
      const device = typeof navigator === 'undefined' ? {} : navigator;
      const ua = device.userAgent || '';
      const ios = /iPhone|iPad|iPod/.test(ua) || (device.platform === 'MacIntel' && device.maxTouchPoints > 1);
      if (ios) return window.SlingHomeScreen?.instructions() || '点浏览器的“分享”图标，再选“添加到主屏幕”（旧版 iOS 请用 Safari）；网页无法直接打开此菜单。';
      if (/Android/i.test(ua)) return '打开浏览器菜单，选择“安装应用”或“添加到主屏幕”。';
      if (/Macintosh/.test(ua) && /Safari/.test(ua) && !/Chrome|Chromium|CriOS|Edg|OPR/.test(ua))
        return 'Mac Safari（macOS Sonoma 14 或更新版本）请在“文件”菜单选择“添加到程序坞”；旧版系统请用 Chrome 或 Edge 安装。';
      if (/Firefox/.test(ua)) return '桌面 Firefox 暂不支持安装网页应用，请用 Chrome 或 Edge 打开并通过浏览器菜单安装。';
      if (/Chrome|Chromium|Edg|OPR/.test(ua)) return '点击地址栏的“安装”图标，或从浏览器菜单选择“安装应用”。';
      return '请在浏览器菜单中选择“安装应用”或“添加到主屏幕”。';
    };
    window.addEventListener('beforeinstallprompt', event => {
      event.preventDefault();
      installPrompt = event;
      installStatus.textContent = '已可安装，点击“添加到主屏幕”继续。';
    });
    window.addEventListener('appinstalled', () => {
      installPrompt = null;
      installStatus.textContent = '已添加到主屏幕。';
    });
    installButton.addEventListener('click', async () => {
      if (installed()) {
        installStatus.textContent = '已从主屏幕打开，无需重复添加。';
      } else if (installPrompt) {
        const prompt = installPrompt;
        installPrompt = null;
        try {
          await prompt.prompt();
          const choice = await prompt.userChoice;
          installStatus.textContent = choice.outcome === 'accepted' ? '安装请求已发送，请查看主屏幕。' : instructions();
        } catch {
          installStatus.textContent = instructions();
        }
      } else {
        installStatus.textContent = instructions();
        window.SlingHomeScreen?.showGuide();
      }
    });
  }

  const refreshPage = document.getElementById('refresh-page');
  const refreshStatus = document.getElementById('refresh-status');
  refreshPage?.addEventListener('click', async () => {
    if (refreshPage.disabled) return;
    refreshPage.disabled = true;
    refreshStatus.textContent = '正在获取最新页面…';
    try {
      const next = new URL(location.href);
      // A new document URL avoids reusing a cached index.html; keep launcher
      // and other query parameters intact when returning to the page.
      next.searchParams.set('_refresh', `${Date.now()}-${Math.random().toString(36).slice(2)}`);
      const remote = next.protocol === 'http:' || next.protocol === 'https:';
      if (remote) {
        const response = await fetch(next.href, {cache: 'reload'});
        if (!response.ok) throw new Error('页面请求失败');
        const page = new DOMParser().parseFromString(await response.text(), 'text/html');
        const resources = new Set([...page.querySelectorAll('script[src],link[rel~="stylesheet"][href]')]
          .map(node => new URL(node.getAttribute('src') || node.getAttribute('href'), next.href))
          .filter(url => url.origin === next.origin && (url.protocol === 'http:' || url.protocol === 'https:'))
          .map(url => url.href));
        // cache: reload bypasses the HTTP cache and replaces its entries. Read
        // each body so the updated response can be stored before navigation.
        const urls = [...resources];
        for (let i = 0; i < urls.length; i += 6) {
          await Promise.all(urls.slice(i, i + 6).map(async url => {
            const asset = await fetch(url, {cache: 'reload'});
            if (!asset.ok) throw new Error('资源请求失败');
            await asset.arrayBuffer();
          }));
        }
      }
      if (game?.phase !== 'clearing') game?.save?.();
      refreshStatus.textContent = remote ? '已获取最新资源，正在重新加载…' : '正在重新加载本地页面…';
      location.replace(next.href);
    } catch (error) {
      console.warn('重新获取页面失败', error);
      refreshStatus.textContent = '获取失败，请检查网络后重试。';
      refreshPage.disabled = false;
    }
  });

  button.addEventListener('click', () => { render(); dialog.showModal(); });
  close?.addEventListener('click', () => dialog.close());
  dialog.addEventListener('cancel', event => { event.preventDefault(); dialog.close(); });
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  render();
})();
