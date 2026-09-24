(() => {
  const G=Game,$=id=>document.getElementById(id);
  let comboStamp='',comboAnimation;
  const compact=n=>Number(n.toFixed(3)).toString();
  const upgrades={power:{name:'弹弓',icon:'crosshair',desc:()=>`拉力 ${Math.round(G.speed()/24*100)}% · 更远射程`},arrow:{name:'箭矢',icon:'move-up-right',desc:()=>`伤害 ${G.damage().toFixed(2)} · 穿透 ${G.penetration()} 块`},brick:{name:'砖块',icon:'blocks',desc:()=>`价值 +${Math.round((G.valueMultiplier()-1)*100)}% · 特殊率 ${(G.specialRate()*100).toFixed(1)}%`},comboCap:{name:'连击强化',icon:'gauge',desc:()=>`每连增幅 +${compact(G.comboStep())}，${G.comboCapKills()} 连达到 ×${compact(G.comboMultiplierCap())} 上限`} };
  for(const [key,u] of Object.entries(upgrades)){
     const el=document.createElement('div');el.className='upgrade';el.innerHTML=`<span class="upgrade-icon"><i data-lucide="${u.icon}"></i></span><div><div class="upgrade-title"><b>${u.name}</b><small id="${key}-level"></small></div><p class="upgrade-desc" id="${key}-desc"></p></div><button class="buy-button" id="buy-${key}" aria-label="升级${u.name}"><i data-lucide="plus"></i><span></span></button>`;$('upgrades').append(el);$('buy-'+key).onclick=()=>G.buy(key);
     if(key==='comboCap'){$(key+'-desc').innerHTML='<span class="combo-upgrade-lock" id="combo-upgrade-lock"><i data-lucide="lock-keyhole" aria-hidden="true"></i>砖块 LV.6</span><span class="combo-upgrade-preview" id="combo-upgrade-preview"><span class="upgrade-metric"><small>增幅</small><b id="combo-step-current"></b><i data-lucide="arrow-right" aria-hidden="true"></i><em id="combo-step-next"></em></span><span class="upgrade-metric"><small>上限</small><b id="combo-cap-current"></b><i data-lucide="arrow-right" aria-hidden="true"></i><em id="combo-cap-next"></em></span></span>';}
  }
  const icons=()=>lucide.createIcons();
  G.ui=()=>{
    $('level').textContent=String(G.phase==='clearing'?G.state.level-1:G.state.level).padStart(2,'0');
    $('balance').textContent=G.fmt(G.state.coins);$('total-destroyed').textContent=G.fmt(G.state.total);$('best-combo').textContent=G.state.best;
    $('best-combo').title=G.state.legacyBest?`旧版多箭合计纪录：${G.state.legacyBest}；当前只记录单箭连击`:'单支箭及其连锁、延迟伤害的最高击碎数';
    $('shot-money').title=`本轮所有箭合计击碎 ${G.roundKills} 块，金额包含独立奖金`;
    $('progress-label').textContent=Math.min(G.killed,G.threshold)+' / '+G.threshold;
    $('progress-bar').style.width=Math.min(100,G.killed/G.threshold*100)+'%';$('core-label').textContent=G.core?'核心已显现':G.phase==='clearing'?'核心击破':'核心解锁';
    $('core-required').textContent=G.threshold;$('core-bonus').textContent='+ '+G.fmt(G.phase==='clearing'&&G.settledBonus!==undefined?G.settledBonus:G.bonus(G.phase==='clearing'?G.state.level-1:G.state.level));
    const arrowScore=G.latestAchievement;
    const combo=$('combo'),kills=arrowScore?.kills||0,capKills=arrowScore?.capKills||G.comboCapKills(),capped=kills>=capKills;
    combo.classList.toggle('visible',kills>=1&&['ready','flying'].includes(G.phase));combo.classList.toggle('is-capped',capped);
    combo.setAttribute('aria-label',arrowScore?`第 ${arrowScore.id} 箭，${kills} 连击，倍率 ${compact(arrowScore.baseMult)}，${capped?'已封顶':`距封顶还差 ${capKills-kills} 块`}`:'等待连击');
    $('combo-count').textContent=kills;$('combo-source').textContent=arrowScore?'#'+arrowScore.id:'—';
    $('combo-mult').textContent='×'+compact(arrowScore?.baseMult||1);
    const stamp=arrowScore?`${arrowScore.id}:${kills}`:'';
    if(stamp!==comboStamp){
      const switched=combo.dataset.arrow!==String(arrowScore?.id||'');combo.dataset.arrow=arrowScore?.id||'';
      combo.classList.toggle('is-switching',switched);
      $('combo-progress').style.strokeDashoffset=100*(1-Math.min(1,kills/capKills));
      comboAnimation?.cancel();
      if(arrowScore&&!G.reduced)comboAnimation=$('combo-count').animate([{transform:switched?'translateY(5px) scale(.85)':'scale(1.2)',opacity:switched ? .3 : 1},{transform:'translateY(0) scale(1)',opacity:1}],{duration:220,easing:'cubic-bezier(.2,.8,.2,1)'});
      comboStamp=stamp;
    }
     $('play-status').textContent=G.paused?'已暂停':G.phase==='clearing'?'下一关即将开始':G.phase==='entering'?'砖块入场中':G.drag?'蓄力中':G.phase==='flying'?'可继续射击':'就绪';
    if(!G.drag)$('power-readout').querySelector('b').textContent='0%';
     for(const [key,u] of Object.entries(upgrades)){
       const locked=key==='comboCap'&&!G.comboUpgradeUnlocked();
       $(key+'-level').textContent=key==='comboCap'?'+'+G.state.up[key]:'LV. '+(G.state.up[key]+1);
       if(key==='comboCap'){
         $('combo-upgrade-lock').hidden=!locked;$('combo-upgrade-preview').hidden=locked;$(key+'-desc').title=u.desc();
         $('combo-step-current').textContent='+'+compact(G.comboStep());$('combo-step-next').textContent='+'+compact(G.comboStep()+.025);
         $('combo-cap-current').textContent='×'+compact(G.comboMultiplierCap());$('combo-cap-next').textContent='×'+compact(G.comboMultiplierCap()+.5);
       }else $(key+'-desc').textContent=u.desc();
       const b=$('buy-'+key),cost=G.cost(key);b.querySelector('span').textContent=locked?'—':G.fmt(cost);b.disabled=locked||G.state.coins<cost||G.phase!=='ready'||G.paused;
      b.title=locked?'砖块升至 LV.6 后解锁':G.phase!=='ready'?'本轮所有箭与延迟效果结束后可升级':G.state.coins<cost?'还差 '+G.fmt(cost-G.state.coins)+' 金币':'升级'+u.name+' · '+G.fmt(cost)+' 金币';
    }
     $('shop-trigger').hidden=false;$('shop-balance').textContent=G.fmt(G.state.coins);
  };
  let toastTimer;
  G.toast=text=>{$('toast').textContent=text;$('toast').classList.add('visible');$('notice-dock').classList.add('has-toast');clearTimeout(toastTimer);toastTimer=setTimeout(()=>{$('toast').classList.remove('visible');$('notice-dock').classList.remove('has-toast');},2400);};
  const pause=value=>{
    if(document.getElementById('skill-library')?.open)return;
    if(G.phase==='draft')value=false;G.paused=value;G.audio.sync();G.drag=null;G.pointer=null;$('overlay').hidden=!value;G.ui();
  };
  $('resume').onclick=()=>pause(false);
  let wasPaused=false;
  $('reset').onclick=()=>{wasPaused=G.paused;pause(true);$('reset-dialog').showModal();};
  $('cancel-reset').onclick=()=>$('reset-dialog').close();
  $('reset-dialog').addEventListener('close',()=>pause(wasPaused));
  $('confirm-reset').onclick=()=>{G.reset();wasPaused=false;$('reset-dialog').close();G.toast('新的开始 · LEVEL 1');};
  const shop=$('shop');let shopClosing=false;
  const closeShop=()=>{
    if(!shop.open||shopClosing)return;
    shopClosing=true;shop.classList.add('is-closing');
    const finish=()=>{shop.classList.remove('is-closing');shopClosing=false;shop.close();};
    if(G.reduced)finish();else shop.addEventListener('animationend',finish,{once:true});
  };
  $('shop-trigger').onclick=()=>{G.drag=null;G.pointer=null;shop.showModal();};
  $('close-shop').onclick=closeShop;
  shop.addEventListener('cancel',e=>{e.preventDefault();closeShop();});
  shop.addEventListener('click',e=>{if(e.target===shop)closeShop();});
  shop.addEventListener('close',()=>$('game').focus({preventScroll:true}));
   document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!document.querySelector('dialog[open]'))pause(!G.paused);});
  document.addEventListener('visibilitychange',()=>{if(document.hidden){pause(true);if(G.phase!=='clearing')G.save();}});
  window.addEventListener('pagehide',()=>{if(G.phase!=='clearing')G.save();});
  G.ui();icons();
})();
