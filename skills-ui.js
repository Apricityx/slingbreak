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
  async function selectSkill(id){
    if(selecting||G.phase!=='draft'||G.paused)return;
    selecting=true;
    G.audio.unlock();
    const cards=[...$('draft-options').children];
    let exit;
    cards.forEach(card=>card.disabled=true);
    draft.classList.add('is-selecting');
    try{
      if(!reducedMotion.matches){
        exit=draft.animate([{opacity:1,transform:'none'},{opacity:0,transform:'translateY(-12px) scale(.97)'}],{duration:180,easing:'ease-in',fill:'forwards'});
        draft.classList.add('is-leaving');
        await waitForAnimations([exit]);
      }
      const chosen=G.chooseSkill(id);
      if(chosen){draft.close();$('game').focus({preventScroll:true});}
    }finally{
      exit?.cancel();
      draft.classList.remove('is-selecting','is-leaving');
      cards.forEach(card=>card.disabled=false);selecting=false;
    }
  }
  const icons=()=>lucide.createIcons();
  const rarity=skill=>`<span class="skill-rarity" data-tier="${skill.tier}"><span class="rarity-dot"></span>${G.skillTiers[skill.tier].name}</span>`;
  const chance=skill=>`<span class="skill-chance" title="排除已装备技能后，按权重不重复抽取三个技能；此值为进入三选一的概率">本轮出现率 ${(skill.chance*100).toFixed(2)}%</span>`;
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
         $('draft-rule').textContent=outgoing?`选入新技能后，自动替换最早获得的「${outgoing.name}」，其余 ${G.skillSlots-1} 个技能继续生效。`:`每关选入 1 个技能，跨关保留；满 ${G.skillSlots} 个后，按获得顺序自动替换最早的技能。`;
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
      if(!draft.open&&!window.SlingBreakIntro?.active&&!document.querySelector('dialog[open]'))draft.showModal();
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
