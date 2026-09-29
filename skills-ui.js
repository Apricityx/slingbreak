(() => {
  const G=Game,$=id=>document.getElementById(id),draft=$('skill-draft'),library=$('skill-library');
  const baseUi=G.ui;let draftKey='',ownedKey='',libraryPaused=false,selecting=false;
  const reducedMotion=matchMedia('(prefers-reduced-motion: reduce)');
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
    const cards=[...$('draft-options').children],card=cards.find(c=>c.dataset.skill===id);
    const skill=G.skillCatalog.find(s=>s.id===id),color=tierColor[skill?.tier]||tierColor.white;
    const running=[];let ghost=null,landed=null,entrance=null;
    // Tracked animations are cancelled on exit; the landing pop and queue slide outlive it.
    const play=(el,frames,options)=>{const a=el.animate(frames,{fill:'forwards',...options});running.push(a);return a;};
    cards.forEach(c=>c.disabled=true);
    draft.classList.add('is-selecting');
    try{
      if(reducedMotion.matches||!card){
        if(G.chooseSkill(id)){draft.close();$('game').focus({preventScroll:true});}
        return;
      }
      // Beat 1: commit.
      card.style.setProperty('--pick-color',color);card.classList.add('is-picked');
      const lift=play(card,[{translate:'0 0',scale:'1'},{translate:'0 -10px',scale:'1.04'}],{duration:300,easing:spring});
      cards.filter(c=>c!==card).forEach((c,i)=>play(c,[{opacity:1,translate:'0 0',rotate:'0deg',scale:'1'},{opacity:0,translate:'0 34px',rotate:(c.compareDocumentPosition(card)&Node.DOCUMENT_POSITION_FOLLOWING?-4:4)+'deg',scale:'.92'}],{duration:260,delay:40+i*50,easing:'cubic-bezier(.5,0,.75,0)'}));
      for(const el of [draft.querySelector('.draft-header'),$('draft-rule'),$('draft-loadout')])play(el,[{opacity:1,translate:'0 0'},{opacity:0,translate:'0 -8px'}],{duration:220,easing:'ease-in'});
      await waitForAnimations([lift],500);
      await new Promise(r=>setTimeout(r,90));
      // Beat 2: flight. The ghost is a popover so it stays above the modal dialog.
      const from=card.getBoundingClientRect(),owned=G.activeSkills(),full=owned.length===G.skillSlots;
      const queue=hudQueue(),slots=queue?[...queue.children]:[],targetSlot=slots[full?slots.length-1:owned.length];
      let to=targetSlot?.getBoundingClientRect();
      if(!to||!onScreen(to)){const r=$('game').getBoundingClientRect();to={left:r.left+r.width/2-60,top:r.top+24,width:120,height:34};}
      const before=new Map(slots.filter(s=>s.dataset.skill).map(s=>[s.dataset.skill,s.getBoundingClientRect()]));
      ghost=document.createElement('div');ghost.className='skill-flight';ghost.setAttribute('aria-hidden','true');
      ghost.style.setProperty('--pick-color',color);
      ghost.innerHTML=`<div class="skill-flight-card skill-card" style="width:${from.width}px;height:${from.height}px">${card.innerHTML}</div><span class="skill-flight-slot skill-queue-slot"><b><i data-lucide="${skill.icon}"></i>${skill.name}</b></span>`;
      Object.assign(ghost.style,{left:from.left+'px',top:from.top+'px',width:from.width+'px',height:from.height+'px'});
      document.body.append(ghost);lucide.createIcons({root:ghost});
      if(ghost.showPopover){ghost.popover='manual';ghost.showPopover();}
      card.style.visibility='hidden';
      draft.classList.add('is-leaving');
      const fade=play(draft,[{opacity:1,scale:'1'},{opacity:0,scale:'.985'}],{duration:220,easing:'ease-in'});
      const dx=to.left-from.left,dy=to.top-from.top,flight=640;
      const path=play(ghost,[
        {left:from.left+'px',top:from.top+'px',width:from.width+'px',height:from.height+'px',borderRadius:'7px',rotate:'0deg'},
        {left:from.left+dx*.45+'px',top:from.top+Math.min(0,dy)*.45-70+'px',width:from.width*.62+to.width*.38+'px',height:from.height*.5+to.height*.5+'px',borderRadius:'6px',rotate:(dx<0?-5:5)+'deg',offset:.45},
        {left:to.left+'px',top:to.top+'px',width:to.width+'px',height:to.height+'px',borderRadius:'5px',rotate:'0deg'}
      ],{duration:flight,easing:'cubic-bezier(.45,0,.2,1)'});
      play(ghost.firstElementChild,[{opacity:1,scale:'1'},{opacity:0,scale:'.55'}],{duration:flight*.45,easing:'ease-in'});
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
        const now=slot.getBoundingClientRect();
        slot.animate([{translate:`${old.left-now.left}px ${old.top-now.top}px`},{translate:'0 0'}],{duration:380,easing:spring});
      }
      if(full&&owned[0]){
        const old=before.get(owned[0].id),drop=old&&slots.find(s=>s.dataset.skill===owned[0].id)?.cloneNode(true);
        if(drop){
          drop.className+=' skill-flight-drop';drop.removeAttribute('data-skill');
          Object.assign(drop.style,{left:old.left+'px',top:old.top+'px',width:old.width+'px',height:old.height+'px'});
          document.body.append(drop);if(drop.showPopover){drop.popover='manual';drop.showPopover();}
          drop.animate([{opacity:1,translate:'0 0',rotate:'0deg'},{opacity:0,translate:'-10px 36px',rotate:'-8deg'}],{duration:420,easing:'cubic-bezier(.5,0,.75,0)',fill:'forwards'}).finished.then(()=>drop.remove(),()=>drop.remove());
        }
      }
      await waitForAnimations([path],flight+200);
      // Beat 3: impact.
      if(landed){
        landed.style.visibility='';
        landed.animate([{scale:'1.14',boxShadow:`0 0 0 0 ${color}aa`},{scale:'.97',offset:.45},{scale:'1',boxShadow:`0 0 0 10px ${color}00`}],{duration:460,easing:'ease-out'});
      }
      if(entrance&&G.boardEntrance===entrance){
        const view=G.view,canvas=$('game').getBoundingClientRect();
        const x=((to.left+to.width/2)-canvas.left-(view?.offsetX||0))/(view?.scale||1),y=((to.top+to.height/2)-canvas.top-(view?.offsetY||0))/(view?.scale||1);
        entrance.origin={x:Math.max(40,Math.min(G.W-40,x)),y:Math.max(-120,Math.min(160,y))};
        G.ring(entrance.origin.x,Math.max(60,entrance.origin.y),color,420);G.shake=Math.max(G.shake,6);
      }
    }finally{
      // Never leave the board stuck invisible, whatever interrupted the sequence.
      if(entrance&&G.boardEntrance===entrance&&entrance.start===Infinity){entrance.start=G.time;entrance.end=G.time+1.05;}
      if(landed)landed.style.visibility='';
      ghost?.remove();running.forEach(a=>a.cancel());
      if(card){card.style.visibility='';card.classList.remove('is-picked');}
      draft.classList.remove('is-selecting','is-leaving');
      cards.forEach(c=>c.disabled=false);selecting=false;
    }
  }
  const icons=()=>lucide.createIcons();
  const rarity=skill=>`<span class="skill-rarity" data-tier="${skill.tier}"><span class="rarity-dot"></span>${G.skillTiers[skill.tier].name}</span>`;
  const chance=skill=>`<span class="skill-chance" title="排除已装备技能后，按权重不重复抽取三个技能；已装备技能稀有度越高，本轮稀有/传说技能权重越低，此值已是调整后的出现率">本轮出现率 ${(skill.chance*100).toFixed(2)}%</span>`;
  const rarityNote=()=>{const pressure=G.skillRarityPressure();return pressure?`已装备高稀有技能带来 ${pressure} 点稀有度压力，本轮稀有与传说技能出现率下调。`:'';};
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
         $('draft-count').textContent=`${owned.length} / ${G.skillSlots} 已装备`;
         $('draft-rule').textContent=outgoing?`选入新技能后，自动替换最早获得的「${outgoing.name}」，其余 ${G.skillSlots-1} 个技能继续生效。${rarityNote()}`:`每关选入 1 个技能，跨关保留；满 ${G.skillSlots} 个后，按获得顺序自动替换最早的技能。${rarityNote()}`;
         $('draft-loadout').replaceChildren();
         for(let i=0;i<G.skillSlots;i++){
           const skill=owned[i],slot=document.createElement('span');
           slot.className='skill-queue-slot'+(!skill?' is-empty':skill===outgoing?' is-outgoing':'');
           slot.innerHTML=`<b>${skill?`<i data-lucide="${skill.icon}" aria-hidden="true"></i>${skill.name}`:'等待加入'}</b>`;
           if(skill)slot.title=skill.describe(1);$('draft-loadout').append(slot);
         }
         for(const id of G.state.draft.options){
           const skill=G.skillCatalog.find(s=>s.id===id),button=document.createElement('button');
           button.className='skill-card';button.dataset.skill=id;button.setAttribute('aria-label',`加入${skill.name}${outgoing?`，自动替换${outgoing.name}`:''}`);
            button.innerHTML=`<span class="skill-card-top"><span class="skill-emblem"><i data-lucide="${skill.icon}"></i></span>${rarity(skill)}</span><h3>${skill.name}</h3><span class="skill-family">${skill.family} / 跨关生效</span><p>${skill.describe(1)}</p>${chance(skill)}<span class="skill-pick">加入技能槽<i data-lucide="arrow-up-right"></i></span>`;
           button.onclick=()=>selectSkill(id);$('draft-options').append(button);
        }
        icons();
      }
      if(!G.holdDraft&&!draft.open&&!window.SlingBreakIntro?.active&&!document.querySelector('dialog[open]'))draft.showModal();
    }else{
      if(draft.open)draft.close();
    }
  }
   let uiQueued=false;
   G.ui=()=>{
     if(uiQueued)return;
     uiQueued=true;
      requestAnimationFrame(()=>{
         uiQueued=false;baseUi();update();G.updateAchievementUI?.();
         // Report migrated-away skills once the entry screen no longer covers the HUD.
         if(G.revokedSkills?.length&&!window.SlingBreakIntro?.active){
           G.toast(`已收回未解锁技能：${G.revokedSkills.map(s=>`${s.name}（需第 ${s.minLevel} 关）`).join('、')}`);
           G.revokedSkills=null;
         }
       });
   };
  draft.addEventListener('cancel',e=>e.preventDefault());
  draft.addEventListener('keydown',e=>{if(e.key==='Escape')e.stopPropagation();});
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
