(() => {
  'use strict';
  const G=window.Game,$=id=>document.getElementById(id),panel=$('earnings');
  // A shared set of 24px emblems keeps each achievement recognizable in both views.
  const emblems={
    double:{color:'#66883d',paths:'<path d="M4 20 20 4M14 4h6v6M3 15l6 6M6 12l6 6M9 9l6 6M12 6l6 6"/>'},
    five:{color:'#658d58',paths:'<path d="M8 3v6l-3 3 3 3v6M16 3v6l3 3-3 3v6M6 6h4M14 18h4M10 14l4-4M11 10h3v3"/>'},
    ten:{color:'#9b7951',paths:'<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3ZM2 12h9l2-4 2 8 2-4h5"/>'},
    twenty:{color:'#ae8c32',paths:'<path d="m3 7 4 4 5-7 5 7 4-4-2 11H5L3 7ZM6 21h12"/><circle cx="12" cy="13" r="1.5"/>'},
    bank:{color:'#688b8c',paths:'<path d="M3 3v18M7 5l10 7-10 7M13 19H7v-6"/><circle cx="17" cy="12" r="2"/>'},
    trick:{color:'#8c77a4',paths:'<path d="m5 18 7-13 7 13H5ZM5 18l10-7M12 5l2 13"/><circle cx="12" cy="5" r="2"/><circle cx="5" cy="18" r="2"/><circle cx="19" cy="18" r="2"/>'},
    chain:{color:'#a57b4c',paths:'<path d="m10 14 4-4M8 16l-1 1a3.5 3.5 0 0 1-5-5l4-4a3.5 3.5 0 0 1 5 0M16 8l1-1a3.5 3.5 0 0 1 5 5l-4 4a3.5 3.5 0 0 1-5 0M8 3V1M16 23v-2"/>'},
    ice:{color:'#649baa',paths:'<path d="M12 2v6M12 16v6M3.3 7l5.2 3M15.5 14l5.2 3M3.3 17l5.2-3M15.5 10l5.2-3M9 3l3 3 3-3M9 21l3-3 3 3M3 10l4-1-1-4M18 19l-1-4 4-1"/><path d="m12 8 3 4-3 4-3-4 3-4Z"/>'},
    mix:{color:'#8d80b0',paths:'<circle cx="12" cy="5" r="3"/><circle cx="5" cy="17" r="3"/><circle cx="19" cy="17" r="3"/><path d="m10 8-3 6M14 8l3 6M8 17h8M12 11v2"/>'},
    gold:{color:'#ad933d',paths:'<ellipse cx="9" cy="7" rx="6" ry="3"/><path d="M3 7v5c0 1.7 2.7 3 6 3M9 10v4"/><ellipse cx="15" cy="14" rx="6" ry="3"/><path d="M9 14v5c0 1.7 2.7 3 6 3s6-1.3 6-3v-5"/>'},
    air:{color:'#7894a2',paths:'<path d="M3 17c7 0 8-12 18-13-1 7-4 13-12 13H3ZM7 17l10-9M11 13v-3M11 13h5M3 21h8M2 12h3"/>'},
    core:{color:'#9c716b',paths:'<path d="m12 4 8 8-8 8-8-8 8-8ZM12 1v3M23 12h-3M12 23v-3M1 12h3"/><circle cx="12" cy="12" r="3"/>'}
  };
  const emblemSVG=id=>`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${emblems[id].paths}</svg>`;
  const bonusText=n=>'+'+Number(n.toFixed(2))+'x';
  // Match reading order to the visual bottom placement.
  $('arena').after(panel);
  const pops=document.createElement('div');pops.className='achievement-pops';pops.setAttribute('aria-live','polite');panel.querySelector('.earnings-main').append(pops);
  const popDuration=1400,maxBurstDuration=1800;
  let popFrame=0,popLast=0,popClock=0,pendingAchievement=null,currentAchievement=null;
  function updatePop(p){
    const item=p.item,source=item.arrow===null?'多箭合计':`第 ${item.arrow} 支箭`;
    const entries=[...item.entries.values()];
    for(const entry of entries){
      let tile=p.tiles.get(entry.id);
      if(!tile){
        const el=document.createElement('div');el.className='achievement-mini';el.style.setProperty('--achievement-accent',emblems[entry.id].color);
        el.innerHTML=`<span class="achievement-mini-icon" aria-hidden="true">${emblemSVG(entry.id)}</span><span class="achievement-mini-name">${entry.name}</span><span class="achievement-mini-bonus"></span>`;
        el.classList.toggle('is-major',entry.unitBonus>=1);
        tile={el,icon:el.querySelector('.achievement-mini-icon'),value:el.querySelector('.achievement-mini-bonus'),born:popClock,updatedAt:popClock,bonus:0};
        p.tiles.set(entry.id,tile);p.grid.append(el);
      }
      if(tile.bonus!==entry.bonus){tile.bonus=entry.bonus;tile.updatedAt=popClock;tile.value.textContent=bonusText(entry.bonus);}
      tile.el.setAttribute('aria-label',`${entry.name}，获得 ${entry.count} 次，加成合计 ${bonusText(entry.bonus)}`);
    }
    p.el.setAttribute('aria-label',`${source}，${entries.map(entry=>`${entry.name} ${bonusText(entry.bonus)}`).join('，')}`);
  }
  function createPop(item){
    const el=document.createElement('div');el.className='achievement-pop';
    const grid=document.createElement('div');grid.className='achievement-grid';
    el.append(grid);pops.append(el);
    panel.classList.add('is-achievement');
    currentAchievement={el,grid,tiles:new Map(),item,born:popClock,ends:popClock+popDuration,opacity:0};
    updatePop(currentAchievement);
  }
  function playAchievements(time){
    popFrame=0;
    const dt=Math.min(50,popLast?time-popLast:0);popLast=time;
    const paused=G.paused||document.hidden||!!document.querySelector('dialog[open]');
    if(!paused)popClock+=dt;
    if(!paused){
      if(currentAchievement&&popClock>=currentAchievement.ends){
        currentAchievement.el.remove();currentAchievement=null;
      }
      if(pendingAchievement&&!currentAchievement){createPop(pendingAchievement);pendingAchievement=null;}
      if(currentAchievement){
        const p=currentAchievement,age=popClock-p.born;
        const enter=1-Math.pow(1-Math.min(1,age/180),3),exit=Math.max(0,1-(p.ends-popClock)/240);
        const target=enter*(1-exit*exit);
        p.opacity=G.reduced?1:p.opacity+(target-p.opacity)*(1-Math.exp(-dt/35));
        panel.style.setProperty('--achievement-opacity',p.opacity);
        p.el.style.opacity=p.opacity;
        for(const tile of p.tiles.values()){
          const arrival=Math.min(1,(popClock-tile.born)/260),settle=1-Math.pow(1-arrival,3);
          const bump=Math.sin(Math.PI*Math.min(1,(popClock-tile.updatedAt)/240));
          tile.el.style.opacity=G.reduced?'1':String(settle);
          tile.el.style.transform=G.reduced?'none':`translateY(${6*(1-settle)}px)`;
          tile.icon.style.transform=G.reduced?'none':`scale(${.9+.1*settle+.12*Math.sin(Math.PI*arrival)})`;
          tile.value.style.transform=G.reduced?'none':`scale(${1+.1*bump})`;
          tile.el.style.setProperty('--tile-glow',G.reduced?'0':String(Math.max(0,1-(popClock-tile.updatedAt)/450)));
        }
      }
      if(!currentAchievement&&panel.classList.contains('is-achievement')){
        panel.classList.remove('is-achievement');panel.style.removeProperty('--achievement-opacity');
      }
    }
    if(pendingAchievement||currentAchievement)popFrame=requestAnimationFrame(playAchievements);
    else popLast=0;
  }
  G.showAchievement=(item,score)=>{
    // Fold arrivals into the live card instead of accumulating a playback queue.
    const burst=currentAchievement?.item||pendingAchievement;
    if(burst){
      burst.count++;burst.bonus+=item.bonus;
      const entry=burst.entries.get(item.id);
      if(entry){entry.count++;entry.bonus+=item.bonus;}
      else burst.entries.set(item.id,{id:item.id,name:item.name,unitBonus:item.bonus,bonus:item.bonus,count:1});
      if(burst.arrow!==score.id)burst.arrow=null;
      if(item.bonus>=burst.bestBonus){burst.id=item.id;burst.name=item.name;burst.bestBonus=item.bonus;}
      if(currentAchievement){
        const p=currentAchievement;
        // Give late arrivals a brief hold, with an absolute limit for the whole burst.
        p.ends=Math.min(p.born+maxBurstDuration,Math.max(p.ends,popClock+450));
        updatePop(p);
      }
    }else pendingAchievement={id:item.id,name:item.name,bonus:item.bonus,bestBonus:item.bonus,arrow:score.id,count:1,entries:new Map([[item.id,{id:item.id,name:item.name,unitBonus:item.bonus,bonus:item.bonus,count:1}]])};
    if(!popFrame)popFrame=requestAnimationFrame(playAchievements);
  };
  const resetGame=G.reset;
  G.reset=()=>{
    pendingAchievement=null;currentAchievement=null;pops.replaceChildren();
    panel.classList.remove('is-achievement');panel.style.removeProperty('--achievement-opacity');
    cancelAnimationFrame(popFrame);popFrame=0;popLast=0;popClock=0;
    return resetGame();
  };
  const exact=n=>Math.floor(n).toLocaleString('en-US');
  let shownMoney=G.shotMoney,shownWallet=G.state.coins,targetMoney=shownMoney,targetWallet=shownWallet;
  let frame=0,last=0,event=0,library='';
  function animate(time){
    const fraction=1-Math.exp(-Math.min(64,time-(last||time-16))/85);last=time;
    shownMoney+=(targetMoney-shownMoney)*fraction;shownWallet+=(targetWallet-shownWallet)*fraction;
    if(Math.abs(targetMoney-shownMoney)<1)shownMoney=targetMoney;
    if(Math.abs(targetWallet-shownWallet)<1)shownWallet=targetWallet;
    $('shot-money').textContent='+ '+G.fmt(shownMoney);$('live-wallet').textContent=exact(shownWallet);
    if(shownMoney!==targetMoney||shownWallet!==targetWallet)frame=requestAnimationFrame(animate);else{frame=0;last=0;}
  }
  function pulse(name){panel.classList.remove(name);void panel.offsetWidth;panel.classList.add(name);}
  panel.addEventListener('animationend',e=>{if(e.animationName==='cash-rise')panel.classList.remove('paying');});
  G.updateAchievementUI=()=>{
    const delta=G.state.coins-targetWallet;
    if(delta>0){$('money-burst').textContent='+'+G.fmt(delta);pulse('paying');}
    if(G.shotMoney<targetMoney||G.reduced)shownMoney=G.shotMoney;
    if(G.state.coins<targetWallet||G.reduced)shownWallet=G.state.coins;
    targetMoney=G.shotMoney;targetWallet=G.state.coins;
    if(!frame)frame=requestAnimationFrame(animate);
    const s=G.latestAchievement;
    const compact=n=>Number(n.toFixed(2)).toString();
    $('arrow-receipt').hidden=!s;
    $('score-source').textContent=s?'#'+s.id:'—';
    $('score-tag').title=s?`最近得分：第 ${s.id} 箭`:'等待得分';
    $('achievement-mult').textContent='×'+compact(s?.mult||1);
    $('achievement-badge').hidden=!(s?.mult>1);
    $('achievement-badge').title=`成就倍率 ×${compact(s?.mult||1)}，作用于整箭并追补收入`;
    $('achievement-badge').setAttribute('aria-label',$('achievement-badge').title);
    $('bounty-mult').textContent='×'+compact(s?.bountyMult||1);
    $('bounty-badge').hidden=!(s?.bountyMult>1);
    $('bounty-badge').title=`当前赏金倍率 ×${compact(s?.bountyMult||1)}`;
    $('bounty-badge').setAttribute('aria-label',$('bounty-badge').title);
    $('arrow-income').textContent='+'+G.fmt(s?.paid||0);
    $('arrow-receipt').setAttribute('aria-label',s?`第 ${s.id} 箭砖块收入 ${Math.round(s.paid)} 金币`:'等待得分');
    $('combo-rules').textContent=`当前装备：第 1 块连击倍率 ×1，此后每块增加 ${G.comboStep().toFixed(3)}，第 ${G.comboCapKills()} 块达到 ×${G.comboMultiplierCap().toFixed(1)} 上限。砖块 LV.6 解锁连击强化，每级让每连增幅 +0.025、倍率上限 +0.5；第 2 块起即可提高倍率。`;
     const e=G.achievementEvent;
    if(e&&e.serial!==event){event=e.serial;$('achievement-ticker').textContent=`第 ${e.arrow} 支箭 · ${e.name} · ${bonusText(e.bonus)}`;$('achievement-ticker').classList.add('hot');}
    else if(!e){event=0;$('achievement-ticker').textContent='';$('achievement-ticker').classList.remove('hot');}
    const stamp=JSON.stringify(G.state.achievements||{});
    if(stamp!==library){
      library=stamp;const h=G.state.achievements||{};
      $('achievement-count').textContent=G.achievementCatalog.filter(a=>h[a.id]>0).length+' / '+G.achievementCatalog.length;
      $('achievement-list').innerHTML=G.achievementCatalog.map(a=>`<div class="achievement-item ${h[a.id]?'earned':''}" style="--achievement-accent:${emblems[a.id].color}"><span class="achievement-item-icon" aria-hidden="true">${emblemSVG(a.id)}</span><b>${a.name}</b><span class="achievement-item-bonus" aria-label="成就倍率增加 ${a.bonus}">${bonusText(a.bonus)}</span><small>${a.description} · ${h[a.id]?'已达成 '+h[a.id]+' 次':'尚未达成'}</small></div>`).join('');
    }
  };
  G.ui();
})();
