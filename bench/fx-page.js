/* Executed by fx-run.mjs in an isolated Chrome profile, against the full index.html. */
(async () => {
  'use strict';
  const G=window.Game,A=G.__audit,O=window.__FX_OPTIONS__;
  const canvas=document.getElementById('game'),ctx=canvas.getContext('2d');
  const state=window.__FX_BENCH__={done:false,results:[],errors:[],config:{...O,
    userAgent:navigator.userAgent,dpr:devicePixelRatio,canvas:[canvas.width,canvas.height],
    css:[canvas.clientWidth,canvas.clientHeight],stageScale:window.SlingStage.k,
    method:O.raf?'Real rAF + production rendering, without readback; simulation frozen':'Full production render + synchronous 1px readback; simulation frozen; not FPS'}};
  const pct=(a,p)=>a[Math.min(a.length-1,Math.floor(a.length*p))];
  function stats(values){const a=[...values].sort((x,y)=>x-y);return {
    samples:a.length,median:pct(a,.5),p95:pct(a,.95),mean:a.reduce((x,y)=>x+y,0)/a.length,max:a.at(-1)};}
  const yieldFrame=()=>new Promise(resolve=>window.__nativeRAF(resolve));
  const colors=['#785fb0','#53a59b','#d77743','#258eb2','#a99231','#c34d68'];
  const pos=i=>({x:85+(i*97)%610,y:170+(i*71)%580});
  function arrow(i,id){const p=pos(i);return {body:{position:p,velocity:{x:8,y:-16}},
    hit:new Set(),trail:Array.from({length:14},(_,j)=>({x:p.x-j*5,y:p.y+j*9})),skillVisual:id,color:colors[i%6]};}
  function reset(){
    G.time=100;G.phase='ready';G.paused=false;G.reduced=O.reduced;G.state.performanceMode=O.reduced;
    document.documentElement.classList.toggle('performance-mode',O.reduced);
    G.state.skills={};G.state.skillScopeVersion=3;G.arrows=[];G.particles=[];G.rings=[];G.bolts=[];G.texts=[];
    G.core=null;G.shake=0;G.coreFlash=0;G.drag=null;G.pointerPos=null;G.boardEntrance=null;G.holdDraft=false;
    A.skills.effects.length=0;A.skills.cooldowns.clear();A.juice.tallies.length=0;
    A.expansion.reset();A.overdrive.reset();
  }
  function equip(id){G.state.skills={[id]:1};}
  function effects(id,n,hero){equip(id);const p=A.skills.profiles[id];
    for(let i=0;i<n;i++){const q=pos(i);A.skills.effects.push({id,kind:p.kind,...q,r:75,
      born:G.time-p.duration*(.12+(i%7)*.09),duration:p.duration,color:p.color,accent:p.accent,hero});}}
  // Start without startup modals or hidden board, but keep the real HUD and board.
  A.intro?.finish();window.SlingBreakIntro.active=false;
  for(const dialog of document.querySelectorAll('dialog[open]'))HTMLDialogElement.prototype.close.call(dialog);
  document.documentElement.classList.remove('intro-pending','intro-revealing');
  reset();G.ui();
  await document.fonts.ready;
  await yieldFrame();G.resizeCanvas();
  state.config.canvas=[canvas.width,canvas.height];
  // Cold FX tests should not attribute first-time board/text rasterisation to
  // the atlas. Warm that unrelated layer before each case clears only Game.fx.
  if(O.animated){A.render();ctx.getImageData(0,0,1,1);}
  const cases=[];
  const add=(group,id,n,setup,extra={})=>cases.push({group,id,n,setup,...extra});
  add('baseline','board',0,()=>{});
  if(O.animated)for(const id of ['blizzard','snowburst','starforge','mixed'])for(const n of [12,56]){
    let frame=0;
    const c={group:'animation',id,n,setup:()=>{
      G.fx?.clear();frame=0;effects(id==='mixed'?'blizzard':id,n,true);
      if(id==='mixed')A.skills.effects.forEach((e,i)=>{const name=['blizzard','snowburst','starforge','supernova'][i%4],p=A.skills.profiles[name];Object.assign(e,{id:name,kind:p.kind,color:p.color,accent:p.accent,duration:p.duration});});
    },advance:()=>{
      G.time+=1/60;frame++;
      // Cycle every animation pose instead of timing one indefinitely warm
      // sprite. Physics stays frozen; screen-space motion and cache misses don't.
      A.skills.effects.forEach((e,i)=>{e.born=G.time-e.duration*(.05+((frame+i*2)%54)/60);});
    }};cases.push(c);
  }
  for(const [id,p] of Object.entries(A.skills.profiles)){
    for(const n of [1,12,56])add('impact',id,n,()=>effects(id,n,false),{limit:56,trail:p.trail});
    // Keep both sides of the original 24-effect blur cliff for before/after A/B.
    for(const n of [1,12,23,24,56])add('hero',id,n,()=>effects(id,n,true),{limit:56});
    for(const n of [1,12,64])add('trail',id,n,()=>{equip(id);G.arrows=Array.from({length:n},(_,i)=>arrow(i,id));},{limit:64,trail:p.trail});
  }
  for(const [id,kind,r,axis] of [
    ['supernova','nova',650,'both'],['roulette','nova',650,'both'],['pulse','nova',550,'both'],
    ['orbital','mark',160,'both'],['sharpshooter','power',180,'both'],['legion','split',190,'both'],
    ['sweep','beam',75,'row'],['lance','beam',75,'column'],['crossfire','beam',75,'both'],['stormfront','beam',75,'row']
  ])for(const n of [1,12,23])add('variant',id+':'+kind,n,()=>{
    effects(id,n,true);for(const e of A.skills.effects){e.kind=kind;e.r=r;e.axis=axis;}
  },{limit:56});
  for(const n of [1,12,64]){
    add('core','plain-trail',n,()=>{G.arrows=Array.from({length:n},(_,i)=>arrow(i));},{limit:64});
    add('core','overdrive-glow',n,()=>{G.arrows=Array.from({length:n},(_,i)=>({...arrow(i),overdrive:true}));},{limit:64});
    add('core','firewheel',n,()=>{equip('firewheel');G.arrows=Array.from({length:n},(_,i)=>({...arrow(i,'firewheel'),firewheel:{}}));},{limit:64});
  }
  for(const n of [0,100,300,1000,3000,8000])add('core','square-particles',n,()=>{
    G.particles=Array.from({length:n},(_,i)=>({...pos(i),vx:0,vy:0,life:.12+(i%8)*.08,max:1,size:2+i%6,color:colors[i%6],rot:0}));
  },{limit:300,synthetic:n>300});
  for(const n of [1,30,100,300,1000]){
    add('core','rings',n,()=>{for(let i=0;i<n;i++)G.rings.push({...pos(i),color:colors[i%6],r:90+i%4*90,life:.28,max:.55});});
    add('core','bolts',n,()=>{for(let i=0;i<n;i++)G.bolts.push({...pos(i),tx:680-(i*37)%580,ty:170+(i*137)%600,life:.2});});
    add('core','floating-text',n,()=>{for(let i=0;i<n;i++)G.texts.push({...pos(i),text:'+'+(i*137+28),size:17,color:colors[i%6],life:.5});});
  }
  for(const n of [1,8])add('core','income-tallies',n,()=>{
    for(let i=0;i<n;i++)A.juice.tallies.push({...pos(i),life:1,pop:.5,count:12,kills:12,total:13800,callout:{text:'势不可挡',life:.6,tier:3}});
  },{limit:8});
  add('adjacent','aim-glow',1,()=>{G.drag={dx:30,dy:90};});
  add('adjacent','core-cached-glow',1,()=>{G.core={x:390,y:80,born:G.time-3};});
  add('adjacent','core-drifting-glow',1,()=>{G.core={x:390,y:80,born:G.time-3,drifting:true};});
  const expansionSignals=[['wormhole','portal'],['siegebreaker','rubble'],['threadweaver','cut'],['infection','seed'],['infection','root'],['transmute','transform'],['spectral','phase']];
  for(const [id,type] of expansionSignals)for(const n of [1,12,80])add('mechanic',id+':'+type,n,()=>{
    for(let i=0;i<n;i++)A.expansion.signals.push({id,type,from:pos(i),to:pos(i+3),born:G.time-.2,duration:.6});
  },{limit:80});
  for(const id of ['fusepath','reboundaim','overkill','chronicle','worldfold','starforge'])
    for(const n of [1,12,96])add('mechanic',id+':signal',n,()=>{
      for(let i=0;i<n;i++)A.overdrive.signals.push({id,from:pos(i),to:pos(i+3),born:G.time-.2,duration:.6});
    },{limit:96});
  for(const n of [1,6])add('mechanic','buzzsaw:disc',n,()=>{
    for(let i=0;i<n;i++)A.expansion.saws.push({...pos(i),direction:1,born:G.time-.3});
  },{limit:6});
  for(const id of ['teslanet','undertow','worldfold','starforge'])for(const n of [1,8,32])add('mechanic',id+':field',n,()=>{
    for(let i=0;i<n;i++)A.overdrive.fields.push({id,...pos(i),vertices:[pos(i),pos(i+2),pos(i+4)],born:G.time-.35,duration:1.2,stacks:16});
  });
  // Boss particle renderers are private in production; the test server exposes them.
  // These tests call the exact drawer with deterministic, live-age fixtures.
  const bossCases=[];
  const badd=(id,n,setup,draw,extra={})=>bossCases.push({group:'boss-particle',id,n,setup,draw,...extra});
  const eye=A.bosses.eye,forge=A.bosses.forge,clock=A.bosses.clock,serpent=A.bosses.serpent;
  for(const n of [1,4,32])badd('eye:well',n,()=>{for(let i=0;i<n;i++)eye.wells.push({...pos(i),born:G.time-.8,end:G.time+1.8});},()=>eye.wells.forEach(w=>eye.well(ctx,w)),{limit:4,synthetic:n>4});
  for(const n of [1,12,70,300]){
    badd('eye:beam',n,()=>{for(let i=0;i<n;i++)eye.beams.push({ox:390,oy:80,...pos(i),born:G.time-.2,end:G.time+.35});},()=>eye.beams.forEach(b=>eye.beam(ctx,b)));
    badd('eye:shards',n,()=>{for(let i=0;i<n;i++)eye.fragments.push({...pos(i),a:i*.3,s:6+i%12,born:G.time-.4});},()=>eye.shards(ctx));
    badd('clock:shards',n,()=>{for(let i=0;i<n;i++)clock.fragments.push({...pos(i),a:i*.3,s:8+i%16,born:G.time-.4});},()=>clock.shards(ctx));
    for(const k of ['flare','wave','streak'])badd('serpent:'+k,n,()=>{
      for(let i=0;i<n;i++)serpent.fx.push({k,...pos(i),c:'#dfaa65',r:k==='flare'?160:260,w:10,len:240,born:G.time-.2,life:.6,
        rays:Array.from({length:12},(_,j)=>({a:j*Math.PI/6,s:.8}))});
    },()=>serpent.drawFx(ctx));
    badd('forge:embers',n,()=>{for(let i=0;i<n;i++)forge.embers.push({...pos(i),born:G.time-.3});},()=>forge.field(ctx));
    badd('forge:meteors',n,()=>{for(let i=0;i<n;i++)forge.meteors.push({x0:390,y0:80,x1:pos(i).x,y1:pos(i).y,born:G.time-.6,dur:1.25,arc:160,
      trail:arrow(i).trail.slice(0,10)});},()=>forge.field(ctx));
    badd('serpent:dust',n,()=>{for(let i=0;i<n;i++)serpent.dust.push({...pos(i),r:2,born:G.time-.3,life:1.2});},()=>serpent.field(ctx));
    badd('serpent:ghosts',n,()=>{for(let i=0;i<n;i++)serpent.ghosts.push({...pos(i),a:.3,born:G.time-.12,twin:false});},()=>serpent.field(ctx));
    badd('serpent:sparks',n,()=>{for(let i=0;i<n;i++)serpent.sparks.push({...pos(i),trail:arrow(i).trail.slice(0,12)});},()=>serpent.field(ctx));
    badd('serpent:portals',n,()=>{for(let i=0;i<n;i++)serpent.portals.push({...pos(i),exit:true,born:G.time-.6,end:G.time+1.5,open:G.time+.2});},()=>serpent.field(ctx));
    badd('serpent:debris',n,()=>{for(let i=0;i<n;i++)serpent.debris.push({...pos(i),w:84,h:44,type:'normal',spin:2,born:G.time-.2,sn:{head:{x:390,y:470,a:.5}}});},()=>serpent.field(ctx));
    badd('eye:chain-snap',n,()=>{for(let i=0;i<n;i++)eye.snaps.push({...pos(i),born:G.time-.2});},()=>eye.chains(ctx));
  }
  for(const n of [1,2,16])badd('serpent:eye-trails',n,()=>{
    for(let i=0;i<n;i++)serpent.snakes.push({mode:'swim',head:pos(i),eyes:Array.from({length:10},(_,j)=>[
      {x:pos(i).x-j*5,y:pos(i).y+j*9},{x:pos(i).x+15-j*5,y:pos(i).y+j*9}])});
  },()=>serpent.eyeTrails(ctx),{limit:2,synthetic:n>2});
  for(const n of [1,12,64])badd('serpent:eclipse-lights',n,()=>{
    serpent.eclipse();G.arrows=Array.from({length:n},(_,i)=>arrow(i));
  },()=>serpent.drawEclipse(ctx),{limit:64});
  const filter=c=>!O.filter||new RegExp(O.filter).test(c.group+'/'+c.id);
  async function measure(c,isolated=false){
    reset();Object.values(A.bosses).forEach(b=>b.reset());
    await c.setup();
    const paint=isolated?()=>{
      ctx.setTransform(1,0,0,1,0,0);ctx.clearRect(0,0,canvas.width,canvas.height);
      const v=G.view,d=canvas.width/canvas.clientWidth;
      ctx.save();ctx.setTransform(d*v.scale,0,0,d*v.scale,d*v.offsetX,d*v.offsetY);c.draw();ctx.restore();
    }:A.render;
    const draw=()=>{c.advance?.();paint();};
    const flush=()=>ctx.getImageData(0,0,1,1);
    if(O.raf){
      // Warm up asynchronous painting, then observe actual browser frame cadence.
      let warm=performance.now();while(performance.now()-warm<400){await yieldFrame();draw();}
      const times=[],cpu=[],begin=performance.now();
      do{await yieldFrame();const t=performance.now();times.push(t);draw();cpu.push(performance.now()-t);}
      while(performance.now()-begin<O.sample||times.length<12);
      const deltas=times.slice(1).map((t,i)=>t-times[i]);
      const {setup,draw:unused,...meta}=c;
      state.results.push({...meta,isolated,frameMs:stats(deltas),submitMs:stats(cpu),fps:1000/stats(deltas).mean});
      return;
    }
    const coldStart=performance.now();draw();flush();const firstDrawMs=performance.now()-coldStart;
    for(let i=0;i<2;i++){draw();flush();}
    const costs=[],submit=[],start=performance.now();
    do{const t=performance.now();draw();const d=performance.now();flush();costs.push(performance.now()-t);submit.push(d-t);}
    while((performance.now()-start<O.sample||costs.length<12)&&costs.length<240);
    const {setup,draw:unused,...meta}=c;
    const row={...meta,isolated,firstDrawMs,costMs:stats(costs),submitMs:stats(submit),cache:G.fx?.stats()};
    if(O.capture){(state.captures||=[]).push({name:`${c.group}-${c.id.replace(/[^\w-]/g,'-')}-${c.n}`,data:canvas.toDataURL('image/png')});}
    if(c.group==='core'&&['square-particles','rings','bolts','floating-text'].includes(c.id)||c.group==='baseline'&&c.id==='board'){
      // Separate update microbenchmark; all objects held alive, no drawing.
      for(const list of [G.particles,G.rings,G.bolts,G.texts])for(const p of list)p.life=1e9;
      const ticks=[];
      for(let batch=0;batch<12;batch++){
        const t=performance.now();for(let j=0;j<100;j++)G.tick(1/60);
        if(batch>=2)ticks.push((performance.now()-t)/100);
      }
      row.updateMs=stats(ticks);
    }
    state.results.push(row);
    if(state.results.length%40===0)console.log('[fx] measured',state.results.length,c.group,c.id,c.n);
    await yieldFrame();
  }
  try{
    // Forge's field renderer also draws its always-on heart; supply a valid fight.
    G.state.milestone={v:3,boss:'forge',level:100,phase:3,intro:true,hp:100,max:100,data:{heat:60},abilities:[[],[],[]]};
    // Keep normal cases on level 1, avoiding boss composition in full renders.
    G.state.level=1;
    for(const c of cases.filter(filter))try{await measure(c);}catch(e){state.errors.push({id:c.id,n:c.n,error:String(e.stack)});}
    G.state.level=100;
    for(const c of bossCases.filter(filter))try{await measure(c,true);}catch(e){state.errors.push({id:c.id,n:c.n,error:String(e.stack)});}
    // Isolated empty-canvas baseline for boss renderer comparisons.
    await measure({group:'baseline',id:'empty-canvas',n:0,setup:()=>{},draw:()=>{}},true);
    // Boss scenes use production board generation and move starters, not invented draws.
    for(const [id,def] of Object.entries(G.bossDefs)){
      const moves=def.start?['idle',...Object.keys(def.abilities)]:['idle'];
      for(const move of moves){
        const c={group:'boss-scene',id:id+':'+move,n:1,setup:()=>{
          G.state.level=100;G.state.bossOverride={level:100,boss:id};G.state.milestone=null;G.generate(false);
          const m=G.boss();m.phase=def.phases||3;m.intro=true;m.abilities=Array.from({length:def.phases||3},()=>Object.keys(def.abilities));
          G.generate(false);G.phase='ready';G.time=100;G.boardEntrance=null;
          if(move==='rewind')for(const b of G.bricks.filter(b=>b.type==='normal').slice(0,3)){def.destroyed(b,0);G.bossApi.removeBrick(b);}
          if(move!=='idle'){if(!def.start(move))throw Error('Move refused: '+id+':'+move);G.time+=1.6;}
          c.snapshot=def.debug?.();
        }};
        if(filter(c))try{await measure(c);}catch(e){state.errors.push({id:c.id,error:String(e.stack)});}
        if(O.animated&&id==='serpent'&&move==='idle'){
          const atmosphere={group:'animation',id:'serpent:atmosphere',n:1,setup:()=>{c.setup();G.fx?.clear();},
            advance:()=>{G.time+=1/60;},draw:()=>serpent.back(ctx)};
          if(filter(atmosphere))try{await measure(atmosphere,true);}catch(e){state.errors.push({id:atmosphere.id,error:String(e.stack)});}
        }
        if(move==='idle')for(const layer of ['back','field','front']){
          const part={group:'boss-layer',id:id+':'+layer,n:1,setup:c.setup,draw:()=>A.bosses[id][layer](ctx)};
          if(filter(part))try{await measure(part,true);}catch(e){state.errors.push({id:part.id,error:String(e.stack)});}
        }
        if(id==='serpent'&&move==='idle'){
          const live={group:'boss-scene',id:'serpent:live-body',n:1,setup:async()=>{
            c.setup();
            // Real hit-stop uses wall time: yield so a fast CPU loop cannot freeze
            // every subsequent tick and mislabel an emerge snapshot as a live body.
            for(let i=0;i<720;i++){await yieldFrame();G.tick(1/60);}
            G.boardEntrance=null;
            live.snapshot=def.debug?.();
            if(!live.snapshot.snakes.some(s=>s.live>0))throw Error('Serpent body did not emerge during fixture warmup');
          }};
          if(filter(live))try{await measure(live);}catch(e){state.errors.push({id:live.id,error:String(e.stack)});}
        }
      }
    }
    // Intro has a fixed 15 × 4 fragments; repetitions are explicitly synthetic.
    if(A.intro&&(!O.filter||new RegExp(O.filter).test('intro/fragments'))){
      const ic=document.getElementById('intro-canvas'),it=ic.getContext('2d');
      for(const n of [1,4,16]){
        const costs=[];
        for(let i=0;i<20;i++){const t=performance.now();for(let j=0;j<n;j++)A.intro.paint();it.getImageData(0,0,1,1);costs.push(performance.now()-t);}
        state.results.push({group:'intro',id:'fragments',n,fragments:n*60,synthetic:n>1,isolated:true,costMs:stats(costs)});
      }
    }
    state.coverage={profiles:Object.keys(A.skills.profiles).length,catalog:G.skillCatalog.length,
      missingProfiles:G.skillCatalog.filter(s=>!A.skills.profiles[s.id]).map(s=>s.id),cases:state.results.length};
    if(O.dom){
      G.state.level=1;G.state.bossOverride=null;G.state.milestone=null;G.generate(false);reset();G.ui();
      for(const kind of ['baseline','coins','sparks','payout'])for(const n of kind==='baseline'?[0]:[1,4,16]){
        const spawn=()=>{
          if(kind==='coins')for(let i=0;i<n;i++)A.transitions.flyCoins(100000);
          if(kind==='sparks')for(let i=0;i<n*6;i++)A.achievement.launchSpark({x:200,y:600},'#ccaa55',{});
          if(kind==='payout')for(let i=0;i<n;i++)A.achievement.flyPayout(1000);
        };
        const t=performance.now();spawn();const spawnMs=performance.now()-t;
        const selector='.flying-coin,.achievement-spark,.achievement-payout-chip';
        const actual=document.querySelectorAll(selector).length;
        const times=[],start=performance.now();
        do{await yieldFrame();times.push(performance.now());A.render();}while(performance.now()-start<Math.max(900,O.sample));
        const deltas=times.slice(1).map((t,i)=>t-times[i]);
        state.results.push({group:'dom',id:kind,n,actualNodes:actual,synthetic:n>1,spawnMs,frameMs:stats(deltas),fps:1000/stats(deltas).mean});
        for(const el of document.querySelectorAll(selector)){el.getAnimations().forEach(a=>a.cancel());el.remove();}
        await yieldFrame();
      }
    }
    state.coverage.cases=state.results.length;
  }catch(e){state.errors.push({error:String(e.stack)});}
  state.done=true;
  console.log('[fx] done',state.results.length,'cases;',state.errors.length,'errors');
})();
