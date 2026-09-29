(() => {
  const G=Game,$=id=>document.getElementById(id);
  let comboStamp='',comboAnimation;
  const compact=n=>Number(n.toFixed(3)).toString();
  const upgrades={power:{name:'弹弓',icon:'crosshair',desc:()=>`拉力 ${Math.round(G.speed()/24*100)}% · 更远射程`},arrow:{name:'箭矢',icon:'move-up-right',desc:()=>`伤害 ${G.damage().toFixed(2)} · 穿透 ${G.penetration()} 块`},brick:{name:'砖块',icon:'blocks',desc:()=>`价值 +${Math.round((G.valueMultiplier()-1)*100)}% · 特殊率 ${(G.specialRate()*100).toFixed(1)}%`},comboCap:{name:'连击强化',icon:'gauge',desc:()=>`每连增幅 +${compact(G.comboStep())}，${G.comboCapKills()} 连达到 ×${compact(G.comboMultiplierCap())} 上限`},slots:{name:'技能槽位',icon:'layout-grid',desc:()=>`当前 ${G.skillSlots} 个技能槽 · 每关三选一，满槽后自动替换最早的技能`} };
  for(const [key,u] of Object.entries(upgrades)){
     const el=document.createElement('div');el.className='upgrade';el.innerHTML=`<span class="upgrade-icon"><i data-lucide="${u.icon}"></i></span><div><div class="upgrade-title"><b>${u.name}</b><small id="${key}-level"></small></div><p class="upgrade-desc" id="${key}-desc"></p></div><button class="buy-button" id="buy-${key}" aria-label="升级${u.name}"><i data-lucide="plus"></i><span></span></button>`;$('upgrades').append(el);$('buy-'+key).onclick=()=>G.buy(key);
     if(key==='comboCap'){$(key+'-desc').innerHTML='<span class="combo-upgrade-lock" id="combo-upgrade-lock"><i data-lucide="lock-keyhole" aria-hidden="true"></i>砖块 LV.6</span><span class="combo-upgrade-preview" id="combo-upgrade-preview"><span class="upgrade-metric"><small>增幅</small><b id="combo-step-current"></b><i data-lucide="arrow-right" aria-hidden="true"></i><em id="combo-step-next"></em></span><span class="upgrade-metric"><small>上限</small><b id="combo-cap-current"></b><i data-lucide="arrow-right" aria-hidden="true"></i><em id="combo-cap-next"></em></span></span>';}
     if(key==='slots'){$(key+'-desc').innerHTML='<span class="combo-upgrade-preview" id="slots-upgrade-preview"><span class="upgrade-metric"><small>技能槽</small><b id="slots-current"></b><i data-lucide="arrow-right" aria-hidden="true"></i><em id="slots-next"></em></span></span><span class="slots-upgrade-done" id="slots-upgrade-done" hidden></span><span class="slots-forge-note" id="slots-forge-note" hidden>神匠赐福不可用于该升级</span>';}
  }
  const icons=()=>lucide.createIcons();
  // G.ui() runs up to once per frame while arrows fly. Writing an unchanged
  // textContent still replaces the text node and dirties layout, so every
  // write below is skipped when the value is already current.
  const setText=(el,value)=>{value=String(value);if(el.textContent!==value)el.textContent=value;};
  const setTitle=(el,value)=>{if(el.title!==value)el.title=value;};
  const setAttr=(el,name,value)=>{if(el.getAttribute(name)!==value)el.setAttribute(name,value);};
  const setHidden=(el,value)=>{if(el.hidden!==value)el.hidden=value;};
  let progressWidth='';
  G.ui=()=>{
    setText($('level'),String(G.phase==='clearing'?G.state.level-1:G.state.level).padStart(2,'0'));
    setText($('balance'),G.fmt(G.state.coins));setText($('total-destroyed'),G.fmt(G.state.total));setText($('best-combo'),G.state.best);
    setTitle($('best-combo'),G.state.legacyBest?`旧版多箭合计纪录：${G.state.legacyBest}；当前只记录单箭连击`:'单支箭及其连锁、延迟伤害的最高击碎数');
    setTitle($('shot-money'),`本轮所有箭合计击碎 ${G.roundKills} 块，金额包含独立奖金`);
    setText($('progress-label'),Math.min(G.killed,G.threshold)+' / '+G.threshold);
    const width=Math.min(100,G.killed/G.threshold*100)+'%';if(width!==progressWidth){progressWidth=width;$('progress-bar').style.width=width;}
    setText($('core-label'),G.core?'核心已显现':G.phase==='clearing'?'核心击破':'核心解锁');
    setText($('core-required'),G.threshold);setText($('core-bonus'),'+ '+G.fmt(G.phase==='clearing'&&G.settledBonus!==undefined?G.settledBonus:G.bonus(G.phase==='clearing'?G.state.level-1:G.state.level)));
    const arrowScore=G.latestAchievement;
    const combo=$('combo'),kills=arrowScore?.kills||0,capKills=arrowScore?.capKills||G.comboCapKills(),capped=kills>=capKills;
    combo.classList.toggle('visible',kills>=1&&['ready','flying'].includes(G.phase));combo.classList.toggle('is-capped',capped);
    setAttr(combo,'aria-label',arrowScore?`第 ${arrowScore.id} 箭，${kills} 连击，倍率 ${compact(arrowScore.baseMult)}，${capped?'已封顶':`距封顶还差 ${capKills-kills} 块`}`:'等待连击');
    setText($('combo-count'),kills);setText($('combo-source'),arrowScore?'#'+arrowScore.id:'—');
    setText($('combo-mult'),'×'+compact(arrowScore?.baseMult||1));
    const stamp=arrowScore?`${arrowScore.id}:${kills}`:'';
    if(stamp!==comboStamp){
      const switched=combo.dataset.arrow!==String(arrowScore?.id||'');combo.dataset.arrow=arrowScore?.id||'';
      combo.classList.toggle('is-switching',switched);
      $('combo-progress').style.strokeDashoffset=100*(1-Math.min(1,kills/capKills));
      comboAnimation?.cancel();
      if(arrowScore&&!G.reduced)comboAnimation=$('combo-count').animate([{transform:switched?'translateY(5px) scale(.85)':'scale(1.2)',opacity:switched ? .3 : 1},{transform:'translateY(0) scale(1)',opacity:1}],{duration:220,easing:'cubic-bezier(.2,.8,.2,1)'});
      comboStamp=stamp;
    }
     setText($('play-status'),G.paused?'已暂停':G.phase==='clearing'?'下一关即将开始':G.phase==='entering'?'砖块入场中':G.drag?'蓄力中':G.phase==='flying'?'可继续射击':'就绪');
    if(!G.drag)setText($('power-readout').querySelector('b'),'0%');
     for(const [key,u] of Object.entries(upgrades)){
       const maxed=key==='slots'&&G.skillSlotBought()>=G.skillSlotUpgrades;
       const locked=key==='comboCap'&&!G.comboUpgradeUnlocked();
       const forgeReady=key==='slots'&&!!G.skillRank?.('forge')&&!G.state.skillRuntime?.forge;
       setText($(key+'-level'),key==='comboCap'?'+'+G.state.up[key]:key==='slots'?`${G.skillSlots} / ${G.skillSlotMax}`:'LV. '+(G.state.up[key]+1));
       if(key==='comboCap'){
         setHidden($('combo-upgrade-lock'),!locked);setHidden($('combo-upgrade-preview'),locked);setTitle($(key+'-desc'),u.desc());
         setText($('combo-step-current'),'+'+compact(G.comboStep()));setText($('combo-step-next'),'+'+compact(G.comboStep()+.025));
         setText($('combo-cap-current'),'×'+compact(G.comboMultiplierCap()));setText($('combo-cap-next'),'×'+compact(G.comboMultiplierCap()+.5));
       }else if(key==='slots'){
         setHidden($('slots-upgrade-preview'),maxed);
         setHidden($('slots-upgrade-done'),!maxed);
         setHidden($('slots-forge-note'),!(forgeReady&&!maxed));
         if(maxed)setText($('slots-upgrade-done'),`已解锁全部 ${G.skillSlotMax} 个技能槽。`);
         else{
           setText($('slots-current'),G.skillSlots);setText($('slots-next'),Math.min(G.skillSlotMax,G.skillSlots+1));
         }
         setTitle($(key+'-desc'),maxed?u.desc():`升级后拥有 ${Math.min(G.skillSlotMax,G.skillSlots+1)} 个技能槽`);
       }else setText($(key+'-desc'),u.desc());
       const b=$('buy-'+key),cost=G.cost(key),disabled=maxed||locked||G.state.coins<cost||G.phase!=='ready'||G.paused;
       setText(b.querySelector('span'),maxed?'已满级':locked?'—':G.fmt(cost));
       if(b.disabled!==disabled)b.disabled=disabled;
      setTitle(b,(maxed?'技能槽已全部解锁':locked?'砖块升至 LV.6 后解锁':G.phase!=='ready'?'本轮所有箭与延迟效果结束后可升级':G.state.coins<cost?'还差 '+G.fmt(cost-G.state.coins)+' 金币':'升级'+u.name+' · '+G.fmt(cost)+' 金币')+(forgeReady&&!maxed?' · 神匠赐福不可用于该升级':''));
    }
     setHidden($('shop-trigger'),false);setText($('shop-balance'),G.fmt(G.state.coins));
  };
  let toastTimer;
  G.toast=text=>{$('toast').textContent=text;$('toast').classList.add('visible');$('notice-dock').classList.add('has-toast');clearTimeout(toastTimer);toastTimer=setTimeout(()=>{$('toast').classList.remove('visible');$('notice-dock').classList.remove('has-toast');},2400);};
  // The overlay fades the arena to grey on the way in and hands colour back on the way out.
  let overlayTimer=0;
  const showOverlay=show=>{
    const overlay=$('overlay');clearTimeout(overlayTimer);
    $('arena').classList.toggle('is-paused',show);
    if(show){overlay.classList.remove('is-leaving');overlay.hidden=false;return;}
    if(overlay.hidden)return;
    if(G.reduced){overlay.hidden=true;return;}
    overlay.classList.add('is-leaving');
    overlayTimer=setTimeout(()=>{overlay.hidden=true;overlay.classList.remove('is-leaving');},260);
  };
  const pause=value=>{
    if(document.getElementById('skill-library')?.open)return;
    if(G.phase==='draft')value=false;G.paused=value;G.audio.sync();G.drag=null;G.pointer=null;showOverlay(value);G.ui();
    // A short input lock stops the tap on "继续游戏" from also loosing an arrow.
    if(!value)G.lockInput?.(260);
  };
  $('resume').onclick=()=>pause(false);
  let wasPaused=false;
  $('reset').onclick=()=>{wasPaused=G.paused;pause(true);$('reset-dialog').showModal();};
  $('cancel-reset').onclick=()=>$('reset-dialog').close();
  $('reset-dialog').addEventListener('close',()=>pause(wasPaused));
  $('confirm-reset').onclick=()=>{wasPaused=false;$('reset-dialog').close();if(G.rewind)G.rewind();else{G.reset();G.toast('新的开始 · LEVEL 1');}};
  const shop=$('shop');
  // transitions.js animates dialog.close(): the shop folds back into its trigger.
  const closeShop=()=>shop.close();
  $('shop-trigger').onclick=()=>{G.drag=null;G.pointer=null;shop.showModal();};
  $('close-shop').onclick=closeShop;
  shop.addEventListener('cancel',e=>{e.preventDefault();closeShop();});
  shop.addEventListener('click',e=>{if(e.target===shop)closeShop();});
  shop.addEventListener('close',()=>{$('game').focus({preventScroll:true});G.ui();});
   document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!document.querySelector('dialog[open]'))pause(!G.paused);});
  // Backgrounding auto-pauses silently: the pause card is only opened on demand.
  let backgroundPaused=false;
  const autoPause=()=>{if(G.paused||G.phase==='draft'||document.querySelector('dialog[open]'))return;backgroundPaused=true;G.paused=true;G.audio.sync();G.drag=null;G.pointer=null;G.ui();};
  const autoResume=()=>{if(!backgroundPaused)return;backgroundPaused=false;G.paused=false;G.audio.sync();G.ui();};
  document.addEventListener('visibilitychange',()=>{if(document.hidden){autoPause();if(G.phase!=='clearing')G.save();}else autoResume();});
  window.addEventListener('pagehide',()=>{if(G.phase!=='clearing')G.save();});
  G.ui();icons();
})();
