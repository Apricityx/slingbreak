(() => {
  'use strict';
  // Skill rerolls: the draft's refresh bar and the in-run swap panel inside the
  // skill detail dialog. Rules live in game.js (charges, cap) and skills.js
  // (rerollDraft / offerSwap / swapSkill); this file only renders and moves.
  //
  // Motion language shared by both surfaces:
  //   charge   – the spent diamond pip bursts and a spark carries it to the cards;
  //   flap     – old cards fold away edge-on like a split-flap board;
  //   reel     – each new emblem spins through the catalog and clicks to a stop,
  //              one card after another, and the rarity stamps in on landing.
  const G=window.Game,S=G.state,$=id=>document.getElementById(id);
  const draft=$('skill-draft'),detail=$('skill-detail');
  const out='cubic-bezier(.22,1,.36,1)',spring='cubic-bezier(.2,1.3,.4,1)',accel='cubic-bezier(.5,0,.75,0)';
  const tierColor={white:'#8a9a78',blue:'#439be8',gold:'#e0ad2c'};
  const byId=new Map(G.skillCatalog.map(s=>[s.id,s]));
  const icons=[...new Set(G.skillCatalog.map(s=>s.icon))];
  const wait=ms=>new Promise(r=>setTimeout(r,ms));
  const still=()=>G.reduced;
  const zk=()=>window.SlingStage?.k||1;
  const settle=(animations,timeout)=>new Promise(resolve=>{
    let done=false;const finish=()=>{if(!done){done=true;clearTimeout(timer);resolve();}};
    const timer=setTimeout(finish,timeout);
    Promise.all(animations.map(a=>a.finished.catch(()=>{}))).then(finish,finish);
  });
  // The detail dialog pauses the game, and paused audio is muted: open the
  // gate for one cue only.
  function cue(type,n=1){
    if(!G.paused){G.sound(type,n);return;}
    G.paused=false;G.audio?.sync?.();
    try{G.sound(type,n);}finally{G.paused=true;G.audio?.sync?.();}
  }
  const tierCue=tier=>tier==='gold'?'gold':tier==='blue'?'chime':'tap';
  // Wordless charge gauge: one diamond per slot of the cap. Full diamonds are
  // banked charges; the first empty one fills from the bottom with the levels
  // cleared towards the next charge (the 5-level cycle), so the gauge alone
  // says how many there are, how many fit, and how close the next one is.
  // The same reading goes to assistive tech through aria-label only.
  const progress=()=>G.rerolls()>=G.rerollCap()?0:(G.state.level-1)%G.rerollEvery/G.rerollEvery;
  const reading=()=>{
    const n=G.rerolls(),cap=G.rerollCap();
    return `技能刷新 ${n} / ${cap}`+(n<cap?`，第 ${G.nextRerollLevel()} 关通关后 +1`:'');
  };
  function pips(el,{ghost=0}={}){
    const n=G.rerolls(),cap=G.rerollCap(),total=Math.min(G.rerollCapMax,cap+ghost),p=progress();
    while(el.children.length<total){const pip=document.createElement('i');pip.className='reroll-pip';el.append(pip);}
    while(el.children.length>total)el.lastElementChild.remove();
    [...el.children].forEach((pip,i)=>{
      pip.classList.toggle('is-full',i<n);pip.classList.toggle('is-ghost',i>=cap);
      const charging=i===n&&i<cap&&p>0;pip.classList.toggle('is-charging',charging);
      const fill=charging?String(Math.round(p*100)/100):'0';
      if(pip.style.getPropertyValue('--fill')!==fill)pip.style.setProperty('--fill',fill);
    });
  }
  // Every gauge shares the same accessible reading; HUD and report chips are images.
  const label=(el,text)=>{if(el.getAttribute('aria-label')!==text)el.setAttribute('aria-label',text);};
  function flash(el,cls,ms){el.classList.remove(cls);void el.offsetWidth;el.classList.add(cls);setTimeout(()=>el.classList.remove(cls),ms);}
  // The pip about to be spent is the last full one.
  const spentPip=el=>el.children[G.rerolls()-1];

  function press(button){
    if(still())return;
    button.animate([{transform:'scale(1)'},{transform:'scale(.93)',offset:.25},{transform:'scale(1.04)',offset:.6},{transform:'scale(1)'}],{duration:420,easing:out});
    button.querySelector('.reroll-icon')?.animate([{transform:'rotate(0deg) scale(1)'},{transform:'rotate(-30deg) scale(.9)',offset:.18},{transform:'rotate(400deg) scale(1.15)',offset:.75},{transform:'rotate(360deg) scale(1)'}],{duration:760,easing:'cubic-bezier(.3,0,.2,1)'});
  }
  // A charge spark flies from the spent pip to a target, inside the open dialog
  // (its own top layer), so it needs no z-index tricks on any browser.
  function spark(host,from,to,color){
    if(still()||!from||!to)return;
    const h=host.getBoundingClientRect(),k=zk(),a=from.getBoundingClientRect(),b=to.getBoundingClientRect();
    const x0=(a.left+a.width/2-h.left)/k+host.scrollLeft,y0=(a.top+a.height/2-h.top)/k+host.scrollTop;
    const x1=(b.left+b.width/2-h.left)/k+host.scrollLeft,y1=(b.top+b.height/2-h.top)/k+host.scrollTop;
    const el=document.createElement('i');el.className='reroll-spark';el.setAttribute('aria-hidden','true');
    if(color)window.SlingColors.set(el,'--spark-color',color);
    host.append(el);
    const mx=(x0+x1)/2+(x1>x0?-40:40),my=Math.min(y0,y1)-30;
    el.animate([
      {transform:`translate(${x0}px,${y0}px) rotate(45deg) scale(.4)`,opacity:0},
      {transform:`translate(${x0}px,${y0-10}px) rotate(135deg) scale(1.3)`,opacity:1,offset:.15},
      {transform:`translate(${mx}px,${my}px) rotate(300deg) scale(1)`,opacity:1,offset:.6},
      {transform:`translate(${x1}px,${y1}px) rotate(405deg) scale(.3)`,opacity:0}
    ],{duration:520,easing:'cubic-bezier(.45,0,.3,1)'}).finished.then(()=>el.remove(),()=>el.remove());
  }

  // ── Slot-machine reel inside an emblem. Resolves when the final icon locks.
  function reel(emblem,finalIcon,delay,duration,tick){
    const box=document.createElement('span');box.className='reroll-reel';box.setAttribute('aria-hidden','true');
    const strip=document.createElement('span');strip.className='reroll-reel-strip';
    // Cells run top → bottom. The strip rises through seven icons, overshoots
    // half a cell into the spare one below the final, then settles back.
    const cells=9,final=cells-2,pool=icons.filter(name=>name!==finalIcon);
    for(let i=0;i<cells;i++){
      const cell=document.createElement('span');cell.className='reroll-reel-cell'+(i===final?' is-final':'');
      const icon=document.createElement('i');icon.setAttribute('data-lucide',i===final?finalIcon:pool[Math.floor(Math.random()*pool.length)]);
      cell.append(icon);strip.append(cell);
    }
    box.append(strip);emblem.append(box);emblem.classList.add('is-reeling');lucide.createIcons({root:box});
    const at=index=>`translate(0,${-index/cells*100}%)`;
    const spin=strip.animate([
      {transform:at(0),easing:'cubic-bezier(.3,.1,.3,1)'},
      {transform:at(final+.28),offset:.84,easing:'cubic-bezier(.3,0,.4,1)'},
      {transform:at(final)}
    ],{duration,delay,fill:'both'});
    // Clicks follow the reel as it slows: dense at first, spaced out at the end.
    const timers=[];
    if(tick)for(let i=1;i<=6;i++)timers.push(setTimeout(()=>{if(box.isConnected)tick();},delay+duration*.86*(1-Math.pow(1-i/6,.55))));
    return settle([spin],delay+duration+300).then(()=>{
      timers.forEach(clearTimeout);
      emblem.classList.remove('is-reeling');box.remove();
    });
  }
  // The landing beat for a card or option row once its reel locks.
  function land(card,emblem,tier){
    card.classList.remove('is-reeling');
    if(still())return;
    emblem.animate([{transform:'scale(1.28)'},{transform:'scale(.92)',offset:.45},{transform:'scale(1)'}],{duration:460,easing:'ease-out'});
    card.animate([{boxShadow:`0 0 0 0 ${tierColor[tier]}aa`},{boxShadow:`0 0 0 9px ${tierColor[tier]}00`}],{duration:620,easing:out});
    const ribbon=card.querySelector('.skill-rarity');
    ribbon?.animate([{opacity:0,transform:'scale(1.9)'},{opacity:1,transform:'scale(.92)',offset:.55},{opacity:1,transform:'scale(1)'}],{duration:380,easing:'ease-out'});
    flash(card,'is-landed',900);
    if(tier==='gold'||tier==='blue'){card.classList.remove('deal-glint');void card.offsetWidth;card.style.setProperty('--glint-delay','120ms');card.classList.add('deal-glint');}
  }

  // ── Draft refresh bar ───────────────────────────────────────────────
  const barButton=$('reroll-draft'),barPips=$('draft-reroll-pips'),options=$('draft-options');
  let rolling=false,lastCount=G.rerolls(),pendingGain=0,reported=false;
  function updateBar(){
    pips(barPips);label(barButton,`重抽三选一，${reading()}`);
    const off=rolling||!G.rerolls()||G.phase!=='draft'||draft.classList.contains('is-selecting');
    if(barButton.disabled!==off)barButton.disabled=off;
  }
  async function rerollDraft(){
    if(rolling||!G.canReroll()||G.phase!=='draft'||draft.classList.contains('is-selecting'))return;
    G.audio?.unlock?.();
    const old=[...options.children];
    if(still()){if(G.rerollDraft()){G.flushUi();options.firstElementChild?.focus({preventScroll:true});}return;}
    rolling=true;
    const pip=spentPip(barPips),flips=[];
    try{
      old.forEach(c=>c.disabled=true);barButton.disabled=true;
      press(barButton);if(pip)flash(pip,'is-spending',700);
      cue('reroll');
      spark(draft,pip||barButton,old[old.length-1]||options,tierColor.gold);
      await wait(160);
      flash(options,'is-scanning',900);
      // Split-flap out, bottom card first: the spark lands at the bottom.
      old.slice().reverse().forEach((card,i)=>flips.push(card.animate([
        {transform:'perspective(700px) rotateX(0deg) scale(1)',opacity:1},
        {transform:'perspective(700px) rotateX(-12deg) scale(1.02)',opacity:1,offset:.3},
        {transform:'perspective(700px) rotateX(90deg) scale(.94)',opacity:.2}
      ],{duration:260,delay:i*60,easing:accel,fill:'forwards'})));
      await settle(flips,700);
      if(!G.rerollDraft())return;
      G.flushUi();
      await dealDraft();
    }finally{
      flips.forEach(a=>a.cancel());
      rolling=false;updateBar();
      [...options.children].forEach(c=>c.disabled=false);
      refocus(barButton.disabled?options.firstElementChild:barButton);
    }
  }
  // Disabling the focused card drops focus to <body>: put it back once dealt.
  function refocus(el){
    if(draft.open&&(!draft.contains(document.activeElement)||document.activeElement===document.body))el?.focus({preventScroll:true});
  }
  // Opening the draft deals the first hand exactly like a refresh: cards flap
  // in edge-on, emblems reel and lock one after another with their tier cue.
  async function openDeal(){
    if(rolling||still()||!options.children.length)return;
    rolling=true;updateBar();
    try{cue('deal');await dealDraft();}
    finally{
      rolling=false;updateBar();
      if(!draft.classList.contains('is-selecting'))[...options.children].forEach(c=>c.disabled=false);
      refocus(options.firstElementChild);
    }
  }
  new MutationObserver(()=>{if(draft.open)openDeal();}).observe(draft,{attributes:true,attributeFilter:['open']});
  function dealDraft(){
    const cards=[...options.children],lands=[];
    cards.forEach((card,i)=>{
      card.disabled=true;card.classList.add('is-reeling');
      const skill=byId.get(card.dataset.skill),emblem=card.querySelector('.skill-emblem');
      const delay=i*70,spinDelay=delay+120,spin=520+i*230;
      card.animate([
        {transform:'perspective(700px) rotateX(-90deg) scale(.94)',opacity:.2},
        {transform:'perspective(700px) rotateX(10deg) scale(1.01)',opacity:1,offset:.62},
        {transform:'perspective(700px) rotateX(0deg) scale(1)',opacity:1}
      ],{duration:440,delay,easing:out,fill:'backwards'});
      if(!emblem||!skill)return;
      lands.push(reel(emblem,skill.icon,spinDelay,spin,()=>{if(G.phase==='draft')G.sound('tick');}).then(()=>{
        land(card,emblem,skill.tier);
        if(G.phase==='draft')G.sound(tierCue(skill.tier));
      }));
    });
    return Promise.all(lands).then(()=>wait(still()?0:140));
  }
  barButton.addEventListener('click',rerollDraft);
  draft.addEventListener('keydown',e=>{
    if(e.repeat||e.ctrlKey||e.metaKey||e.altKey||e.key.toLowerCase()!=='r')return;
    e.preventDefault();if(!barButton.disabled)rerollDraft();
  });

  // A new charge lights its diamond at once in the HUD gauge, and again in the
  // draft or detail gauge the next time one of them opens.
  const gain=(el,gained,delay)=>{
    if(still()||!gained)return;
    const n=G.rerolls();
    [...el.children].slice(Math.max(0,n-gained),n).forEach((pip,i)=>setTimeout(()=>flash(pip,'is-gaining',900),delay+i*140));
  };
  function celebrate(el){const gained=pendingGain;pendingGain=0;gain(el,gained,560);}

  // HUD gauge: pinned to the skill bar's corner, out of flow so the bar (and
  // so the board scale) never changes height.
  const hudGauge=document.createElement('span');
  hudGauge.className='reroll-gauge hud-reroll';hudGauge.setAttribute('role','img');
  hudGauge.innerHTML='<i data-lucide="refresh-cw" aria-hidden="true"></i><span class="reroll-pips" aria-hidden="true"></span>';
  document.querySelector('.skill-live')?.append(hudGauge);lucide.createIcons({root:hudGauge});
  const hudPips=hudGauge.lastElementChild;
  function updateHud(){
    pips(hudPips);label(hudGauge,reading());
    hudGauge.classList.toggle('is-empty',!G.rerolls());
  }

  // Shop row: the gauge plus a dashed ghost diamond for the slot the next upgrade adds.
  G.paintRerollGauge=(el,{ghost=0}={})=>{
    if(!el)return;pips(el.querySelector('.reroll-pips'),{ghost});
    label(el,reading()+(ghost?`，升级后上限 ${G.rerollCap()+ghost}`:''));
  };
  G.updateRerollUI=()=>{
    const n=G.rerolls(),gained=n>lastCount?n-lastCount:0;
    lastCount=n;
    updateBar();updateHud();if(detail.open)updateSwap();
    if(gained){pendingGain+=gained;if(!reported)gain(hudPips,gained,640);reported=false;}
    if(draft.open)celebrate(barPips);
  };

  // ── In-run swap panel (skill detail dialog) ────────────────────────
  const panel=$('skill-swap'),swapPips=$('swap-pips'),swapOptions=$('swap-options'),swapButton=$('swap-reroll');
  const detailEmblem=$('skill-detail-emblem');
  let swapping=false,pending=null,shownKey='',morphs=[];
  const target=()=>detail.dataset.skill;
  // No visible copy here: the button itself is the gauge. A spin-locked icon
  // (is-waiting) marks "not while arrows fly"; empty diamonds mark "no charge".
  function updateSwap(){
    const id=target(),owned=!!id&&G.skillRank(id)===1;
    panel.hidden=!owned;if(!owned)return;
    pips(swapPips);
    const n=G.rerolls(),offer=G.swapOffer(id),ready=G.canSwapSkill();
    panel.classList.toggle('is-waiting',!ready);panel.classList.toggle('has-offer',!!offer);
    label(swapButton,`${offer?'重新抽取':'抽取'}三个技能替换${byId.get(id).name}，${reading()}${ready?'':'，本轮结束后可用'}`);
    swapButton.disabled=swapping||!ready||!n;
    const key=offer?offer.options.join(','):'';
    if(key!==shownKey&&!swapping){shownKey=key;renderOffer(offer,false);}
    [...swapOptions.children].forEach(row=>{row.disabled=swapping||!ready;});
  }
  function renderOffer(offer,animated){
    swapOptions.replaceChildren();swapOptions.hidden=!offer;
    if(!offer)return [];
    return offer.options.map((id,i)=>{
      const skill=byId.get(id),row=document.createElement('button');
      row.type='button';row.className='swap-option';row.dataset.skill=id;row.dataset.tier=skill.tier;
      window.SlingColors.set(row,'--skill-color',G.skillColor(id));
      row.setAttribute('aria-label',`替换为${skill.name}，${G.skillTiers[skill.tier].name}，${skill.describe(1)}`);
      row.innerHTML=`<span class="skill-emblem" aria-hidden="true"><i data-lucide="${skill.icon}"></i></span><span class="swap-option-body"><span class="swap-option-head"><strong>${skill.name}</strong><span class="skill-rarity" data-tier="${skill.tier}"><span class="rarity-dot"></span>${G.skillTiers[skill.tier].name}</span></span><span class="swap-option-desc">${skill.describe(1)}</span></span><i class="swap-option-go" data-lucide="arrow-left-right" aria-hidden="true"></i>`;
      row.addEventListener('click',()=>pick(id,row));
      swapOptions.append(row);lucide.createIcons({root:row});
      if(animated)row.classList.add('is-reeling');
      return row;
    });
  }
  async function swapReroll(){
    const id=target();
    if(swapping||!G.canSwapSkill()||!G.canReroll()||!id)return;
    const old=[...swapOptions.children],pip=spentPip(swapPips);
    if(still()){if(G.offerSwap(id)){shownKey='';updateSwap();swapOptions.firstElementChild?.focus({preventScroll:true});}return;}
    swapping=true;swapButton.disabled=true;old.forEach(r=>r.disabled=true);
    const flips=[];
    try{
      press(swapButton);if(pip)flash(pip,'is-spending',700);cue('reroll');
      spark(detail,pip||swapButton,detailEmblem,G.skillColor(id));
      // The current skill flinches: it is the one being put up for exchange.
      flash(detailEmblem,'is-targeted',700);
      old.slice().reverse().forEach((row,i)=>flips.push(row.animate([
        {transform:'perspective(600px) rotateX(0deg)',opacity:1},
        {transform:'perspective(600px) rotateX(90deg)',opacity:0}
      ],{duration:220,delay:i*50,easing:accel,fill:'forwards'})));
      await settle(flips,600);await wait(old.length?0:120);
      const offer=G.offerSwap(id);if(!offer)return;
      shownKey=offer.options.join(',');
      const opening=swapOptions.hidden,from=swapOptions.offsetHeight;
      const rows=renderOffer(offer,true);
      // The list grows open the first time, so the dialog does not jump.
      if(opening)swapOptions.animate([{height:'0px',opacity:0},{height:swapOptions.offsetHeight+'px',opacity:1}],{duration:360,easing:out});
      else if(from)swapOptions.animate([{height:from+'px'},{height:swapOptions.offsetHeight+'px'}],{duration:260,easing:out});
      updateSwap();
      const lands=rows.map((row,i)=>{
        const skill=byId.get(row.dataset.skill),emblem=row.querySelector('.skill-emblem'),delay=60+i*80;
        row.disabled=true;
        row.animate([
          {transform:'perspective(600px) translate(0,-10px) rotateX(-90deg)',opacity:0},
          {transform:'perspective(600px) translate(0,2px) rotateX(12deg)',opacity:1,offset:.6},
          {transform:'perspective(600px) translate(0,0) rotateX(0deg)',opacity:1}
        ],{duration:420,delay,easing:out,fill:'backwards'});
        return reel(emblem,skill.icon,delay+100,440+i*200,()=>cue('tick')).then(()=>{land(row,emblem,skill.tier);cue(tierCue(skill.tier));});
      });
      await Promise.all(lands);
    }finally{
      flips.forEach(a=>a.cancel());
      swapping=false;updateSwap();
      if(detail.open&&!detail.contains(document.activeElement))(swapOptions.firstElementChild||swapButton).focus({preventScroll:true});
    }
  }
  swapButton.addEventListener('click',swapReroll);

  // Picking a candidate: the chosen row lifts, the rest fall away, its emblem
  // flies into the header, and the header flips over to the new skill. The
  // queue itself changes on close, so the dialog folds back to the old slot
  // and the slot then flips over in the HUD.
  let pickToken=0;
  async function pick(id,row){
    const from=target(),skill=byId.get(id);
    if(swapping||!G.canSwapSkill()||!skill||!G.swapOffer(from)?.options.includes(id))return;
    swapping=true;pending={from,id};const token=++pickToken;
    const rows=[...swapOptions.children];rows.forEach(r=>r.disabled=true);swapButton.disabled=true;
    cue(tierCue(skill.tier));
    if(still()){detail.close();return;}
    row.classList.add('is-chosen');
    // The others fall away, then fold shut (height, padding and their share of
    // the flex gap), so the list closes up around the pick instead of leaving
    // holes. The dialog is centred, so it shrinks from both edges at once.
    const gap=parseFloat(getComputedStyle(swapOptions).rowGap)||0,folds=[];
    rows.filter(r=>r!==row).forEach((r,i)=>{
      r.animate([{transform:'translate(0,0) rotate(0deg)',opacity:1},{transform:`translate(${i?16:-16}px,26px) rotate(${i?4:-4}deg)`,opacity:0}],{duration:300,delay:i*40,easing:accel,fill:'forwards'});
      const box=getComputedStyle(r);
      folds.push(r.animate([
        {height:box.height,paddingTop:box.paddingTop,paddingBottom:box.paddingBottom,borderTopWidth:box.borderTopWidth,borderBottomWidth:box.borderBottomWidth,marginBottom:'0px'},
        {height:'0px',paddingTop:'0px',paddingBottom:'0px',borderTopWidth:'0px',borderBottomWidth:'0px',marginBottom:-gap+'px'}
      ],{duration:280,delay:200+i*40,easing:out,fill:'forwards'}));
      r.style.overflow='hidden';
    });
    row.animate([{transform:'translate(0,0) scale(1)'},{transform:'translate(0,-4px) scale(1.03)'}],{duration:220,easing:spring,fill:'forwards'});
    // The emblem's flight measures the header after the dialog has settled.
    await settle(folds,700);
    if(token!==pickToken||!detail.open)return;
    await flyEmblem(row.querySelector('.skill-emblem'),detailEmblem,G.skillColor(id));
    if(token!==pickToken||!detail.open)return;
    await morphHeader(skill);
    if(token!==pickToken||!detail.open)return;
    await settle([panel.animate([{opacity:1,transform:'translate(0,0)'},{opacity:0,transform:'translate(0,8px)'}],{duration:220,easing:accel,fill:'forwards'})],400);
    await wait(260);
    if(token===pickToken&&detail.open)detail.close();
  }
  function flyEmblem(from,to,color){
    if(!from||!to)return Promise.resolve();
    const h=detail.getBoundingClientRect(),k=zk(),a=from.getBoundingClientRect(),b=to.getBoundingClientRect();
    const ghost=document.createElement('span');ghost.className='swap-ghost skill-emblem';ghost.setAttribute('aria-hidden','true');
    window.SlingColors.set(ghost,'--skill-color',color);ghost.innerHTML=from.innerHTML;
    const w=a.width/k,x0=(a.left-h.left)/k+detail.scrollLeft,y0=(a.top-h.top)/k+detail.scrollTop;
    const s=b.width/a.width,x1=(b.left-h.left)/k+detail.scrollLeft,y1=(b.top-h.top)/k+detail.scrollTop;
    ghost.style.width=ghost.style.height=w+'px';
    detail.append(ghost);from.style.visibility='hidden';
    const mx=(x0+x1)/2+30,my=Math.min(y0,y1)-24;
    const flight=ghost.animate([
      {transform:`translate(${x0}px,${y0}px) scale(1) rotate(0deg)`},
      {transform:`translate(${mx}px,${my}px) scale(${(1+s)/2*1.15}) rotate(-12deg)`,offset:.55},
      {transform:`translate(${x1}px,${y1}px) scale(${s}) rotate(0deg)`}
    ],{duration:480,easing:'cubic-bezier(.5,0,.25,1)',fill:'forwards'});
    return settle([flight],700).then(()=>{ghost.remove();});
  }
  morphs=[];
  async function morphHeader(skill){
    const head=[detailEmblem,$('skill-detail-name'),$('skill-detail-family'),$('skill-detail-meta'),$('skill-detail-text')];
    const half=head.map((el,i)=>el.animate([{transform:'perspective(500px) rotateY(0deg)',opacity:1},{transform:'perspective(500px) rotateY(90deg)',opacity:.3}],{duration:150,delay:i*25,easing:accel,fill:'forwards'}));
    await settle(half,450);
    window.SlingColors.set(detail,'--skill-detail-color',G.skillColor(skill.id));
    detailEmblem.innerHTML=`<i data-lucide="${skill.icon}"></i>`;
    head[1].textContent=skill.name;head[2].textContent=`${skill.family} · 跨关生效`;
    head[3].innerHTML=`<span class="skill-rarity" data-tier="${skill.tier}"><span class="rarity-dot"></span>${G.skillTiers[skill.tier].name}</span>`;
    head[4].textContent=skill.describe(1);
    lucide.createIcons({root:detailEmblem});lucide.createIcons({root:head[3]});
    half.forEach(a=>a.cancel());
    morphs=head.map((el,i)=>el.animate([{transform:'perspective(500px) rotateY(-90deg)',opacity:.3},{transform:'perspective(500px) rotateY(8deg)',opacity:1,offset:.7},{transform:'perspective(500px) rotateY(0deg)',opacity:1}],{duration:320,delay:i*30,easing:out,fill:'backwards'}));
    burst(detailEmblem,skill.tier);
    await settle(morphs,700);
  }
  function burst(el,tier){
    const ring=document.createElement('i');ring.className='swap-burst';ring.dataset.tier=tier;ring.setAttribute('aria-hidden','true');
    el.append(ring);
    ring.animate([{transform:'scale(.6)',opacity:1},{transform:'scale(2.3)',opacity:0}],{duration:620,easing:out}).finished.then(()=>ring.remove(),()=>ring.remove());
  }

  // HUD landing after the dialog has folded back into the old slot.
  const queue=document.querySelector('.skill-live .skill-queue');
  function landHud(old,id){
    const slot=queue&&[...queue.children].find(s=>s.dataset.skill===id),skill=byId.get(id);
    if(!slot||!skill)return;
    if(still()){flash(slot,'is-sheen',700);return;}
    const flap=document.createElement('span');flap.className='swap-flap';flap.setAttribute('aria-hidden','true');
    window.SlingColors.set(flap,'--skill-color',G.skillColor(old.id));
    flap.innerHTML=`<b><i data-lucide="${old.icon}"></i>${old.name}</b>`;
    slot.classList.add('is-swapping');slot.append(flap);lucide.createIcons({root:flap});
    const content=slot.firstElementChild;
    flap.animate([{transform:'perspective(260px) rotateX(0deg)',opacity:1},{transform:'perspective(260px) rotateX(-90deg)',opacity:.4}],{duration:200,easing:accel,fill:'forwards'})
      .finished.then(()=>flap.remove(),()=>flap.remove());
    content?.animate([{transform:'perspective(260px) rotateX(90deg)',opacity:0},{transform:'perspective(260px) rotateX(90deg)',opacity:0,offset:.38},{transform:'perspective(260px) rotateX(-14deg)',opacity:1,offset:.78},{transform:'perspective(260px) rotateX(0deg)',opacity:1}],{duration:520,easing:out});
    const c=tierColor[skill.tier];
    slot.animate([{boxShadow:`0 0 0 0 ${c}cc`},{boxShadow:`0 0 0 10px ${c}00`}],{duration:700,delay:200,easing:out});
    setTimeout(()=>{flash(slot,'is-sheen',800);slot.classList.remove('is-swapping');},240);
    if(G.skillFX){G.skillFX(id,G.origin.x,G.origin.y,{kind:'launch',r:120,force:true});}
    G.ring?.(G.origin.x,G.origin.y,G.skillColor(id),110);
  }

  detail.addEventListener('close',()=>{
    pickToken++;morphs.forEach(a=>a.cancel());morphs=[];
    panel.getAnimations?.().forEach(a=>a.cancel());
    const move=pending;pending=null;swapping=false;
    if(!move)return;
    const old=byId.get(move.from);
    if(G.swapSkill(move.from,move.id))requestAnimationFrame(()=>landHud(old,move.id));
  });
  new MutationObserver(()=>{
    if(!detail.open)return;
    pending=null;swapping=false;shownKey='\0';
    updateSwap();celebrate(swapPips);
  }).observe(detail,{attributes:true,attributeFilter:['open']});

  // Charge earned on a 5th clear: the level report carries a wordless gauge
  // whose new diamond lights up with the report. Without a report (reduced
  // motion off-path) the HUD gauge's own flash is the cue.
  const clear=G.clear;
  G.clear=(...args)=>{
    const before=G.phase,result=clear(...args);
    if(before!=='clearing'&&G.phase==='clearing'&&G.rerollGained){
      G.rerollGained=false;
      const reports=document.querySelectorAll('.clear-scene .level-report'),report=reports[reports.length-1];
      if(report){
        const chip=document.createElement('div');chip.className='reroll-gauge report-reroll';chip.setAttribute('role','img');
        chip.innerHTML='<i data-lucide="refresh-cw" aria-hidden="true"></i><span class="reroll-pips" aria-hidden="true"></span>';
        const row=chip.lastElementChild;pips(row);
        row.children[G.rerolls()-1]?.classList.add('is-new');
        label(chip,reading());
        report.insertBefore(chip,report.querySelector('.report-continue'));lucide.createIcons({root:chip});
        reported=true;
      }
    }
    return result;
  };

  updateBar();
})();
