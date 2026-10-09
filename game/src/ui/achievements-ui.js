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
  const pops=document.createElement('div');pops.className='achievement-pops';pops.setAttribute('aria-hidden','true');panel.querySelector('.earnings-main').append(pops);
  // One polite announcement per card, not per DOM change.
  const announcer=document.createElement('p');announcer.className='sr-only';announcer.setAttribute('role','status');panel.append(announcer);
  // Cards animate on the compositor: CSS/WAAPI own transform and opacity, and JS
  // only keeps a small clock for hand-offs. Achievements from the same arrow
  // merge into one card, so a burst reads as one big moment instead of flicker.
  const holdFor=760,mergeHold=520,exitDuration=380,maxStacked=2,maxMarks=3;
  const queue=[],stacked=[];
  let current=null,exiting=null,popLast=0,speed=1,popFrame=0;
  const reduced=()=>G.reduced||matchMedia('(prefers-reduced-motion: reduce)').matches;
  const blocked=()=>G.paused||document.hidden||!!document.querySelector('dialog[open]');
  const busy=()=>queue.length||current||stacked.length||exiting;
  const scheduleAchievementFrame=()=>{if(!popFrame&&busy()&&!blocked())popFrame=requestAnimationFrame(loop);};
  const title=g=>g.items.length===1?g.items[0].name:`${['','','双重','三重','四重'][g.items.length]||g.items.length+' 重'}成就`;
  const subtitle=g=>g.items.length>1?g.items.map(i=>i.name).join(' · '):'';
  let replayId=0;const replayIds=new WeakMap(),pendingReplay=new WeakMap();
  const replay=(el,cls)=>{
    if(!el||reduced())return;
    let id=replayIds.get(el);if(!id){id=++replayId;replayIds.set(el,id);}
    let pending=pendingReplay.get(el);if(!pending){pending={classes:new Set(),queued:false};pendingReplay.set(el,pending);}
    pending.classes.add(cls);if(pending.queued)return;pending.queued=true;
    const paint=()=>{pending.queued=false;pending.classes.forEach(name=>el.classList.remove(name));void el.offsetWidth;pending.classes.forEach(name=>el.classList.add(name));pending.classes.clear();};
    // Keep one restart per element/class per frame instead of forcing layout
    // once for every achievement in a synchronous burst.
    if(G.deferVisual)G.deferVisual(`achievement-replay:${id}:${cls}`,paint);else paint();
  };
  const play=(el,frames,options)=>reduced()?null:el.animate(frames,options);
  function markup(g){
    const hero=g.hero;
    hero.classList.toggle('is-major',g.bonus>=1||g.items.length>=3);
    window.SlingColors.set(hero,'--hero-accent',emblems[g.items[g.items.length-1].id].color);
    hero.querySelector('.achievement-hero-name').textContent=title(g);
    const sub=hero.querySelector('.achievement-hero-sub');sub.textContent=subtitle(g);sub.hidden=!sub.textContent;
    hero.querySelector('.achievement-hero-bonus').textContent=bonusText(g.bonus);
    g.el.setAttribute('aria-label',`第 ${g.arrow} 支箭，${title(g)}，加成 ${bonusText(g.bonus)}`);
  }
  function addMark(g,item){
    const marks=g.hero.querySelector('.achievement-hero-marks'),mark=document.createElement('span');
    mark.className='achievement-hero-mark';mark.innerHTML=emblemSVG(item.id);window.SlingColors.set(mark,'--mark-accent',emblems[item.id].color);
    marks.append(mark);while(marks.children.length>maxMarks)marks.firstElementChild.remove();
    [...marks.children].forEach((m,i,all)=>{m.style.setProperty('--mark-index',all.length-1-i);m.classList.toggle('is-older-mark',i<all.length-1);});
    g.mark=mark;
  }
  function open(g){
    const el=document.createElement('div');el.className='achievement-pop';
    el.innerHTML='<div class="achievement-hero"><i class="hero-flash"></i><i class="hero-sweep"></i><span class="achievement-hero-marks"></span><span class="achievement-hero-rays">'+[-150,-100,-50,0,50,100,150].map(a=>`<i style="--ray-angle:${a}deg"></i>`).join('')+'</span><span class="achievement-hero-text"><strong class="achievement-hero-name"></strong><small class="achievement-hero-sub" hidden></small></span><span class="achievement-hero-bonus"></span></div>';
    g.el=el;g.hero=el.firstElementChild;g.age=0;g.hold=holdFor;
    g.items.forEach(item=>addMark(g,item));markup(g);
    pops.append(el);panel.classList.add('is-achievement');
    current=g;bumpBadge();
  }
  function restack(){
    stacked.forEach((g,i)=>{
      const depth=i+1;g.el.style.zIndex=String(maxStacked-i);
      g.depthAnim?.cancel();
      g.depthAnim=play(g.hero,[{transform:`translateY(${-(depth-1)*7}px) scale(${1-(depth-1)*.06})`},{transform:`translateY(${-depth*7}px) scale(${1-depth*.06})`}],{duration:260,easing:'cubic-bezier(.22,1,.36,1)',fill:'forwards'});
      if(!g.depthAnim)g.hero.style.transform=`translateY(${-depth*7}px) scale(${1-depth*.06})`;
      g.el.style.opacity=String(1-depth*.28);
    });
  }
  function stackCurrent(){
    current.el.style.zIndex='';stacked.unshift(current);current=null;
    while(stacked.length>maxStacked)stacked.pop().el.remove();
    restack();
  }
  function startExit(){
    const cards=[current,...stacked].filter(Boolean);
    exiting={cards,age:0,pay:cards.reduce((n,g)=>n+g.pay,0),arrow:current?.arrow};
    cards.forEach((g,i)=>{g.exit=play(g.el,[{opacity:g.el.style.opacity||1,transform:'none'},{opacity:0,transform:'translateY(6px) scale(.94)'}],{duration:exitDuration-i*40,delay:i*40,easing:'cubic-bezier(.5,0,.75,0)',fill:'forwards'});});
    current=null;stacked.length=0;
    panel.classList.remove('is-achievement');
  }
  // Coins fly only once the level total is back in view; a card that opens
  // straight after inherits the unpaid amount instead.
  function finishExit(){
    const pay=exiting.pay;exiting.cards.forEach(g=>g.el.remove());exiting=null;
    if(queue.length)queue[0].pay+=pay;else flyPayout(pay);
  }
  // Merging into a card that is already leaving brings it straight back.
  function revive(g){
    exiting.cards.forEach(c=>{if(c!==g)c.el.remove();});exiting=null;
    g.exit?.cancel();g.exit=null;g.el.style.opacity='';g.el.style.zIndex='';g.depthAnim?.cancel();g.hero.style.transform='';
    current=g;panel.classList.add('is-achievement');
  }
  function loop(time){
    popFrame=0;
    if(blocked()){popLast=0;return;}
    const dt=Math.min(50,popLast?time-popLast:0);popLast=time;
    // A queued card cuts an exit short rather than waiting behind it.
    if(exiting){exiting.age+=dt;if(exiting.age>=exitDuration||queue.length)finishExit();}
    if(current){
      current.age+=dt*speed;
      if(current.age>=current.hold){if(queue.length)stackCurrent();else startExit();}
    }
    if(!current&&!exiting&&queue.length)open(queue.shift());
    if(!queue.length)speed=1;
    if(busy())popFrame=requestAnimationFrame(loop);else popLast=0;
  }
  // ── The payoff: a spark links the arrow to its card, and the back-paid coins
  // fly into the level total when the card steps aside.
  let sparks=0,payouts=0;
  function toClient(p){
    if(!p)return null;
    const c=$('game'),r=c.getBoundingClientRect(),v=G.view||{scale:r.width/G.W,offsetX:0,offsetY:0};
    // G.view is canvas layout px; rk maps it to client px under the stage scale.
    const rk=r.width/(c.clientWidth||r.width)||1;
    return{x:r.left+(v.offsetX+p.x*v.scale)*rk,y:r.top+(v.offsetY+p.y*v.scale)*rk};
  }
  // Sparks and chips live on <body>, zoomed by the stage scale: translate() takes client px ÷ k.
  const zk=()=>window.SlingStage?.k||1;
  function toZoomed(p){
    if(!p)return null;const k=zk();return{x:p.x/k,y:p.y/k};
  }
  function zoomRect(r,k){
    return{left:r.left/k,top:r.top/k,right:r.right/k,width:r.width/k,height:r.height/k};
  }
  function launchSpark(from,color,g){
    if(reduced()||!from||sparks>=6)return;
    const k=zk(),target=(g.mark&&g===current?g.mark:pops).getBoundingClientRect();
    const tx=(target.left+Math.min(40*k,target.width/2))/k,ty=(target.top+target.height/2)/k;
    const spark=document.createElement('i');spark.className='achievement-spark';spark.style.setProperty('--spark-color',color);document.body.append(spark);sparks++;
    const mx=(from.x+tx)/2+(from.x<tx?-60:60),my=Math.min(from.y,ty)-40;
     const clean=()=>{
       spark.remove();sparks--;
       if(g.el?.isConnected){replay(g.hero,'is-struck');replay(g.mark,'is-landing');}
     };
     spark.animate([
      {transform:`translate(${from.x}px,${from.y}px) scale(.4)`,opacity:0},
      {transform:`translate(${from.x}px,${from.y-18}px) scale(1.2)`,opacity:1,offset:.15},
      {transform:`translate(${mx}px,${my}px) scale(1)`,opacity:1,offset:.55},
      {transform:`translate(${tx}px,${ty}px) scale(.6)`,opacity:.9}
     ],{duration:520,easing:'cubic-bezier(.45,0,.3,1)'}).finished.then(clean,clean);
  }
  function flyPayout(amount){
    if(amount<1)return;
    const k=zk(),readout=$('shot-money'),from=zoomRect(pops.getBoundingClientRect(),k),to=zoomRect(readout.getBoundingClientRect(),k);
    const land=()=>{replay(panel,'is-backpaid');};
    if(reduced()||!from.width||payouts>=3||document.hidden){land();return;}
    const chip=document.createElement('b');chip.className='achievement-payout-chip';chip.textContent='+'+G.fmt(amount);document.body.append(chip);payouts++;
    const clean=()=>{chip.remove();payouts--;land();};
    chip.animate([
      {transform:`translate(${from.right-90}px,${from.top+from.height/2}px) scale(.8)`,opacity:0},
      {transform:`translate(${from.right-100}px,${from.top+from.height/2-10}px) scale(1.1)`,opacity:1,offset:.25},
      {transform:`translate(${to.left+to.width*.6}px,${to.top+to.height/2}px) scale(.7)`,opacity:.2}
    ],{duration:560,delay:120,easing:'cubic-bezier(.5,0,.3,1)',fill:'backwards'}).finished.then(clean,clean);
  }
  function bumpBadge(){replay($('achievement-badge'),'is-bumped');}
  G.showAchievement=(item,score)=>{
    const entry={id:item.id,name:item.name,bonus:item.bonus};
    // Back-pay this unlock adds to the arrow: its bonus applied to what the arrow already earned.
    const pay=Math.max(0,(score.base||0)*item.bonus);
    let g=[current,...queue].find(g=>g&&g.arrow===score.id);
    if(!g&&exiting?.arrow===score.id){g=exiting.cards.find(c=>c.arrow===score.id);if(g)revive(g);}
    if(g){
      g.items.push(entry);g.bonus+=item.bonus;g.pay+=pay;
      if(g.el){
        addMark(g,entry);markup(g);g.hold=Math.max(g.hold,g.age+mergeHold);
        replay(g.hero.querySelector('.achievement-hero-bonus'),'is-bumped');replay(g.hero,'is-struck');bumpBadge();
      }
    }else{
      g={arrow:score.id,items:[entry],bonus:item.bonus,pay,el:null};queue.push(g);
    }
    announcer.textContent=`第 ${g.arrow} 支箭，${title(g)}，加成 ${bonusText(g.bonus)}`;
    // Backlog still moves faster, but never so fast that a card cannot be read.
    speed=Math.min(2,1+queue.length*.35);
    const hook=G.juiceAchievement?.(score.id,item.name,emblems[item.id].color);
    launchSpark(toZoomed(toClient(hook)),emblems[item.id].color,g);
    scheduleAchievementFrame();
  };
  const resetGame=G.reset;
  G.reset=()=>{
    queue.length=0;stacked.length=0;current=null;exiting=null;pops.replaceChildren();
    panel.classList.remove('is-achievement');
    cancelAnimationFrame(popFrame);popFrame=0;popLast=0;speed=1;
    return resetGame();
  };
  const exact=n=>G.fmtInteger?G.fmtInteger(n):Math.floor(n).toLocaleString('en-US');
  // Skip unchanged writes: rewriting identical text still replaces the node and dirties layout.
  const setText=(el,value)=>{value=String(value);if(el.textContent!==value)el.textContent=value;};
  const setTitle=(el,value)=>{if(el.title!==value)el.title=value;};
  const setAttr=(el,name,value)=>{if(el.getAttribute(name)!==value)el.setAttribute(name,value);};
  const setHidden=(el,value)=>{if(el.hidden!==value)el.hidden=value;};
  let shownMoney=G.levelMoney,shownWallet=G.state.coins,targetMoney=shownMoney,targetWallet=shownWallet;
  let frame=0,last=0,event=0,library='';
  function animate(time){
    const fraction=1-Math.exp(-Math.min(64,time-(last||time-16))/85);last=time;
    shownMoney+=(targetMoney-shownMoney)*fraction;shownWallet+=(targetWallet-shownWallet)*fraction;
    if(Math.abs(targetMoney-shownMoney)<1)shownMoney=targetMoney;
    if(Math.abs(targetWallet-shownWallet)<1)shownWallet=targetWallet;
    setText($('shot-money'),'+ '+G.fmt(shownMoney));setText($('live-wallet'),exact(shownWallet));
    if(shownMoney!==targetMoney||shownWallet!==targetWallet)frame=requestAnimationFrame(animate);else{frame=0;last=0;}
  }
  function pulse(name){panel.classList.remove(name);void panel.offsetWidth;panel.classList.add(name);}
  panel.addEventListener('animationend',e=>{if(e.animationName==='cash-rise')panel.classList.remove('paying');});
  G.updateAchievementUI=()=>{
    const delta=G.state.coins-targetWallet;
    if(delta>0){$('money-burst').textContent='+'+G.fmt(delta);if(!panel.classList.contains('is-achievement'))pulse('paying');}
    if(G.levelMoney<targetMoney||G.reduced)shownMoney=G.levelMoney;
    if(G.state.coins<targetWallet||G.reduced)shownWallet=G.state.coins;
    targetMoney=G.levelMoney;targetWallet=G.state.coins;
    if(!frame)frame=requestAnimationFrame(animate);
    const s=G.latestAchievement;
    const compact=n=>Number(n.toFixed(2)).toString();
    $('arrow-receipt').classList.toggle('is-idle',!s);
    setText($('score-source'),s?'#'+s.id:'—');
    setTitle($('score-tag'),s?`最近得分：第 ${s.id} 箭`:'等待得分');
    setText($('achievement-mult'),'×'+compact(s?.mult||1));
    const achievementTitle=`成就倍率 ×${compact(s?.mult||1)}，作用于整箭并追补收入`;
    setHidden($('achievement-badge'),!(s?.mult>1));
    setTitle($('achievement-badge'),achievementTitle);
    setAttr($('achievement-badge'),'aria-label',achievementTitle);
    const bountyTitle=`当前赏金倍率 ×${compact(s?.bountyMult||1)}`;
    setText($('bounty-mult'),'×'+compact(s?.bountyMult||1));
    setHidden($('bounty-badge'),!(s?.bountyMult>1));
    $('achievement-badge').parentElement.hidden=!(s?.mult>1||s?.bountyMult>1);
    setTitle($('bounty-badge'),bountyTitle);
    setAttr($('bounty-badge'),'aria-label',bountyTitle);
    setText($('arrow-income'),'+'+G.fmt(s?.paid||0));
    setAttr($('arrow-receipt'),'aria-label',s?`第 ${s.id} 箭砖块收入 ${Math.round(s.paid)} 金币`:'等待得分');
    setText($('combo-rules'),`当前装备：第 1 块连击倍率 ×1，此后每块增加 ${G.comboStep().toFixed(3)}，第 ${G.comboCapKills()} 块达到 ×${G.comboMultiplierCap().toFixed(1)} 上限。砖块 LV.6 解锁连击强化，每级让每连增幅 +0.025、倍率上限 +0.5；第 2 块起即可提高倍率。`);
     const e=G.achievementEvent;
    if(e&&e.serial!==event){event=e.serial;$('achievement-ticker').textContent=`第 ${e.arrow} 支箭 · ${e.name} · ${bonusText(e.bonus)}`;$('achievement-ticker').classList.add('hot');}
    else if(!e){event=0;$('achievement-ticker').textContent='';$('achievement-ticker').classList.remove('hot');}
    const stamp=JSON.stringify(G.state.achievements||{});
    if(stamp!==library){
       library=stamp;const h=G.state.achievements||{};
       $('achievement-count').textContent=G.achievementCatalog.filter(a=>h[a.id]>0).length+' / '+G.achievementCatalog.length;
       $('achievement-list').innerHTML=G.achievementCatalog.map(a=>`<div class="achievement-item ${h[a.id]?'earned':''}" style="${window.SlingColors.style('--achievement-accent',emblems[a.id].color)}"><span class="achievement-item-icon" aria-hidden="true">${emblemSVG(a.id)}</span><b>${a.name}</b><span class="achievement-item-bonus" aria-label="成就倍率增加 ${a.bonus}">${bonusText(a.bonus)}</span><small>${a.description} · ${h[a.id]?'已达成 '+h[a.id]+' 次':'尚未达成'}</small></div>`).join('');
     }
    scheduleAchievementFrame();
  };
  document.addEventListener('visibilitychange',scheduleAchievementFrame);
  document.querySelectorAll('dialog').forEach(dialog=>dialog.addEventListener('close',scheduleAchievementFrame));
  G.ui();
})();
