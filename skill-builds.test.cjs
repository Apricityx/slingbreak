const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const Matter=require('./vendor/matter.min.js');
const files=['game.js','skills.js','achievements.js','skill-expansion.js','skill-overdrive.js'];

function boot(ids=[]){
  let stored=JSON.stringify({level:1,coins:0,total:0,best:0,comboRulesVersion:2,up:{power:0,arrow:0,brick:0,comboCap:0,slots:3},skills:Object.fromEntries(ids.map(id=>[id,1])),skillScopeVersion:3,skillChosenLevel:ids.length?1:0,skillGateVersion:1}),seed=8241;
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const context={Matter,Math:math,console,window:{},URLSearchParams,location:{search:''},matchMedia:()=>({matches:true}),localStorage:{getItem:()=>stored,setItem:(key,value)=>stored=value},document:{getElementById:()=>({})}};
  vm.createContext(context);for(const file of files)vm.runInContext(fs.readFileSync(__dirname+'/'+file,'utf8'),context);
  const G=context.window.Game;G.burst=G.float=G.ring=()=>{};return G;
}
function armor(G){G.bricks.forEach(b=>{b.type='normal';b.hp=b.max=10000;b.frozen=false;});G.threshold=999;}
function near(actual,expected){assert.ok(Math.abs(actual-expected)<1e-8,`${actual} != ${expected}`);}
function idle(G,seconds){
  G.engine.gravity.y=0;
  for(let i=0;i<Math.ceil(seconds*120);i++){
    for(const a of G.arrows){Matter.Body.setPosition(a.body,{x:390,y:1250});Matter.Body.setVelocity(a.body,{x:0,y:0});}
    G.tick(1/120);
  }
}

test('row and column strikes each trigger once per main, fan, echo and overlapping shot arrow',()=>{
  for(const id of ['sweep','lance']){
    const G=boot(['trident','echo',id]);armor(G);G.shoot(0,100);
    const main=G.arrows[0],fan=G.arrows[1],target=G.bricks.find(b=>b.x===390&&b.y===410);
    const witness=G.bricks.find(b=>b!==target&&(id==='sweep'?b.y===target.y:b.x===target.x));
    assert.ok(target&&witness);const hp=witness.hp,damage=G.damage();
    const hit=a=>{G.withArrow(a,()=>G.projectileHit(target,a));idle(G,.12);};
    hit(main);near(witness.hp,hp-damage*2);
    hit(main);near(witness.hp,hp-damage*2);
    hit(fan);near(witness.hp,hp-damage*4);
    const echo=G.arrows[6];assert.ok(echo);hit(echo);near(witness.hp,hp-damage*6);
    if(G.time<G.nextShotAt)idle(G,G.nextShotAt-G.time+G.physicsStep);
    const existing=G.arrows.length;assert.equal(G.phase,'flying');assert.equal(G.shoot(0,100),true);
    hit(G.arrows[existing]);near(witness.hp,hp-damage*8);
    hit(main);near(witness.hp,hp-damage*8);
    if(id==='lance')assert.ok(G.bolts.some(b=>b.x===target.x&&b.tx===target.x&&b.ty>=Math.max(...G.bricks.map(t=>t.y))));
  }
});

test('shatter has six independent activations per source and delayed quakes retain retired arrow ownership',()=>{
  const G=boot(['shatter']);armor(G);G.shoot(0,100);
  const first=G.arrows[0],second=G.addArrow(390,1250,0,0);
  const witness=G.bricks.find(b=>b.x===390&&b.y===410),victims=G.bricks.filter(b=>b!==witness).slice(0,15),events=[];
  const hit=G.hit;G.hit=(b,damage,depth)=>{if(b===witness)events.push({source:G.activeArrow,damage});return hit(b,damage,depth);};
  const kill=(a,b)=>{
    b.x=witness.x;b.y=witness.y+30;Matter.Body.setPosition(b.body,{x:b.x,y:b.y});b.hp=1;b.frozen=true;
    G.withArrow(a,()=>G.hit(b,1));
  };
  for(const b of victims.slice(0,7))kill(first,b);
  Matter.Composite.remove(G.engine.world,first.body);G.arrows=G.arrows.filter(a=>a!==first);
  idle(G,.2);assert.equal(events.length,6);assert.ok(events.every(e=>e.source===first));
  for(const b of victims.slice(7,14))kill(second,b);
  idle(G,.2);assert.equal(events.length,12);assert.ok(events.slice(6).every(e=>e.source===second));
  kill(first,victims[14]);idle(G,.2);assert.equal(events.length,12);
  assert.ok(events.every(e=>e.damage===G.damage()*1.5));near(witness.hp,10000-G.damage()*18);
});

test('nova and cascade retain shared flight-round limits across different arrows',()=>{
  for(const [id,limit] of [['nova',8],['cascade',16]]){
    const G=boot([id]);armor(G);G.shoot(0,100);const first=G.arrows[0],second=G.addArrow(390,1250,0,0);
    let spawned=0,explosions=0;const add=G.addArrow;
    G.addArrow=(...args)=>{const a=add(...args);if(a)spawned++;return a;};
    G.skillFX=skill=>{if(skill==='cascade')explosions++;};
    const victims=G.bricks.slice(0,limit*2);
    victims.forEach((b,i)=>G.withArrow(i<limit?first:second,()=>G.hit(b,10000)));
    idle(G,.2);
    if(id==='nova')assert.equal(spawned,24);else assert.equal(explosions,16);
    assert.equal(G.hasPendingEffects(),false);
  }
});

