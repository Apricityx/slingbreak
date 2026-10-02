const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const Matter=require('./vendor/matter.min.js');
const source=fs.readFileSync(__dirname+'/game.js','utf8');
function boot(saved,{systemReduced=true}={}){
  let storage=saved?JSON.stringify(saved):null;
  let onMotionChange;
  const motion={matches:systemReduced,addEventListener:(type,fn)=>{onMotionChange=fn;}};
  const classes=new Set();
  const context={Matter,console,window:{},URLSearchParams,location:{search:''},matchMedia:()=>motion,localStorage:{getItem:()=>storage,setItem:(k,v)=>storage=v},document:{documentElement:{classList:{toggle:(name,on)=>on?classes.add(name):classes.delete(name)}},getElementById:()=>({})}};
  vm.createContext(context);vm.runInContext(source,context);
  return {G:context.window.Game,read:()=>JSON.parse(storage),setSystemReduced:on=>{motion.matches=on;onMotionChange();},hasPerformanceClass:()=>classes.has('performance-mode')};
}
test('performance mode follows the saved checkbox and system motion preference independently',()=>{
  const session=boot(undefined,{systemReduced:false}),{G}=session;
  assert.equal(G.state.performanceMode,false);assert.equal(G.reduced,false);assert.equal(session.hasPerformanceClass(),false);
  G.setPerformanceMode(true);
  assert.equal(G.reduced,true);assert.equal(session.hasPerformanceClass(),true);assert.equal(session.read().performanceMode,true);
  G.reset();assert.equal(G.state.performanceMode,true);
  const reloaded=boot(session.read(),{systemReduced:false});
  assert.equal(reloaded.G.reduced,true);assert.equal(reloaded.hasPerformanceClass(),true);
  reloaded.setSystemReduced(true);
  reloaded.G.setPerformanceMode(false);
  assert.equal(reloaded.G.reduced,true);assert.equal(reloaded.hasPerformanceClass(),false);
  reloaded.setSystemReduced(false);assert.equal(reloaded.G.reduced,false);
  assert.equal(boot({...session.read(),performanceMode:'true'},{systemReduced:false}).G.state.performanceMode,false);
  assert.equal(boot({...session.read(),performanceMode:undefined},{systemReduced:false}).G.state.performanceMode,false);
});
test('visual shockwaves merge nearby impacts, remain bounded and preserve major pulses',()=>{
  const {G}=boot(undefined,{systemReduced:false});G.rings=[];
  G.ring(100,100,'#ffaa33',90);G.ring(105,105,'#ffaa33',95);
  assert.equal(G.rings.length,1);assert.ok(G.rings[0].energy>1);
  G.ring(100,100,'#ffaa33',600);G.ring(100,100,'#ffaa33',600);
  assert.equal(G.rings.filter(r=>r.r===600).length,2);
  for(let i=0;i<300;i++)G.ring(i*40,100,'#ffaa33');
  assert.equal(G.rings.length,48);assert.equal(G.rings.filter(r=>r.r===600).length,2);
  G.reduced=true;G.rings=[];for(let i=0;i<100;i++)G.ring(i*40,100,'#ffaa33');assert.equal(G.rings.length,24);
});
test('visual text and arc budgets never change awarded money or scoring state',()=>{
  const {G}=boot();const coins=G.state.coins,total=G.state.total;
  for(let i=0;i<300;i++){G.float(i,i,'+'+i);G.bolts.push({x:i,y:i,tx:0,ty:0,life:1});}
  assert.equal(G.texts.length,48);G.tick(1/60);assert.ok(G.bolts.length<=64);
  assert.equal(G.state.coins,coins);assert.equal(G.state.total,total);
});
test('destruction coalesces HUD requests but damage, income and core unlock stay synchronous',()=>{
  const {G}=boot();G.bricks.forEach(b=>b.type='normal');let paints=0;G.ui=()=>paints++;
  const before=G.state.coins,count=G.bricks.length;
  for(const b of [...G.bricks])G.hit(b,1e9);
  assert.equal(G.bricks.length,0);assert.equal(G.killed,count);assert.equal(G.state.total,count);
  assert.ok(G.state.coins>before);assert.ok(G.core);assert.equal(paints,0);
  G.flushUi();assert.equal(paints,1);G.flushUi();assert.equal(paints,1);
  G.requestUi();G.requestUi();G.flushUi();assert.equal(paints,2);
});
test('frame visuals merge by identity, do not merge different feedback, and reset drops stale work',()=>{
  const {G}=boot();const painted=[];
  G.deferVisual('combo',()=>painted.push('old'));G.deferVisual('boss',()=>painted.push('boss'));
  G.deferVisual('combo',()=>{painted.push('latest');G.deferVisual('next',()=>painted.push('next'));});
  G.flushVisuals();assert.deepEqual(painted,['latest','boss']);G.flushVisuals();assert.deepEqual(painted,['latest','boss','next']);
  G.deferVisual('old-board',()=>painted.push('stale'));G.generate();G.flushVisuals();assert.equal(painted.includes('stale'),false);
});
test('nearest and radius queries preserve full-sort order, ties, strict boundaries and moving bricks',()=>{
  const {G}=boot();G.bricks=[{x:3,y:4},{x:-3,y:4},{x:0,y:0},{x:30,y:40},{x:5,y:0}];
  for(const [x,y] of [[0,0],[7,12],[-100,5]])for(const n of [0,1,3,8]){
    const filter=b=>b.x>=0;
    for(const accept of [undefined,filter]){
      const expected=G.bricks.filter(b=>!accept||accept(b)).sort((a,b)=>Math.hypot(a.x-x,a.y-y)-Math.hypot(b.x-x,b.y-y)).slice(0,n);
      assert.deepEqual([...G.nearestBricks(x,y,n,accept)],expected);
    }
    for(const inclusive of [false,true])for(const r of [0,5,50,150])assert.deepEqual([...G.bricksNear(x,y,r,inclusive)],
      G.bricks.filter(b=>inclusive?Math.hypot(b.x-x,b.y-y)<=r:Math.hypot(b.x-x,b.y-y)<r));
  }
  G.bricks[3].x=0;G.bricks[3].y=0;assert.equal(G.nearestBricks(0,0,2)[1],G.bricks[3]);
});
test('cached number formatting is exactly the previous en-US output at every abbreviation boundary',()=>{
  const {G}=boot();
  for(const n of [-1234.5,0,3.8,999.9,1000,9999.9,10000,999999,1000000,999999999,1000000000]){
    assert.equal(G.fmtInteger(n),Math.floor(n).toLocaleString('en-US'));
    assert.equal(G.fmt(n),n>=1e9?(n/1e9).toFixed(1)+'B':n>=1e6?(n/1e6).toFixed(1)+'M':n>=10000?(n/1000).toFixed(1)+'k':Math.floor(n).toLocaleString('en-US'));
  }
});
test('reused fragments retain the previous random sequence, capacity, ordering and visual values',()=>{
  const {G}=boot(undefined,{systemReduced:false});let seed=123;
  const rng=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const expected=[];const operations=[[16,1],[80,3],[800,1],[0,1],[12,.55]];
  const context={Matter,window:{},console,URLSearchParams,location:{search:''},Math:Object.create(Math),
    matchMedia:()=>({matches:false,addEventListener(){}}),localStorage:{getItem:()=>null,setItem(){}},
    document:{documentElement:{classList:{toggle(){}}},getElementById:()=>({})}};
  vm.createContext(context);vm.runInContext(source,context);const live=context.window.Game;live.particles=[];
  for(const reduced of [false,true]){
    live.reduced=reduced;live.particles=[];expected.length=0;
    for(const [count,force] of operations){
      seed=123;const n=reduced?Math.min(count,5):Math.ceil(count*.55);
      for(let i=0;i<n;i++){const a=rng()*Math.PI*2,v=(1+rng()*5)*force;expected.push({x:10,y:20,vx:Math.cos(a)*v,vy:Math.sin(a)*v-1,life:.5+rng()*.4,max:1,size:2+rng()*5,color:'#ffeecc',rot:rng()*6});}
      if(expected.length>300)expected.splice(0,expected.length-300);const next=rng();
      seed=123;context.Math.random=rng;live.burst(10,20,'#ffeecc',count,force);
      assert.equal(rng(),next);assert.equal(JSON.stringify(live.particles),JSON.stringify(expected));
    }
  }
  assert.ok(G.fmt);
});
test('volume defaults, migrates and survives save and game reset',()=>{
  const {G,read}=boot();assert.equal(G.state.volume,100);
  G.state.volume=0;G.state.sound=false;G.save();
  const loaded=boot(read()).G;assert.equal(loaded.state.volume,0);assert.equal(loaded.state.sound,false);
  loaded.reset();assert.equal(loaded.state.volume,0);assert.equal(loaded.state.sound,false);
  assert.equal(boot(read()).G.state.volume,0);
  const legacy={...read(),volume:undefined,sound:false,soundMigrated:true};
  assert.equal(boot(legacy).G.state.volume,0);
  assert.equal(boot({...legacy,soundMigrated:false}).G.state.volume,100);
  assert.equal(boot({...legacy,volume:1000}).G.state.volume,0);
});
test('prediction matches every live physics step through obstacle and wall ricochets',()=>{
  for(const [x,y,vx,vy] of [[390,970,-18,-16],[30,600,-23,-8],[750,40,20,-18],[390,36,3,-24],[300,540,22,0],[390,650,4,-25]]){
    const {G}=boot();Matter.Composite.clear(G.engine.world);G.bricks=[];G.obstacles=[];
    const body=Matter.Bodies.rectangle(390,540,84,44,{isStatic:true,label:'obstacle'});
    const obstacle={x:390,y:540,w:84,h:44,body,flash:0};body.obstacle=obstacle;G.obstacles.push(obstacle);Matter.Composite.add(G.engine.world,body);
    const worldBefore=G.engine.world.bodies.length,timeBefore=G.time;
    const path=G.predictPath(x,y,vx,vy,1800);
    assert.equal(G.engine.world.bodies.length,worldBefore);assert.equal(G.time,timeBefore);assert.equal(obstacle.flash,0);
    G.phase='flying';const arrow=G.addArrow(x,y,vx,vy);let bounces=0;G.onRicochet=()=>bounces++;
    for(const p of path.slice(1)){
      G.tick(G.physicsStep);
      assert.ok(Math.hypot(p.x-arrow.body.position.x,p.y-arrow.body.position.y)<1e-8,'predicted and live positions must match after every bounce');
    }
    assert.ok(bounces>0,'scenario must exercise a ricochet');
  }
});
test('60Hz WebView mode keeps prediction and live physics aligned',()=>{
  const {G}=boot();G.physicsStep=1/60;Matter.Composite.clear(G.engine.world);G.bricks=[];G.obstacles=[];
  const body=Matter.Bodies.rectangle(390,540,84,44,{isStatic:true,label:'obstacle'});
  const obstacle={x:390,y:540,w:84,h:44,body,flash:0};body.obstacle=obstacle;G.obstacles.push(obstacle);Matter.Composite.add(G.engine.world,body);
  const path=G.predictPath(390,970,-18,-16,1800);G.phase='flying';const arrow=G.addArrow(390,970,-18,-16);G.onRicochet=()=>{};
  for(const p of path.slice(1)){G.tick(G.physicsStep);assert.ok(Math.hypot(p.x-arrow.body.position.x,p.y-arrow.body.position.y)<1e-8);}
});
test('random levels retain all five specials, correct threshold, and no practical level cap',()=>{
  const {G}=boot();
   for(const level of [1,2,10,100,10000]){G.state.level=level;G.generate();assert.ok(G.bricks.length>=55);assert.ok(G.bricks.length<=68);assert.ok(G.bricks.every(b=>b.w===84&&b.h===44));assert.equal(G.threshold,Math.ceil(G.initial*.6));for(const kind of ['bomb','lightning','frost','prism','gold'])assert.ok(G.bricks.some(b=>b.type===kind));assert.ok(Number.isFinite(G.bonus()));}
});
test('coins scale with level and a linear per-arrow combo capped at threefold',()=>{
  const {G}=boot();const base=G.reward('normal',1);assert.equal(G.mult(1),1);assert.equal(G.mult(2),1.25);assert.equal(G.mult(5),2);assert.equal(G.mult(9),3);assert.equal(G.mult(10000),3);assert.ok(G.reward('normal',5)>base);assert.ok(G.reward('normal',15)>G.reward('normal',5));G.state.level=10;assert.ok(G.reward('normal',1)>base);assert.equal(G.reward('gold',1),Math.round(3*Math.pow(10,1.1)*3));
});
test('core threshold unlocks, cleanup pays only its bonus, and cannot pay twice',()=>{
  const {G}=boot();G.bricks.forEach(b=>b.type='normal');
  for(let i=0;i<G.threshold;i++)G.hit(G.bricks[0],999);
  assert.ok(G.core);const before=G.state.coins,total=G.state.total,roundKills=G.roundKills,best=G.state.best,bonus=G.bonus(),level=G.state.level;
  G.clear();assert.equal(G.state.coins,before+bonus);assert.equal(G.state.total,total);assert.equal(G.roundKills,roundKills);assert.equal(G.state.best,best);assert.equal(G.bricks.length,0);assert.equal(G.state.level,level+1);G.clear();assert.equal(G.state.coins,before+bonus);
  assert.equal(G.obstacles.length,0);
});
test('upgrades are affordable-only and unavailable mid-shot',()=>{
  const {G}=boot();assert.equal(G.buy('arrow'),false);G.state.coins=1000;const price=G.cost('arrow');assert.equal(G.buy('arrow'),true);assert.equal(G.state.coins,1000-price);assert.equal(G.state.up.arrow,1);assert.ok(G.damage()>1);G.shoot(0,100);assert.equal(G.buy('power'),false);
});
test('combo upgrades unlock at brick tier five and raise both the step and cap',()=>{
  const {G,read}=boot();const oldSave=read();assert.equal(oldSave.up.comboCap,0);assert.equal(G.comboMultiplierCap(),3);assert.equal(G.comboStep(),.25);assert.equal(G.comboCapKills(),9);
  G.state.coins=Number.MAX_SAFE_INTEGER;assert.equal(G.buy('comboCap'),false);G.state.up.brick=4;assert.equal(G.buy('comboCap'),false);
  G.state.up.brick=5;assert.equal(G.cost('comboCap'),1500);assert.equal(G.cost('brick'),Math.ceil(120*1.5**5));
  assert.equal(G.buy('comboCap'),true);assert.equal(G.comboMultiplierCap(),3.5);assert.equal(G.comboStep(),.275);assert.equal(G.comboCapKills(),11);assert.equal(G.mult(10000),3.5);assert.equal(G.state.up.comboCap,1);
  assert.equal(G.cost('comboCap'),2475);const loaded=boot(read()).G;assert.equal(loaded.state.up.comboCap,1);assert.equal(loaded.comboMultiplierCap(),3.5);assert.equal(loaded.comboStep(),.275);
});
test('skill slots are bought one at a time for 100K, 10M then 1B',()=>{
  const {G,read}=boot();assert.equal(G.skillSlotBought(),0);assert.equal(G.skillSlotMax,4);assert.equal(G.skillSlotUpgrades,3);
  assert.equal(G.skillSlotCost(0),1e5);assert.equal(G.skillSlotCost(1),1e7);assert.equal(G.skillSlotCost(2),1e9);
  G.state.coins=99999;assert.equal(G.cost('slots'),1e5);assert.equal(G.buy('slots'),false);assert.equal(G.skillSlotBought(),0);
  G.state.coins=1e5;assert.equal(G.buy('slots'),true);assert.equal(G.skillSlotBought(),1);assert.equal(G.state.up.slots,1);assert.equal(G.state.coins,0);
  assert.equal(G.cost('slots'),1e7);assert.equal(G.buy('slots'),false);
  G.state.coins=1e7;assert.equal(G.buy('slots'),true);assert.equal(G.skillSlotBought(),2);assert.equal(G.state.coins,0);
  assert.equal(G.cost('slots'),1e9);
  G.state.coins=1e9;assert.equal(G.buy('slots'),true);assert.equal(G.skillSlotBought(),3);assert.equal(G.state.coins,0);
  // Maxed out: no further purchase even with plenty of coins.
  G.state.coins=1e12;assert.equal(G.buy('slots'),false);assert.equal(G.skillSlotBought(),3);assert.equal(G.state.up.slots,3);
  const loaded=boot(read()).G;assert.equal(loaded.skillSlotBought(),3);assert.equal(loaded.state.up.slots,3);
});
test('legacy saves without a slots key start at zero bought upgrades',()=>{
  const {G}=boot({level:12,coins:50,total:0,best:0,comboRulesVersion:2,up:{power:0,arrow:0,brick:0,comboCap:0}});
  assert.equal(G.state.up.slots,0);assert.equal(G.skillSlotBought(),0);
});
test('fixed world keeps the sling beneath the lowest brick row with clear separation',()=>{
   const {G}=boot();assert.equal(G.H,1400);assert.equal(G.origin.y,970);
  const lowestRow=Math.max(...G.bricks.map(b=>b.y));
  assert.ok(G.origin.y-(lowestRow+14)>=20,'sling ring should clear the lowest brick row');
  G.bricks.forEach(b=>{b.type='normal';b.hp=1;});
  assert.equal(G.shoot(0,100),true);for(let i=0;i<700;i++)G.tick(1/120);
  assert.ok(G.killed>0,'arrow should hit bricks');assert.equal(G.phase,'ready');assert.equal(G.arrows.length,0);
});
test('board damage, core state, upgrades, and wallet survive reload',()=>{
  const {G,read}=boot();G.state.coins=500;G.buy('brick');G.bricks.forEach(b=>b.type='normal');for(let i=0;i<G.threshold;i++)G.hit(G.bricks[0],999);G.save();
  const loaded=boot(read()).G;assert.equal(loaded.bricks.length,G.bricks.length);assert.equal(loaded.killed,G.killed);assert.equal(loaded.state.coins,G.state.coins);assert.equal(loaded.state.up.brick,1);assert.ok(loaded.core);
  assert.equal(JSON.stringify(loaded.obstacles.map(o=>[o.x,o.y,o.w,o.h])),JSON.stringify(G.obstacles.map(o=>[o.x,o.y,o.w,o.h])));
});
test('barriers stay separated, avoid bricks and leave the core route open',()=>{
  const {G}=boot();
  for(let i=0;i<35;i++){
    G.state.level=i+1;G.generate();assert.ok(G.obstacles.length>=5&&G.obstacles.length<=8);
    assert.equal(G.initial,G.bricks.length);
    for(const o of G.obstacles){
      assert.ok(Math.abs(o.x-390)-o.w/2>=80);assert.ok(o.y+o.h/2<G.origin.y-130);
      assert.ok(G.bricks.every(b=>Math.abs(b.x-o.x)>=(b.w+o.w)/2||Math.abs(b.y-o.y)>=(b.h+o.h)/2));
      assert.ok(G.obstacles.every(other=>other===o||Math.hypot(other.x-o.x,other.y-o.y)>=104));
    }
  }
});
test('barriers reflect both faces, do not consume penetration or award coins, and survive repeated hits',()=>{
  for(const horizontal of [false,true]){
    const {G}=boot();G.bricks.forEach(b=>Matter.Composite.remove(G.engine.world,b.body));G.bricks=[];
    const o=G.obstacles[0],count=G.obstacles.length;
    for(let repeat=0;repeat<2;repeat++){
      G.phase='flying';G.addArrow(o.x+(horizontal?-o.w/2-12:0),o.y+(horizontal?0:o.h/2+12),horizontal?24:0,horizontal?0:-24);
      const arrow=G.arrows.at(-1);for(let i=0;i<4;i++)G.tick(1/120);
      assert.ok(horizontal?arrow.body.velocity.x<0:arrow.body.velocity.y>0,JSON.stringify({horizontal,repeat,obstacle:{x:o.x,y:o.y},position:arrow.body.position,velocity:arrow.body.velocity}));
      assert.equal(arrow.pierce,G.penetration());assert.equal(G.obstacles.length,count);
      assert.equal(G.state.coins,0);assert.equal(G.killed,0);assert.equal(G.arrowKills(arrow),0);
      G.arrows.forEach(a=>Matter.Composite.remove(G.engine.world,a.body));G.arrows=[];
    }
  }
});
test('explosions and other specials never destroy or reward barriers',()=>{
  for(const type of ['bomb','lightning','frost','prism']){
    const {G}=boot();const original=G.obstacles.map(o=>o.body.id);G.bricks.forEach(b=>b.type='normal');
    const o=G.obstacles[0],b=G.bricks.reduce((a,b)=>Math.hypot(b.x-o.x,b.y-o.y)<Math.hypot(a.x-o.x,a.y-o.y)?b:a);b.type=type;G.hit(b,999);
    assert.deepEqual(G.obstacles.map(o=>o.body.id),original);assert.equal(G.killed,G.initial-G.bricks.length);
  }
});
test('old in-progress saves retain progress; untouched boards adopt the portrait layout',()=>{
  const {G,read}=boot();G.bricks.forEach(b=>b.type='normal');G.hit(G.bricks[0],999);G.save();
   const saved=read();delete saved.board.obstacles;delete saved.board.balanceVersion;delete saved.board.layoutVersion;
   const loaded=boot(saved).G;assert.equal(loaded.killed,1);assert.equal(loaded.state.coins,G.state.coins);assert.equal(loaded.bricks.length,G.bricks.length);
   saved.board.killed=0;const upgraded=boot(saved).G;assert.ok(upgraded.bricks.length>=55);assert.ok(upgraded.obstacles.length>=5);assert.ok(upgraded.bricks.every(b=>b.w===84&&b.h===44));
});
test('clearing reload advances exactly once and pause freezes time',()=>{
  const {G,read}=boot();G.spawnCore();const bonus=G.bonus();G.clear();const loaded=boot(read()).G;assert.equal(loaded.state.level,2);assert.equal(loaded.state.coins,bonus);assert.ok(loaded.bricks.length>0);const t=loaded.time;loaded.paused=true;loaded.tick(2);assert.equal(loaded.time,t);
});
test('special effects apply meaningful state changes',()=>{
  for(const type of ['bomb','lightning','frost','prism']){
    const {G}=boot();G.bricks.forEach(b=>{b.type='normal';b.hp=b.max=(type==='frost'?100:1);});const target=G.bricks.find(b=>G.bricks.some(t=>t!==b&&Math.hypot(t.x-b.x,t.y-b.y)<78));assert.ok(target);target.type=type;G.hit(target,999);
    if(type==='bomb'||type==='lightning')assert.ok(G.killed>1);
    if(type==='frost')assert.ok(G.bricks.some(b=>b.frozen&&b.hp<b.max));
    if(type==='prism'){assert.equal(G.arrows.length,3);assert.ok(G.arrows.every(a=>a.pierce===2));}
  }
});
test('special quotas include guaranteed types and never exceed 22 percent at any upgrade tier',()=>{
  const {G}=boot();let previous=0;
  for(const tier of [0,1,5,10,20,50,100,1000]){
    G.state.up.brick=tier;const rate=G.specialRate();assert.ok(rate>=previous&&rate<=.22);previous=rate;
    if(tier===0)assert.equal(rate,.1);
    for(let sample=0;sample<8;sample++){
      G.state.level=sample+1;G.generate();const special=G.bricks.filter(b=>b.type!=='normal');
      assert.equal(special.length,Math.floor(G.initial*rate));assert.ok(special.length/G.initial<=.22);
      for(const type of ['bomb','lightning','frost','prism','gold'])assert.ok(special.some(b=>b.type===type));
    }
  }
});
test('penetration grows once per four upgrades, caps at six, and damage still progresses',()=>{
  const {G}=boot();
  for(const [tier,pierce] of [[0,2],[3,2],[4,3],[8,4],[12,5],[16,6],[50,6]]){
    G.state.up.arrow=tier;assert.equal(G.penetration(),pierce);assert.equal(G.damage(),2+.65*Math.log2(tier+1));
  }
});
test('frost bricks are pass-through and do not consume arrow penetration',()=>{
  const {G}=boot();
  const frost=G.bricks[0];frost.type='frost';
  const normal=G.bricks[1];normal.type='normal';
  assert.equal(G.pierceCost(frost.body),0);assert.equal(G.pierceCost(normal.body),1);
  const arrow={pierce:2};arrow.pierce-=G.pierceCost(frost.body);assert.equal(arrow.pierce,2);
  arrow.pierce-=G.pierceCost(normal.body);assert.equal(arrow.pierce,1);
});
test('a two-pierce arrow destroys a frost brick plus two aligned normal bricks',()=>{
  const {G}=boot();
  G.bricks.slice(3).forEach(b=>Matter.Composite.remove(G.engine.world,b.body));G.bricks=G.bricks.slice(0,3);
  G.bricks.forEach((b,i)=>{Matter.Body.setPosition(b.body,{x:390,y:500-i*46});b.x=390;b.y=500-i*46;b.hp=b.max=1;b.type=i===0?'frost':'normal';});
  G.initial=G.bricks.length;G.threshold=99;G.shoot(0,100);const arrow=G.arrows[0];
  for(let i=0;i<700&&G.phase==='flying';i++)G.tick(1/120);
  assert.equal(G.killed,3);assert.equal(G.arrowKills(arrow),3);assert.equal(G.state.best,3);assert.equal(G.arrows.length,0);
});
test('an arrow can hit the same brick again after leaving it',()=>{
  const {G}=boot();const {Bodies,Composite}=Matter;
  G.engine.gravity.y=0;G.bricks.forEach(b=>Composite.remove(G.engine.world,b.body));G.bricks=[];
  G.obstacles.forEach(o=>Composite.remove(G.engine.world,o.body));G.obstacles=[];
  const body=Bodies.rectangle(390,500,84,44,{isStatic:true,label:'brick'});
  const b={x:390,y:500,w:84,h:44,hp:100,max:100,type:'normal',frozen:false,body,flash:0,id:Math.random()};
  body.brick=b;G.bricks.push(b);Composite.add(G.engine.world,body);
  G.phase='flying';G.addArrow(300,500,24,0,20);
  for(let i=0;i<240&&G.arrows.length;i++)G.tick(1/120);
  assert.equal((100-b.hp)/2,3);
});
test('plain arrows stop after exactly two brick contacts at the initial tier',()=>{
  const {G}=boot();G.bricks.forEach(b=>{b.type='normal';b.hp=1;});G.shoot(0,100);const arrow=G.arrows[0];
  for(let i=0;i<600&&G.phase==='flying';i++)G.tick(1/120);
  assert.equal(G.killed,2);assert.equal(G.arrowKills(arrow),2);assert.equal(G.state.best,2);assert.equal(G.arrows.length,0);
});
test('portrait boards reload without rerolling',()=>{
  const {G,read}=boot();G.state.level=20;G.generate();const original=JSON.stringify(read().board);
   assert.ok(G.initial>=62);const loaded=boot(read());assert.equal(JSON.stringify(loaded.read().board),original);
});
test('legacy special-heavy boards are capped while preserving damage, currency and progress',()=>{
  const {G,read}=boot();G.state.coins=321;G.killed=1;G.bricks[0].hp=.5;G.bricks.forEach(b=>b.type='bomb');G.save();
  const saved=read();delete saved.board.balanceVersion;const loaded=boot(saved).G;
   assert.equal(loaded.state.coins,321);assert.equal(loaded.killed,1);assert.ok(loaded.bricks.every(b=>b.w===84&&b.h===44));
  assert.equal(loaded.bricks.filter(b=>b.type!=='normal').length,Math.floor(loaded.initial*loaded.specialRate()));
});
test('all special destructions and core trigger dedicated priority audio, never on a nonlethal hit',()=>{
  for(const [type,cue] of [['bomb','boom'],['lightning','lightning'],['frost','frost'],['prism','prism'],['gold','gold']]){
    const {G}=boot(),events=[];G.bricks.forEach(b=>b.type='normal');const b=G.bricks[0];b.type=type;b.hp=b.max=10;G.sound=(...args)=>events.push(args);
    G.hit(b,1);assert.ok(!events.some(e=>e[3]));G.hit(b,100,100);assert.equal(events.filter(e=>e[0]===cue&&e[2]===b.x&&e[3]===true).length,1);G.hit(b,100);assert.equal(events.filter(e=>e[0]===cue&&e[3]===true).length,1);
  }
  const {G}=boot(),events=[];G.sound=(...args)=>events.push(args);G.clear();assert.equal(events.filter(e=>e[0]==='win'&&e[3]===true).length,1);
});
