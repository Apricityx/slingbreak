(() => {
  'use strict';
  // Apple does not expose a web API to open Add to Home Screen. Offer an honest,
  // visible manual path instead of pretending to install or enter fullscreen.
  const device = typeof navigator === 'undefined' ? {} : navigator;
  const ua = device.userAgent || '';
  const isAppleMobile = () => /iPhone|iPad|iPod/.test(ua) ||
    (device.platform === 'MacIntel' && device.maxTouchPoints > 1);
  const isStandalone = () => !!(window.matchMedia?.('(display-mode: standalone)')?.matches || device.standalone === true);
  const isEmbedded = () => /MicroMessenger|QQ\/|QQBrowser|Weibo|FBAN|FBAV|Instagram|Line\//i.test(ua);
  const instructions = () => isEmbedded()
    ? '请先通过右上角菜单选择“在 Safari 中打开”；若没有此选项，复制链接到 Safari，再点“分享” → “添加到主屏幕”。'
    : '点浏览器的“分享”图标，再选“添加到主屏幕”（旧版 iOS 请用 Safari）；网页无法直接打开此菜单。';

  const dialog = document.getElementById('home-screen-guide');
  const status = document.getElementById('home-screen-status');
  const url = document.getElementById('home-screen-url');
  const showGuide = () => {
    if (!dialog || !isAppleMobile()) return;
    document.getElementById('home-screen-step-open').textContent = isEmbedded()
      ? '先在 App 右上角菜单选择“在 Safari 中打开”。没有此选项时，复制下面的链接，粘贴到 Safari 地址栏打开。'
      : '在 Safari 中打开此页面；支持此功能的新版 Chrome、Edge 等浏览器也可使用分享菜单。';
    document.getElementById('home-screen-step-add').textContent = '点浏览器的“分享”按钮（方框向上箭头），选择“添加到主屏幕”；找不到时向下滚动分享菜单。';
    document.getElementById('home-screen-step-launch').textContent = '若显示“作为网页 App 打开”，请保持开启，再点“添加”。回到主屏幕，点“弓引力”图标进入游戏。';
    status.textContent = isStandalone() ? '已从主屏幕打开，无需重复添加。' : instructions();
    url.value = window.location.href;
    if (!dialog.open) dialog.showModal();
  };

  if (dialog) {
    document.getElementById('close-home-screen-guide')?.addEventListener('click', () => dialog.close());
    dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
    document.getElementById('copy-home-screen-url')?.addEventListener('click', async () => {
      try {
        await device.clipboard.writeText(url.value);
        status.textContent = '链接已复制。请打开 Safari，粘贴到地址栏。';
      } catch {
        url.focus();
        url.select();
        url.setSelectionRange(0, url.value.length);
        status.textContent = '无法自动复制，请长按链接并选择“复制”，再到 Safari 中打开。';
      }
    });
  }
  window.SlingHomeScreen = { isAppleMobile, isStandalone, instructions, showGuide };
})();
