(() => {
  const G=Game,$=id=>document.getElementById(id),draft=$('skill-draft'),library=$('skill-library');
  const baseUi=G.ui;let draftKey='',ownedKey='',libraryPaused=false,selecting=false;
  function waitForAnimations(animations,timeout=700){
    return new Promise(resolve=>{
      let settled=false;
      const finish=()=>{if(settled)return;settled=true;clearTimeout(timer);resolve();};
      const timer=setTimeout(finish,timeout);
      Promise.all(animations.map(animation=>animation.finished.catch(()=>{}))).then(finish,finish);
    });
  }
  const tierColor={white:'#8a9a78',blue:'#439be8',gold:'#e0ad2c'};
  const spring='cubic-bezier(.2,1.3,.4,1)';
  const hudQueue=()=>document.querySelector('.skill-live .skill-queue');
  const onScreen=r=>r.width>0&&r.bottom>0&&r.top<innerHeight&&r.right>0&&r.left<innerWidth;
  // The flight ghost lives on <body>, zoomed by the stage scale, and slots sit
  // inside the scaled stage: both take client px ÷ k.
  const zk=()=>window.SlingStage?.k||1;
  const zoomRect=r=>{const k=zk();return{left:r.left/k,top:r.top/k,width:r.width/k,height:r.height/k};};
  // Draft → board, in three beats:
  // 1. commit  – the pick lifts and shines while the other two cards fall away;
  // 2. flight  – a ghost leaves the dialog and arcs into its HUD slot, morphing
  //              from a card into a slot while the queue slides to make room;
  // 3. impact  – the slot pops, the arena rings, and bricks ripple in from the
  //              landing point (render.js reads boardEntrance.origin).
  async function selectSkill(id){
    if(selecting||G.phase!=='draft'||G.paused)return;
    selecting=true;
    G.audio.unlock();
    const options=$('draft-options'),cards=[...options.children],card=cards.find(c=>c.dataset.skill===id);
    const skill=G.skillCatalog.find(s=>s.id===id),color=tierColor[skill?.tier]||tierColor.white;
    const running=[];let ghost=null,landed=null,entrance=null;
    // Tracked animations are cancelled on exit; the landing pop and queue slide outlive it.
    const play=(el,frames,options)=>{const a=el.animate(frames,{fill:'forwards',...options});running.push(a);return a;};
    cards.forEach(c=>c.disabled=true);
    draft.classList.add('is-selecting');
    G.sound('pick',{blue:1,gold:2}[skill?.tier]||0);
    try{
      if(G.reduced||!card){
        if(G.chooseSkill(id)){draft.close();$('game').focus({preventScroll:true});}
        return;
      }
      // Capture layout, not the transformed client rect: the latter includes
      // the commit lift and zoom, and would reflow the cloned text immediately.
      const layout=getComputedStyle(card),cardWidth=layout.width,cardHeight=layout.height;
      const textBoxes=[...card.querySelectorAll('.skill-card-body,.skill-card-name,.skill-card-desc,.skill-family,.skill-chance,.skill-card-tier,.skill-pick')].map(el=>{
        const style=getComputedStyle(el);return{width:style.width,height:style.height};
      });
      // Beat 1: commit.
      // The grid still contains deal-in overflow, but its 16px top padding is
      // too small for the lift + 4% growth around the card's low transform origin.
      // Include spring overshoot and the pick ring, also for tall descriptions.
      options.style.setProperty('--draft-commit-headroom',Math.ceil(16+parseFloat(cardHeight)*.04)+'px');
      window.SlingColors.set(card,'--pick-color',color);card.classList.add('is-picked');
      const lift=play(card,[{transform:'translate(0,0) scale(1)'},{transform:'translate(0,-10px) scale(1.04)'}],{duration:300,easing:spring});
      cards.filter(c=>c!==card).forEach((c,i)=>play(c,[{opacity:1,transform:'translate(0,0) rotate(0deg) scale(1)'},{opacity:0,transform:`translate(0,34px) rotate(${c.compareDocumentPosition(card)&Node.DOCUMENT_POSITION_FOLLOWING?-4:4}deg) scale(.92)`}],{duration:260,delay:40+i*50,easing:'cubic-bezier(.5,0,.75,0)'}));
      for(const el of [draft.querySelector('.draft-header'),$('draft-loadout')])play(el,[{opacity:1,transform:'translate(0,0)'},{opacity:0,transform:'translate(0,-8px)'}],{duration:220,easing:'ease-in'});
      await waitForAnimations([lift],500);
      await new Promise(r=>setTimeout(r,90));
      // Beat 2: a transparent dialog keeps the flight above the draft's top layer,
      // including Chrome 89, which has no Popover API. No z-index workaround.
      const from=zoomRect(card.getBoundingClientRect()),owned=G.activeSkills(),full=owned.length===G.skillSlots;
      const queue=hudQueue(),slots=queue?[...queue.children]:[],targetSlot=slots[full?slots.length-1:owned.length];
      let to=targetSlot?.getBoundingClientRect();
      if(!to||!onScreen(to)){const r=zoomRect($('game').getBoundingClientRect());to={left:r.left+r.width/2-60,top:r.top+24,width:120,height:34};}
      else to=zoomRect(to);
      const before=new Map(slots.filter(s=>s.dataset.skill).map(s=>[s.dataset.skill,zoomRect(s.getBoundingClientRect())]));
      ghost=document.createElement('dialog');ghost.className='skill-flight';ghost.setAttribute('aria-hidden','true');
      ghost.addEventListener('cancel',e=>e.preventDefault());
      window.SlingColors.set(ghost,'--pick-color',color);
      const flyingCard=card.cloneNode(true);flyingCard.className='skill-flight-card skill-card';
      for(const el of [flyingCard,...flyingCard.querySelectorAll('[id]')])el.removeAttribute('id');
      flyingCard.removeAttribute('aria-labelledby');flyingCard.removeAttribute('aria-describedby');
      Object.assign(flyingCard.style,{width:cardWidth,height:cardHeight});
      [...flyingCard.querySelectorAll('.skill-card-body,.skill-card-name,.skill-card-desc,.skill-family,.skill-chance,.skill-card-tier,.skill-pick')].forEach((el,i)=>Object.assign(el.style,textBoxes[i]));
      const flyingSlot=document.createElement('span');flyingSlot.className='skill-flight-slot skill-queue-slot';
      flyingSlot.innerHTML=`<b><i data-lucide="${skill.icon}"></i>${skill.name}</b>`;
      // The shell morphs, but both sets of text have a fixed layout box. Only
      // their transforms/opacity change; neither can wrap again mid-flight.
      Object.assign(flyingSlot.style,{width:to.width+'px',height:to.height+'px'});
      ghost.append(flyingCard,flyingSlot);
      Object.assign(ghost.style,{left:from.left+'px',top:from.top+'px',width:from.width+'px',height:from.height+'px'});
      document.body.append(ghost);lucide.createIcons({root:ghost});
      ghost.showModal();
      card.style.visibility='hidden';
      draft.classList.add('is-leaving');
      const fade=play(draft,[{opacity:1,transform:'scale(1)'},{opacity:0,transform:'scale(.985)'}],{duration:220,easing:'ease-in'});
      const dx=to.left-from.left,dy=to.top-from.top,flight=640;
      G.sound('whoosh');
      const path=play(ghost,[
        {left:from.left+'px',top:from.top+'px',width:from.width+'px',height:from.height+'px',borderRadius:'7px',transform:'rotate(0deg)'},
        {left:from.left+dx*.45+'px',top:from.top+Math.min(0,dy)*.45-70+'px',width:from.width*.62+to.width*.38+'px',height:from.height*.5+to.height*.5+'px',borderRadius:'6px',transform:`rotate(${dx<0?-5:5}deg)`,offset:.45},
        {left:to.left+'px',top:to.top+'px',width:to.width+'px',height:to.height+'px',borderRadius:'5px',transform:'rotate(0deg)'}
      ],{duration:flight,easing:'cubic-bezier(.45,0,.2,1)'});
      const sx=from.width/parseFloat(cardWidth),sy=from.height/parseFloat(cardHeight);
      play(flyingCard,[{opacity:1,transform:`translate(-50%,-50%) scale(${sx},${sy})`},{opacity:0,transform:`translate(-50%,-50%) scale(${sx*.55},${sy*.55})`}],{duration:flight*.45,easing:'ease-in'});
      play(ghost.lastElementChild,[{opacity:0},{opacity:0,offset:.35},{opacity:1}],{duration:flight*.7,easing:'ease-out'});
      await waitForAnimations([fade],400);
      // Commit mid-flight so the HUD queue shifts while the ghost is still airborne.
      if(!G.chooseSkill(id))return;
      entrance=G.boardEntrance;
      if(entrance){entrance.start=entrance.end=Infinity;}
      draft.close();$('game').focus({preventScroll:true});
      landed=hudQueue()?.querySelector(`[data-skill="${id}"]`);
      if(landed)landed.style.visibility='hidden';
      for(const slot of hudQueue()?.children||[]){
        const old=before.get(slot.dataset.skill);if(!old||slot===landed)continue;
        const now=zoomRect(slot.getBoundingClientRect());
        slot.animate([{transform:`translate(${old.left-now.left}px,${old.top-now.top}px)`},{transform:'translate(0,0)'}],{duration:380,easing:spring});
      }
      if(full&&owned[0]){
        const old=before.get(owned[0].id),oldSlot=old&&slots.find(s=>s.dataset.skill===owned[0].id);
        if(oldSlot){
          const drop=document.createElement('dialog');drop.className='skill-queue-slot skill-flight-drop';drop.innerHTML=oldSlot.innerHTML;drop.setAttribute('aria-hidden','true');
          drop.style.cssText=oldSlot.style.cssText;
          drop.addEventListener('cancel',e=>e.preventDefault());
          Object.assign(drop.style,{left:old.left+'px',top:old.top+'px',width:old.width+'px',height:old.height+'px'});
          document.body.append(drop);drop.showModal();
          drop.animate([{opacity:1,transform:'translate(0,0) rotate(0deg)'},{opacity:0,transform:'translate(-10px,36px) rotate(-8deg)'}],{duration:420,easing:'cubic-bezier(.5,0,.75,0)',fill:'forwards'}).finished.then(()=>drop.remove(),()=>drop.remove());
        }
      }
      await waitForAnimations([path],flight+200);
      // Beat 3: impact.
      G.sound('slot');
      if(landed){
        landed.style.visibility='';
        landed.animate([{transform:'scale(1.14)',boxShadow:`0 0 0 0 ${color}aa`},{transform:'scale(.97)',offset:.45},{transform:'scale(1)',boxShadow:`0 0 0 10px ${color}00`}],{duration:460,easing:'ease-out'});
      }
      if(entrance&&G.boardEntrance===entrance){
        const view=G.view,canvas=zoomRect($('game').getBoundingClientRect());
        const x=((to.left+to.width/2)-canvas.left-(view?.offsetX||0))/(view?.scale||1),y=((to.top+to.height/2)-canvas.top-(view?.offsetY||0))/(view?.scale||1);
        entrance.origin={x:Math.max(40,Math.min(G.W-40,x)),y:Math.max(-120,Math.min(160,y))};
        G.ring(entrance.origin.x,Math.max(60,entrance.origin.y),color,420);G.shake=Math.max(G.shake,6);
      }
    }finally{
      // Never leave the board stuck invisible, whatever interrupted the sequence.
      if(entrance&&G.boardEntrance===entrance&&entrance.start===Infinity){entrance.start=G.time;entrance.end=G.time+1.05;}
      if(landed)landed.style.visibility='';
      ghost?.remove();running.forEach(a=>a.cancel());
      options.style.removeProperty('--draft-commit-headroom');
      if(G.phase!=='draft')$('game').focus({preventScroll:true});
      if(card){card.style.visibility='';card.classList.remove('is-picked');}
      draft.classList.remove('is-selecting','is-leaving');
      cards.forEach(c=>c.disabled=false);selecting=false;
    }
  }
  const icons=()=>lucide.createIcons();
  const rarity=skill=>`<span class="skill-rarity" data-tier="${skill.tier}"><span class="rarity-dot"></span>${G.skillTiers[skill.tier].name}</span>`;
  const chance=skill=>`<span class="skill-chance" title="排除已装备技能后，按权重不重复抽取三个技能；已装备技能稀有度越高，本轮稀有/传说技能权重越低，此值已是调整后的出现率">本轮出现率 ${(skill.chance*100).toFixed(2)}%</span>`;
  function update(){
    const owned=G.activeSkills(),outgoing=G.outgoingSkill(),key=JSON.stringify(G.state.skills);
    $('skill-count').textContent=`${owned.length} / ${G.skillSlots}`;
    if(key!==ownedKey){
      ownedKey=key;$('owned-skills').replaceChildren();
      if(!owned.length)$('owned-skills').textContent=`技能跨关保留，满 ${G.skillSlots} 个后自动替换最早获得的技能`;
      owned.forEach(skill=>{const tag=document.createElement('span');tag.innerHTML=`<i data-lucide="${skill.icon}" aria-hidden="true"></i>${skill.name}`;tag.title=skill.describe(1);tag.classList.toggle('is-outgoing',skill===outgoing);$('owned-skills').append(tag);});
      icons();
    }
     if(G.phase==='draft'){
       $('play-status').textContent='选择新技能 · 滚动构筑';
      const nextKey=JSON.stringify(G.state.draft)+key;
      if(nextKey!==draftKey){
         draftKey=nextKey;$('draft-options').replaceChildren();
         const options=G.state.draft.options;
         $('draft-kicker').textContent=`第 ${G.state.level} 关 · ${options.length===3?'三选一':`${options.length} 选 1`}`;
         $('draft-count').textContent=`${owned.length} / ${G.skillSlots} 已装备`;
         $('draft-loadout').replaceChildren();
         $('draft-loadout').style.setProperty('--slots',G.skillSlots);
         for(let i=0;i<G.skillSlots;i++){
           const skill=owned[i],slot=document.createElement('span');
           slot.className='skill-queue-slot'+(!skill?' is-empty':skill===outgoing?' is-outgoing':'');
           slot.innerHTML=`<b>${skill?`<i data-lucide="${skill.icon}" aria-hidden="true"></i>${skill.name}`:'等待加入'}</b><b class="slot-preview" aria-hidden="true"></b>`;
           if(skill){slot.title=skill.describe(1);window.SlingColors.set(slot,'--skill-color',G.skillColor(skill.id));}
           $('draft-loadout').append(slot);
         }
         // The slot this pick lands in: the outgoing one when full, else the first empty.
         const target=$('draft-loadout').children[outgoing?0:owned.length];
         options.forEach((id,i)=>{
           const skill=G.skillCatalog.find(s=>s.id===id),button=document.createElement('button');
           button.className='skill-card';button.dataset.skill=id;button.dataset.tier=skill.tier;
           window.SlingColors.set(button,'--skill-color',G.skillColor(id));
           button.setAttribute('aria-keyshortcuts',String(i+1));
           button.setAttribute('aria-labelledby',`draft-card-${i}-name draft-card-${i}-tier draft-card-${i}-pick`);
           button.setAttribute('aria-describedby',`draft-card-${i}-desc`);
           button.innerHTML=`<span class="skill-card-art" aria-hidden="true"><span class="skill-emblem"><i data-lucide="${skill.icon}"></i></span><kbd class="skill-key">${i+1}</kbd></span><span id="draft-card-${i}-tier" class="skill-card-tier">${rarity(skill)}</span><span class="skill-card-body"><strong id="draft-card-${i}-name" class="skill-card-name">${skill.name}</strong><span class="skill-family">${skill.family} · 跨关生效</span><span id="draft-card-${i}-desc" class="skill-card-desc">${skill.describe(1)}</span>${chance(skill)}</span><span id="draft-card-${i}-pick" class="skill-pick${outgoing?' is-swap':''}"><span>${outgoing?`替换「${outgoing.name}」`:'加入技能槽'}</span><i data-lucide="${outgoing?'arrow-left-right':'arrow-up-right'}"></i></span>`;
           const preview=on=>{
             if(!target||selecting&&!on)return;
             target.classList.toggle('is-previewing',on);
             if(on)target.lastElementChild.innerHTML=button.querySelector('.skill-emblem').innerHTML+skill.name;
             window.SlingColors.set(target,'--preview-color',G.skillColor(id));
           };
           button.onpointerenter=()=>preview(true);button.onpointerleave=()=>preview(false);
           button.onfocus=()=>{if(button.matches(':focus-visible'))preview(true);};button.onblur=()=>preview(false);
           button.onclick=()=>{preview(true);selectSkill(id);};$('draft-options').append(button);
        });
        icons();
      }
      if(!G.holdDraft&&!draft.open&&!window.SlingBreakIntro?.active&&!document.querySelector('dialog[open]'))draft.showModal();
    }else{
      if(draft.open)draft.close();
    }
  }
   let uiQueued=false;
   const flushUi=G.flushUi;
   const paintUi=()=>{
     if(!uiQueued)return;uiQueued=false;baseUi();update();G.updateAchievementUI?.();G.updateRerollUI?.();
     if(G.revokedSkills?.length&&!window.SlingBreakIntro?.active){
       G.toast(`已收回未解锁技能：${G.revokedSkills.map(s=>`${s.name}（需第 ${s.minLevel} 关）`).join('、')}`);
       G.revokedSkills=null;
     }
   };
   G.flushUi=()=>{flushUi?.();paintUi();};
    G.ui=()=>{
     if(uiQueued)return;
     uiQueued=true;
       requestAnimationFrame(paintUi);
   };
  draft.addEventListener('cancel',e=>e.preventDefault());
  draft.addEventListener('keydown',e=>{
    if(e.key==='Escape'){e.stopPropagation();return;}
    if(e.repeat||e.ctrlKey||e.metaKey||e.altKey)return;
    const cards=[...$('draft-options').children];
    // 1/2/3 pick directly; arrows walk the row (grid is a column on mobile).
    const n=Number(e.key);
    if(n>=1&&n<=cards.length){e.preventDefault();cards[n-1].click();return;}
    const step={ArrowRight:1,ArrowDown:1,ArrowLeft:-1,ArrowUp:-1}[e.key];
    if(!step)return;
    const at=cards.indexOf(document.activeElement),next=at<0?(step>0?0:cards.length-1):(at+step+cards.length)%cards.length;
    e.preventDefault();cards[next]?.focus();
  });
  $('open-skills').onclick=()=>{
    libraryPaused=G.paused;G.paused=true;G.drag=null;G.audio.sync();$('library-grid').replaceChildren();
     const owned=G.activeSkills();
     owned.forEach(skill=>{const item=document.createElement('article');item.className='library-item';item.innerHTML=`<span class="skill-family">${skill.family}</span><span class="skill-emblem"><i data-lucide="${skill.icon}"></i></span><h3>${skill.name}</h3>${rarity(skill)}<p>${skill.describe(1)}</p>`;$('library-grid').append(item);});
     if(!owned.length)$('library-grid').textContent=`尚未装备技能。每关选择一个，逐步组成你的 ${G.skillSlots} 技能构筑。`;
     if(!library.open)library.showModal();icons();
   };
   $('close-skills').onclick=()=>library.close();
   library.addEventListener('click',e=>{if(e.target===library)library.close();});
  library.addEventListener('close',()=>{G.paused=libraryPaused;G.audio.sync();G.ui();});
  G.ui();
})();
