(() => {
  'use strict';
  // This is a local debug control, not authentication. Never expose sensitive
  // server-side capabilities based on a URL parameter alone.
  if (!new URLSearchParams(location.search).has('admin')) return;

  const game = window.Game;
  const group = document.getElementById('admin-group');
  const settings = document.getElementById('settings');
  const form = document.getElementById('admin-level-form');
  const input = document.getElementById('admin-level');
  const status = document.getElementById('admin-status');
  const bossForm = document.getElementById('admin-boss-form');
  const bossInput = document.getElementById('admin-boss');
  if (!game || !group || !settings || !form || !input || !status) return;

  group.hidden = false;
  const showLevel = () => { input.value = String(game.state.level); };
  showLevel();
  document.getElementById('settings-toggle')?.addEventListener('click', showLevel);
  settings.addEventListener('close', () => game.ui?.());

  if (bossForm && bossInput && game.bossDefs && game.enterBoss) {
    for (const [id, boss] of Object.entries(game.bossDefs)) {
      const option = document.createElement('option');
      option.value = id;
      option.textContent = `${boss.name} (${id})`;
      bossInput.append(option);
    }
    const showBoss = () => { if (game.boss?.()) bossInput.value = game.boss().boss; };
    showBoss();
    document.getElementById('settings-toggle')?.addEventListener('click', showBoss);
    bossForm.addEventListener('submit', event => {
      event.preventDefault();
      if (!Object.prototype.hasOwnProperty.call(game.bossDefs, bossInput.value)) {
        status.textContent = '请选择有效的 Boss。';
        return;
      }
      if (!game.enterBoss(bossInput.value)) {
        status.textContent = '请先结束当前射击或过场，并恢复游戏后再结算。';
        return;
      }
      showLevel();
      const name = game.bossDefs[bossInput.value].name;
      status.textContent = `当前关已结算，下一关为 ${name} · 第 ${game.state.level} 关第一阶段。`;
      settings.close();
      game.toast?.(`管理员 · ${name}`);
    });
  }

  form.addEventListener('submit', event => {
    event.preventDefault();
    const raw = input.value.trim();
    const level = Number(raw);
    if (!/^[1-9]\d*$/.test(raw) || !Number.isSafeInteger(level) || level > 100000) {
      status.textContent = '请输入 1 至 100000 的整数关卡编号。';
      return;
    }
    if (level === game.state.level) {
      status.textContent = '已经在这一关，无需调整。';
      return;
    }
    if (game.paused || game.phase !== 'ready') {
      status.textContent = '请先结束当前射击或选关，并恢复游戏后再调整。';
      return;
    }

    // Reuse the normal generation pipeline so physics bodies, temporary skill
    // effects, the next skill draft and the saved board all match the new level.
    game.state.level = level;
    game.state.board = null;
    game.state.draft = null;
    game.state.skillChosenLevel = 0;
    game.state.skillRuntime = null;
    game.drag = null;
    game.pointer = null;
    game.generate();
    status.textContent = `已跳转至第 ${level} 关。`;
    settings.close();
    game.toast?.(`管理员 · LEVEL ${level}`);
  });
})();