test('multishot and echo inherit both retained damage and penetration skills',()=>{
  const G=boot(['titan','trident','echo','piercer']);armor(G);assert.equal(G.shoot(0,100),true);
  assert.equal(G.arrows.length,6);assert.ok(G.arrows.every(a=>a.damage===4&&a.pierce===6));
  for(const a of G.arrows){Matter.Body.setPosition(a.body,{x:390,y:1100});Matter.Body.setVelocity(a.body,{x:0,y:0});}
  for(let i=0;i<32;i++)G.tick(.01);
  assert.equal(G.arrows.length,12);assert.ok(G.arrows.every(a=>a.damage===4&&a.pierce===6));
});

test('projectile multipliers reach fan arrows and fastest firing cadence wins',()=>{
  const G=boot(['trident','timeslip','rapid','titan']);armor(G);G.shoot(0,100);
  near(G.nextShotAt,.18);assert.equal(G.arrows.length,6);for(const a of G.arrows)near(a.damage,9.4);
  const stacked=boot(['boomerang','spectral','fusepath','rhythm']);stacked.shoot(0,100);assert.equal(stacked.arrows[0].pierce,20);assert.equal(stacked.arrows[0].damage,4);
});

test('ricochet, homing rebound, split and direct-kill growth coexist across modules',()=>{
  const G=boot(['ricochet','reboundaim','bankshot','siphon']);armor(G);G.phase='flying';
  const a=G.addArrow(30,900,0,-20);G.onRicochet(a);near(a.damage,3.3);assert.equal(G.arrows.length,3);
  const target=G.bricks[0];target.hp=1;G.withArrow(a,()=>G.projectileHit(target,a));
  assert.equal(a.siphonKills,1);assert.equal(a.kills,1);near(a.damage,4.125);
  G.onRicochet(a);near(a.damage,5.425);assert.equal(G.arrows.length,5);
  assert.ok(G.arrows.slice(1).every(child=>child.achievement.id!==a.achievement.id));
});

test('outgoing contract cannot mark or reward the next board before or after drafting',()=>{
  const G=boot(['contract','titan','mint','heavy']);assert.ok(G.state.skillRuntime.contract.targets.length);
  G.clear();G.tick(2.1);assert.equal(G.state.skillRuntime.contract,undefined);
  G.state.draft={level:G.state.level,options:['ice','piercer','echo']};assert.equal(G.chooseSkill('ice'),true);
  assert.equal(G.skillRank('contract'),0);assert.equal(G.state.skillRuntime.contract,undefined);
});

test('retained contract and periodic shot counters restart on each new board',()=>{
  const G=boot(['pulse','contract']);armor(G);G.shoot(0,100);assert.equal(G.state.skillRuntime.shots,1);
  G.clear();G.tick(2.1);assert.equal(G.state.skillRuntime.shots,0);assert.equal(G.state.skillRuntime.contract,undefined);
  G.state.draft={level:G.state.level,options:['ice','piercer','echo']};assert.equal(G.chooseSkill('ice'),true);
  assert.equal(G.state.skillRuntime.contract.rounds,0);assert.equal(G.state.skillRuntime.contract.targets.length,3);
});

test('four-skill builds remain bounded, settle and preserve the build through clear',()=>{
  const builds=[
    ['trident','echo','nova','bankshot'],['ice','shatter','nova','prism'],
    ['transmute','cascade','aftershock','doubletap'],['ricochet','reboundaim','bankshot','siphon'],
    ['timeslip','rapid','spectral','siegebreaker'],['boomerang','wormhole','threadweaver','fusepath'],
    ['chronicle','firewheel','worldfold','starforge'],['mint','bounty','contract','treasury'],
    ['overkill','rhythm','siphon','contract'],['teslanet','undertow','infection','lightning']
  ];
  // Include every existing skill in a four-slot build with production modules loaded.
  const ids=Array.from(boot().skillCatalog,s=>s.id);
  for(let i=0;i<ids.length;i+=4)builds.push(ids.slice(i,i+4));
  for(const build of builds){
    const G=boot(build);assert.equal(G.shoot(0,100),true);let steps=0;
    for(;steps<1800&&G.phase==='flying';steps++){
      G.tick(1/120);assert.ok(G.arrows.length<=64,build.join(','));
      assert.ok(G.arrows.every(a=>Number.isFinite(a.damage)&&a.damage>0),build.join(','));
      assert.ok(Number.isFinite(G.state.coins),build.join(','));
    }
    assert.notEqual(G.phase,'flying',build.join(','));assert.equal(G.hasPendingEffects(),false,build.join(','));
    G.clear();assert.deepEqual(Object.keys(G.state.skills),build);
  }
});

test('per-arrow area builds remain bounded and settle after rapid overlapping fire',()=>{
  for(const build of [['rapid','trident','sweep','lance'],['rapid','ice','shatter','nova'],['rapid','undertow','frostfire','thunderlottery']]){
    const G=boot(build);G.state.level=100;G.state.skillChosenLevel=100;G.state.up.arrow=12;G.generate();
    for(let i=0;i<1800&&G.phase!=='clearing'&&(G.time<3||G.phase==='flying');i++){
      if(G.time<3&&G.time>=G.nextShotAt)G.shoot(0,100);
      G.tick(1/120);assert.ok(G.arrows.length<=64,build.join(','));
      assert.ok(G.arrows.every(a=>Number.isFinite(a.damage)&&a.damage>0),build.join(','));
    }
    assert.notEqual(G.phase,'flying',build.join(','));assert.equal(G.hasPendingEffects(),false,build.join(','));
    assert.ok(Number.isFinite(G.state.coins));
  }
});
