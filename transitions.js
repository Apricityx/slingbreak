(() => {
  'use strict';
  // Cross-state transitions: core reveal, clear settlement, level hand-off,
  // reset rewind, draft deal and dialog morphs. Game rules stay untouched: this
  // file only wraps entry points and choreographs the DOM around them.
  const G=Game,$=id=>document.getElementById(id);
  const motion=matchMedia('(prefers-reduced-motion: reduce)'),still=()=>motion.matches;
  const arena=$('arena'),canvas=$('game');
  const wait=ms=>new Promise(r=>setTimeout(r,ms));
  const settle=a=>a.finished.catch(()=>{});
  const out='cubic-bezier(.22,1,.36,1)',spring='cubic-bezier(.2,1.3,.4,1)',accel='cubic-bezier(.5,0,.75,0)';
  const pad=n=>String(n).padStart(2,'0');
  const onScreen=r=>r.width>0&&r.bottom>0&&r.top<innerHeight&&r.right>0&&r.left<innerWidth;
  const toClient=(x,y)=>{
    const r=canvas.getBoundingClientRect(),v=G.view||{scale:r.width/G.W,offsetX:0,offsetY:0};
    return{x:r.left+v.offsetX+x*v.scale,y:r.top+v.offsetY+y*v.scale};
  };

  // Input lock: while a transition owns the screen, a stray tap cannot fire an arrow.
  let lockedUntil=0;
  G.lockInput=ms=>{lockedUntil=Math.max(lockedUntil,performance.now()+ms);G.drag=null;G.pointer=null;};
  const shoot=G.shoot;
  G.shoot=(...args)=>performance.now()<lockedUntil?false:shoot(...args);

  // Hit-stop: the simulation freezes for a beat when the core breaks.
  let frozenUntil=0;
  const tick=G.tick;
  G.tick=dt=>{if(performance.now()<frozenUntil)return;tick(dt);};

  // ── 5. Core reveal: the HUD meter answers the canvas materialisation (render.js).
  const spawnCore=G.spawnCore;
  G.spawnCore=(quiet=false,...rest)=>{
    const absent=!G.core,result=spawnCore(quiet,...rest);
    if(absent&&G.core&&!quiet&&!still()){
      document.querySelector('.core-progress')?.animate([{scale:'1',filter:'none'},{scale:'1.07',filter:'brightness(1.3)',offset:.3},{scale:'1',filter:'none'}],{duration:640,easing:'ease-out'});
      $('progress-bar')?.animate([{boxShadow:'0 0 0 0 #9bcc5d00'},{boxShadow:'0 0 14px 3px #9bcc5dcc',offset:.35},{boxShadow:'0 0 0 0 #9bcc5d00'}],{duration:1000});
    }
    return result;
  };

  // ── 6. Core break → settlement: hit-stop, impact frame, CLEAR stamp, coins to wallet.
  function flyCoins(bonus){
    const target=document.querySelector('.wallet-readout'),t=target?.getBoundingClientRect();
    if(!t||!onScreen(t))return;
    const from=toClient(390,80),count=Math.min(14,6+Math.floor(Math.log10(Math.max(10,bonus))*2));
    for(let i=0;i<count;i++){
      const coin=document.createElement('i');coin.className='flying-coin';coin.setAttribute('aria-hidden','true');document.body.append(coin);
      const sx=from.x+(Math.random()-.5)*60,sy=from.y+(Math.random()-.5)*30,ex=t.left+14,ey=t.top+t.height/2;
      const mx=(sx+ex)/2+(Math.random()-.5)*140,my=Math.min(sy,ey)-50-Math.random()*90;
      const flight=coin.animate([
        {transform:`translate(${sx}px,${sy}px) scale(.2)`,opacity:0},
        {transform:`translate(${sx+(Math.random()-.5)*70}px,${sy-24-Math.random()*20}px) scale(1)`,opacity:1,offset:.2},
        {transform:`translate(${mx}px,${my}px) scale(.85)`,opacity:1,offset:.62},
        {transform:`translate(${ex}px,${ey}px) scale(.45)`,opacity:.9}
      ],{duration:860,delay:320+i*55,easing:'cubic-bezier(.45,0,.35,1)',fill:'both'});
      flight.finished.then(()=>{coin.remove();target.animate([{scale:'1.14'},{scale:'1'}],{duration:200,easing:'ease-out'});},()=>coin.remove());
    }
  }
  async function stampClear(level,bonus){
    const stamp=document.createElement('div');stamp.className='clear-stamp';stamp.setAttribute('aria-hidden','true');
    stamp.innerHTML=`<span>LEVEL ${pad(level)}</span><strong>CLEAR</strong><b>+ 0</b>`;
    arena.append(stamp);
    const amount=stamp.querySelector('b');
    await wait(140);
    stamp.animate([{opacity:0,scale:'1.7',filter:'blur(8px)'},{opacity:1,scale:'.95',filter:'blur(0)',offset:.55},{opacity:1,scale:'1',filter:'blur(0)'}],{duration:340,easing:'ease-out',fill:'both'});
    const start=performance.now();
    const count=()=>{
      const p=Math.min(1,(performance.now()-start-120)/760),e=1-(1-Math.max(0,p))**3;
      amount.textContent='+ '+G.fmt(Math.round(bonus*e));
      if(p<1&&stamp.isConnected)requestAnimationFrame(count);
    };
    requestAnimationFrame(count);
    flyCoins(bonus);
    await wait(1300);
    await settle(stamp.animate([{opacity:1,translate:'0 0'},{opacity:0,translate:'0 -20px'}],{duration:260,easing:accel,fill:'forwards'}));
    stamp.remove();
  }
  const clear=G.clear;
  G.clear=(...args)=>{
    if(G.phase==='clearing')return clear(...args);
    const level=G.state.level,result=clear(...args);
    if(G.phase!=='clearing'||still())return result;
    frozenUntil=performance.now()+130;
    // The DOM stamp carries the same message as these canvas floats.
    G.texts=G.texts.filter(t=>t.text!=='核心击破'&&!String(t.text).startsWith('关卡奖金'));
    canvas.animate([{filter:'brightness(1.9) saturate(1.5)'},{filter:'none'}],{duration:340,easing:'ease-out'});
    stampClear(level,G.settledBonus??G.bonus(level));
    return result;
  };

  // ── 7 / 11. Curtain wipe that covers the board swap before the draft opens.
  // G.holdDraft keeps skills-ui from opening the draft and render.js from
  // drawing the new board until the curtain starts peeling away.
  G.holdDraft=false;
  let handoff=false,rewinding=false;
  async function wipe({eyebrow,from,to,note}){
    G.lockInput(1100);
    const el=document.createElement('div');el.className='level-wipe';el.setAttribute('aria-hidden','true');
    el.innerHTML=`<i class="level-wipe-accent"></i><div class="level-wipe-panel"><span>${eyebrow}</span><strong><b>${from??to}</b>${from!=null?`<b>${to}</b>`:''}</strong><em>${note}</em></div>`;
    arena.append(el);
    const curtain=[{clipPath:'inset(0 100% 0 0)'},{clipPath:'inset(0 0 0 0)',offset:.34},{clipPath:'inset(0 0 0 0)',offset:.62},{clipPath:'inset(0 0 0 100%)'}];
    const timing={duration:1050,easing:'cubic-bezier(.65,0,.35,1)',fill:'forwards'};
    const accent=el.firstElementChild,panel=el.lastElementChild,digits=[...panel.querySelectorAll('strong b')];
    const runs=[accent.animate(curtain,timing),panel.animate(curtain,{...timing,delay:70})];
    panel.firstElementChild.animate([{opacity:0,translate:'40px 0'},{opacity:1,translate:'0 0',offset:.4},{opacity:1,translate:'0 0',offset:.7},{opacity:0,translate:'-30px 0'}],{duration:1050,easing:out,fill:'both'});
    panel.lastElementChild.animate([{opacity:0,translate:'60px 0'},{opacity:0,translate:'60px 0',offset:.2},{opacity:1,translate:'0 0',offset:.5},{opacity:1,translate:'0 0',offset:.7},{opacity:0,translate:'-40px 0'}],{duration:1050,easing:out,fill:'both'});
    if(digits.length===2)for(const d of digits)d.animate([{translate:'0 0'},{translate:'0 0',offset:.36},{translate:'0 -100%',offset:.56},{translate:'0 -100%'}],{duration:1050,easing:spring,fill:'both'});
    else digits[0].animate([{opacity:0,scale:'1.3'},{opacity:0,scale:'1.3',offset:.25},{opacity:1,scale:'1',offset:.48},{opacity:1,scale:'1'}],{duration:1050,easing:out,fill:'both'});
    await wait(640);
    G.holdDraft=false;
    // Without a pending draft the board ripples in as the curtain peels.
    if(G.phase==='ready'&&!G.boardEntrance){G.boardEntrance={start:G.time,end:G.time+1.05,origin:{x:390,y:-40}};G.phase='entering';}
    G.ui();
    await Promise.all(runs.map(settle));
    el.remove();
  }
  const generate=G.generate;
  G.generate=(...args)=>{
    const levelUp=G.phase==='clearing'&&!rewinding&&!still();
    const previous=G.state.level-1;
    if(levelUp){G.holdDraft=true;handoff=true;}
    const result=generate(...args);
    if(levelUp)wipe({eyebrow:'NEXT LEVEL',from:pad(previous),to:pad(G.state.level),note:'新的局面'}).finally(()=>{G.holdDraft=false;handoff=false;G.ui();});
    return result;
  };
  const toast=G.toast;
  G.toast=text=>{if(handoff&&/^LEVEL /.test(text))return;toast(text);};
  G.rewind=async()=>{
    if(still()){G.reset();G.toast('新的开始 · LEVEL 1');return;}
    rewinding=true;G.holdDraft=true;G.lockInput(1800);
    const shrunk={scale:'.95',filter:'grayscale(1) blur(3px)',opacity:.55};
    const fold=arena.animate([{scale:'1',filter:'none',opacity:1},shrunk],{duration:360,easing:accel,fill:'forwards'});
    try{
      await settle(fold);
      G.reset();
      const curtain=wipe({eyebrow:'RESTART',to:'LEVEL 01',note:'从第一箭重新开始'});
      arena.animate([shrunk,{scale:'1',filter:'none',opacity:1}],{duration:480,easing:out});
      fold.cancel();
      await curtain;
    }finally{fold.cancel();rewinding=false;G.holdDraft=false;G.ui();}
    G.toast('新的开始 · LEVEL 1');
  };

  // ── Level tag odometer: the old number rolls out as the new one rolls in.
  const levelEl=$('level');let shownLevel=levelEl.textContent;
  new MutationObserver(()=>{
    const next=levelEl.textContent;if(next===shownLevel)return;
    const prev=shownLevel;shownLevel=next;if(still()||!prev)return;
    const dir=Number(next)>=Number(prev)?1:-1,ghost=document.createElement('b');
    ghost.className='level-ghost';ghost.textContent=prev;ghost.setAttribute('aria-hidden','true');
    Object.assign(ghost.style,{left:levelEl.offsetLeft+'px',top:levelEl.offsetTop+'px'});
    levelEl.parentElement.append(ghost);
    ghost.animate([{translate:'0 0',opacity:1},{translate:`0 ${-dir*.9}em`,opacity:0}],{duration:420,easing:'cubic-bezier(.6,0,.3,1)',fill:'forwards'}).finished.then(()=>ghost.remove(),()=>ghost.remove());
    levelEl.animate([{translate:`0 ${dir*.9}em`,opacity:0},{translate:'0 0',opacity:1}],{duration:520,delay:70,easing:spring,fill:'backwards'});
  }).observe(levelEl,{childList:true,characterData:true,subtree:true});

  // ── 3. Draft deal: cards flip in from edge-on, rare cards catch a glint.
  const draft=$('skill-draft');
  new MutationObserver(()=>{
    if(!draft.open||still())return;
    [...draft.querySelectorAll('#draft-loadout .skill-queue-slot')].forEach((slot,i)=>slot.animate([{opacity:0,scale:'.8'},{opacity:1,scale:'1'}],{duration:360,delay:90+i*45,easing:spring,fill:'backwards'}));
    [...draft.querySelectorAll('.skill-card')].forEach((card,i)=>{
      const delay=160+i*95,tier=card.querySelector('.skill-rarity')?.dataset.tier;
      card.animate([
        {opacity:0,translate:'0 70px',rotate:'y 86deg',scale:'.86'},
        {opacity:1,offset:.3},
        {opacity:1,translate:'0 -8px',rotate:'y -7deg',scale:'1.02',offset:.68},
        {opacity:1,translate:'0 0',rotate:'y 0deg',scale:'1'}
      ],{duration:700,delay,easing:out,fill:'backwards'});
      card.querySelector('.skill-emblem')?.animate([{scale:'0',rotate:'-40deg'},{scale:'1',rotate:'0deg'}],{duration:480,delay:delay+260,easing:spring,fill:'backwards'});
      card.classList.remove('deal-glint');
      if(tier==='gold'||tier==='blue'){void card.offsetWidth;card.style.setProperty('--glint-delay',delay+520+'ms');card.classList.add('deal-glint');}
    });
  }).observe(draft,{attributes:true,attributeFilter:['open']});

  // ── 9 / 10. Dialog morphs: panels grow out of the control that opened them,
  // fold back into it on close, and push the panel underneath back a step.
  let lastTrigger=null;
  document.addEventListener('pointerdown',e=>{lastTrigger=e.target.closest?.('button,summary,[role="button"]')||null;},true);
  document.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' ')lastTrigger=document.activeElement;},true);
  const nativeClose=HTMLDialogElement.prototype.close;
  const stack=[];
  const sourceRect=el=>{if(!el?.isConnected)return null;const r=el.getBoundingClientRect();return onScreen(r)?r:null;};
  function folded(dialog,source){
    const d=dialog.getBoundingClientRect(),s=source||{left:d.left+d.width/2-24,top:d.top+d.height/2+40,width:48,height:48};
    const dx=s.left+s.width/2-(d.left+d.width/2),dy=s.top+s.height/2-(d.top+d.height/2);
    const k=Math.max(.08,Math.min(.6,Math.max(s.width/d.width,s.height/d.height)));
    return{transform:`translate(${dx}px,${dy}px) scale(${k})`,opacity:0};
  }
  const backdrop=(dialog,frames,duration)=>{try{return dialog.animate(frames,{duration,easing:'ease-out',fill:'forwards',pseudoElement:'::backdrop'});}catch{return null;}};
  for(const dialog of ['shop','skill-library','skill-detail','reset-dialog','equipment'].map($).filter(Boolean)){
    dialog.classList.add('is-morph');
    let source=null,closing=false,fade=null;
    new MutationObserver(()=>{
      if(!dialog.open||closing||stack.includes(dialog))return;
      source=lastTrigger&&!dialog.contains(lastTrigger)?lastTrigger:null;
      const below=stack.at(-1);stack.push(dialog);
      if(still())return;
      if(below)below._cover=below.animate([{scale:'1',filter:'none'},{scale:'.94',filter:'brightness(.92)'}],{duration:320,easing:out,fill:'forwards'});
      dialog.animate([folded(dialog,sourceRect(source)),{opacity:1,offset:.35},{transform:'none',opacity:1}],{duration:460,easing:spring});
      fade=backdrop(dialog,[{opacity:0},{opacity:1}],280);
    }).observe(dialog,{attributes:true,attributeFilter:['open']});
    dialog.close=function(value){
      if(!dialog.open||closing)return;
      if(still()){nativeClose.call(dialog,value);return;}
      closing=true;
      const fold=dialog.animate([{transform:'none',opacity:1},folded(dialog,sourceRect(source))],{duration:250,easing:'cubic-bezier(.5,0,.8,.4)',fill:'forwards'});
      const clearing=backdrop(dialog,[{opacity:1},{opacity:0}],250);
      const done=()=>{if(!closing)return;closing=false;fold.cancel();clearing?.cancel();fade?.cancel();nativeClose.call(dialog,value);};
      fold.finished.then(done,done);setTimeout(done,420);
    };
    dialog.addEventListener('cancel',e=>{e.preventDefault();dialog.close();});
    dialog.addEventListener('close',()=>{
      const i=stack.indexOf(dialog);if(i>=0)stack.splice(i,1);
      const below=stack.at(-1),cover=below?._cover;
      if(cover){below._cover=null;cover.cancel();if(!still())below.animate([{scale:'.94',filter:'brightness(.92)'},{scale:'1',filter:'none'}],{duration:380,easing:spring});}
    });
  }
})();
