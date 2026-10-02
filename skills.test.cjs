const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const Matter=require('./vendor/matter.min.js');
function boot(saved,search=''){
  let storage=saved?JSON.stringify(saved):null,seed=9128;
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const context={Matter,Math:math,console,window:{},URLSearchParams,location:{search},matchMedia:()=>({matches:true}),localStorage:{getItem:()=>storage,setItem:(k,v)=>storage=v},document:{getElementById:()=>({})}};
  vm.createContext(context);for(const file of ['game.js','skills.js','skill-expansion.js'])vm.runInContext(fs.readFileSync(__dirname+'/'+file,'utf8'),context);
  const G=context.window.Game;G.burst=G.float=G.ring=()=>{};return{G,read:()=>JSON.parse(storage)};
}
// Tests that predate the level-gated slot upgrade play with all four slots unlocked.
// skillGateVersion pre-marks the gate migration as already applied so these mechanical
// tests can equip late-game skills (e.g. boomerang) at level 1.
const fresh=()=>({level:1,coins:0,total:0,best:0,comboRulesVersion:2,legacyBest:0,up:{power:0,arrow:0,brick:0,comboCap:0,slots:3},sound:true,board:null,skills:{},skillScopeVersion:3,skillChosenLevel:0,draft:null,skillRuntime:null,skillGateVersion:1});
function ready(ids){const result=boot(fresh()),G=result.G;G.state.skills=Object.fromEntries((Array.isArray(ids)?ids:ids?[ids]:[]).map(id=>[id,1]));G.state.skillChosenLevel=G.state.level;G.state.draft=null;G.phase='ready';return result;}
function choose(G,id){G.state.draft={level:G.state.level,options:[id,...G.skillCatalog.filter(s=>s.id!==id&&!G.skillRank(s.id)).slice(0,2).map(s=>s.id)]};G.prepareDraft();assert.equal(G.chooseSkill(id),true);}
function finish(G){for(let i=0;i<1800&&G.phase==='flying';i++)G.tick(1/120);assert.notEqual(G.phase,'flying');if(G.time<G.nextShotAt)G.tick(G.nextShotAt-G.time);}
function park(G){for(const a of G.arrows){Matter.Body.setPosition(a.body,{x:390,y:1350});Matter.Body.setVelocity(a.body,{x:0,y:0});}}
function armor(G){G.bricks.forEach(b=>{b.type='normal';b.hp=b.max=100;b.frozen=false;});}
test('81 choices, stable drafts and one selection per level',()=>{
  const {G,read}=boot();assert.equal(G.skillCatalog.length,81);assert.ok(G.skillCatalog.every(s=>s.max===1));assert.equal(G.phase,'draft');assert.equal(G.shoot(0,100),false);assert.equal(G.buy('arrow'),false);
  assert.equal(JSON.stringify(boot(read()).G.state.draft),JSON.stringify(G.state.draft));
  const id=G.state.draft.options[0];assert.equal(G.chooseSkill('invalid'),false);assert.equal(G.chooseSkill(id),true);assert.equal(G.chooseSkill(id),false);assert.equal(Object.keys(G.state.skills).length,1);assert.equal(boot(read()).G.skillRank(id),1);
});
test('rebalanced rarities also move draw weights while treasury keeps its ordinary tier and bonus',()=>{
  const {G}=boot(),byId=new Map(G.skillCatalog.map(s=>[s.id,s]));
  const changes=[
    ['forge','blue',112],['sharpshooter','blue',96],['rhythm','blue',101],
    ['teslanet','gold',55],['undertow','gold',53],['frostfire','gold',49],['thunderlottery','gold',48],
    ['timeslip','gold',53.5],['rapid','gold',56],['jackpot','gold',53],
    ['lightning','blue',15],['doubletap','blue',14],['siegebreaker','blue',10.5]
  ];
  for(const [id,tier,oldWeight] of changes){
    const skill=byId.get(id);assert.equal(skill.tier,tier,id);
    assert.ok(oldWeight>18?skill.weight<oldWeight:skill.weight>oldWeight,id+' draw weight');
  }
  assert.equal(byId.get('treasury').tier,'white');assert.equal(byId.get('treasury').weight,116);
  const treasury=ready('treasury').G;for(const level of [1,25,1000])assert.equal(treasury.bonus(level),Math.round(240*level**1.15)*3);
  for(const tier of ['white','blue','gold'])assert.equal(G.skillCatalog.filter(s=>s.tier===tier).length,27);
});
test('clear awards current skill bonus once and keeps skills through transition reload',()=>{
  const {G,read}=ready('treasury');G.save();assert.equal(G.bonus(),720);G.clear();assert.equal(G.state.coins,720);assert.equal(G.skillRank('treasury'),1);assert.equal(Object.keys(G.state.skills).length,1);assert.equal(G.settledBonus,720);G.clear();assert.equal(G.state.coins,720);
  const loaded=boot(read()).G;assert.equal(loaded.state.level,2);assert.equal(loaded.phase,'draft');assert.equal(loaded.state.coins,720);assert.equal(loaded.skillRank('treasury'),1);assert.ok(!loaded.state.draft.options.includes('treasury'));
});
test('equipped skills remain active but cannot be drawn or selected twice',()=>{
  const {G}=ready('titan');assert.equal(G.damage(),4);G.clear();G.tick(2.1);
  G.state.draft={level:2,options:['titan','mint','prism']};G.prepareDraft();assert.ok(!G.state.draft.options.includes('titan'));assert.equal(G.chooseSkill('titan'),false);assert.equal(G.skillRank('titan'),1);assert.equal(G.damage(),4);
  choose(G,'heavy');assert.equal(G.damage(),5.6);assert.deepEqual(Object.keys(G.state.skills),['titan','heavy']);
});
test('four slots rotate oldest-first across levels and reloads, with no replacement argument',()=>{
  let {G,read}=boot(fresh());const history=[];
  for(const id of ['titan','mint','ice','heavy','piercer','titan']){
    if(history.length){G.clear();G.tick(2.1);}
    choose(G,id);history.push(id);
    assert.deepEqual(Object.keys(G.state.skills),history.slice(-4));
    assert.deepEqual(Array.from(G.activeSkills(),s=>s.id),history.slice(-4));
    assert.equal(G.outgoingSkill()?.id,history.length>=4?history.at(-4):undefined);
    const loaded=boot(read());G=loaded.G;read=loaded.read;
    assert.deepEqual(Object.keys(G.state.skills),history.slice(-4));assert.equal(G.phase,'ready');
  }
  assert.equal(G.skillRank('mint'),0);assert.equal(G.skillRank('ice'),1);
});
test('active skill arrays are reused within a shot and replaced when ownership changes',()=>{
  const {G}=ready(['titan','mint']);const first=G.activeSkills();assert.strictEqual(G.activeSkills(),first);
  G.state.skills={cascade:1,storm:1};const second=G.activeSkills();assert.notStrictEqual(second,first);assert.deepEqual(Array.from(second,s=>s.id),['cascade','storm']);
  G.invalidateSkillCache();assert.notStrictEqual(G.activeSkills(),second);
});
test('single-level v2 saves preserve current skill, progress and runtime on migration',()=>{
  const {G,read}=ready('decay');G.prepareDraft();G.state.coins=432;G.state.up.arrow=5;G.killed=3;G.state.skillRuntime.shots=7;G.save();
  const saved=read();saved.skillScopeVersion=2;const loaded=boot(saved).G;
  assert.equal(loaded.state.skillScopeVersion,3);assert.equal(loaded.skillRank('decay'),1);assert.equal(loaded.phase,'ready');assert.equal(loaded.state.coins,432);assert.equal(loaded.state.up.arrow,5);assert.equal(loaded.killed,3);assert.equal(loaded.state.skillRuntime.shots,7);assert.equal(loaded.bricks[0].hp,G.bricks[0].hp);
  saved.level++;saved.board=null;const expired=boot(saved).G;assert.equal(expired.skillRank('decay'),0);assert.equal(expired.phase,'draft');
});
test('malformed skill saves retain only the latest four valid unique entries',()=>{
  const {G,read}=ready('titan');G.save();const saved=read();saved.skills={titan:1,mint:1,invalid:1,ice:1,heavy:1,piercer:1,forge:99};
  const loaded=boot(saved).G;assert.deepEqual(Object.keys(loaded.state.skills),['mint','ice','heavy','piercer']);
  saved.skills=['titan'];const empty=boot(saved).G;assert.equal(Object.keys(empty.state.skills).length,0);assert.equal(empty.phase,'draft');
});
test('legacy accumulated skills are removed without losing wallet, gear or board progress',()=>{
  const {G,read}=ready('mint');G.state.coins=678;G.state.up.arrow=10;G.killed=4;G.save();const old=read();delete old.skillScopeVersion;old.skills={titan:50,mint:10,ice:2};
  const loaded=boot(old).G;assert.equal(loaded.state.coins,678);assert.equal(loaded.state.up.arrow,10);assert.equal(loaded.killed,4);assert.equal(loaded.phase,'draft');assert.equal(Object.keys(loaded.state.skills).length,0);assert.ok(loaded.damage()<5);
});
test('retained decay applies once per board after drafting, never again on reload',()=>{
  const {G,read}=ready('decay');const before=G.bricks[0].hp;G.prepareDraft();assert.equal(G.bricks[0].hp,before*.65);assert.equal(boot(read()).G.bricks[0].hp,G.bricks[0].hp);
  G.clear();G.tick(2.1);assert.ok(G.bricks.every(b=>b.hp===b.max));assert.equal(G.state.skillRuntime.decay,false);
  choose(G,'mint');assert.ok(G.bricks.every(b=>b.hp===b.max*.65));assert.equal(boot(read()).G.bricks[0].hp,G.bricks[0].hp);
});
test('retained resonance reapplies on the next level after drafting',()=>{
  const {G}=ready('resonance');G.prepareDraft();assert.equal(G.threshold,Math.ceil(G.initial*.45));G.clear();G.tick(2.1);choose(G,'mint');assert.equal(G.threshold,Math.ceil(G.initial*.45));
});
test('entry effects of an outgoing skill never leak into the replacement board',()=>{
  for(const id of ['decay','resonance']){
    const {G,read}=ready([id,'mint','titan','heavy']);G.prepareDraft();G.clear();G.tick(2.1);
    const restored=boot(read()).G;choose(restored,'piercer');assert.equal(restored.skillRank(id),0);assert.ok(restored.bricks.every(b=>b.hp===b.max));assert.equal(restored.threshold,Math.ceil(restored.initial*.6));
  }
});
test('the slot upgrade never consumes 神匠赐福, which still applies to real upgrades',()=>{
  const {G}=ready('forge');
  G.state.up.slots=0;G.state.coins=1e5;
  assert.equal(G.state.skillRuntime.forge,false);
  assert.equal(G.buy('slots'),true);
  assert.equal(G.skillSlotBought(),1);                 // exactly +1 slot, not +2
  assert.equal(G.state.up.slots,1);
  assert.equal(G.state.coins,0);
  assert.equal(G.state.skillRuntime.forge,false);      // charge kept for later
  // The next real upgrade still triggers 神匠赐福, adding its usual +2.
  G.state.coins=1e6;assert.equal(G.buy('arrow'),true);
  assert.equal(G.state.up.arrow,3);
  assert.equal(G.state.skillRuntime.forge,true);
});
test('retained economy passives stack and forge refreshes once on each new level',()=>{
  const {G,read}=ready('forge');G.state.coins=10000;G.buy('arrow');assert.equal(G.state.up.arrow,3);const loaded=boot(read()).G;loaded.buy('arrow');assert.equal(loaded.state.up.arrow,4);loaded.clear();loaded.tick(2.1);choose(loaded,'mint');loaded.buy('arrow');assert.equal(loaded.state.up.arrow,7);
  assert.equal(ready('mint').G.reward('normal',1),6);assert.equal(ready('alchemist').G.reward('gold',1),24);assert.equal(ready('bargain').G.cost('arrow'),60);
  const build=ready(['mint','alchemist','bargain','treasury']).G;assert.equal(build.reward('gold',1),48);assert.equal(build.cost('arrow'),60);assert.equal(build.bonus(),720);
});
test('every single passive runs a shot without deadlocking or exceeding projectile budget',()=>{
  for(const skill of boot().G.skillCatalog){const {G}=ready(skill.id);G.prepareDraft();G.shoot(0,100);let peak=0;for(let i=0;i<1800&&G.phase==='flying';i++){G.tick(1/120);peak=Math.max(peak,G.arrows.length);}assert.notEqual(G.phase,'flying',skill.id);assert.ok(peak<=64);assert.ok(Number.isFinite(G.state.coins));}
});
test('ice applies exactly double damage, rage caps, and ricochet grows additively',()=>{
  const ice=ready('ice').G;armor(ice);ice.projectileHit(ice.bricks[0],{damage:1});assert.equal(ice.bricks[0].hp,98);
  const rage=ready('rage').G;armor(rage);
  for(const [kills,multiplier] of [[0,1],[2,1],[3,1.2],[18,2.2],[500,2.2]]){
    const target=rage.bricks[0];target.hp=100;rage.projectileHit(target,{damage:2,kills});assert.ok(Math.abs(target.hp-(100-2*multiplier))<1e-8);
  }
  const kinetic=ready('ricochet').G,a=kinetic.addArrow(390,600,0,-24);for(let i=0;i<20;i++)kinetic.onRicochet(a);assert.equal(a.rebounds,4);assert.equal(a.pierce,10);assert.ok(Math.abs(a.damage-3.2)<1e-9);
});
test('execution threshold is 25 percent and crits deal triple rather than fourfold damage',()=>{
  const G=ready('execute').G;armor(G);const b=G.bricks[0];G.projectileHit(b,{damage:50});assert.equal(b.hp,50);G.projectileHit(b,{damage:25});assert.ok(!G.bricks.includes(b));
  const critical=ready('critical').G;armor(critical);let crits=0;for(const b of critical.bricks.slice(0,60)){critical.projectileHit(b,{damage:2});assert.ok(b.hp===98||b.hp===94);if(b.hp===94)crits++;}assert.ok(crits>0&&crits<60);
});
test('pulse and legion trigger every third shot and counters persist',()=>{
  const {G,read}=ready('pulse');armor(G);G.shoot(0,100);finish(G);const loaded=boot(read()).G;
  loaded.shoot(0,100);finish(loaded);assert.equal(loaded.state.skillRuntime.shots,2);
   const target=loaded.bricks.find(b=>b.x===102),hp=target.hp;loaded.shoot(0,100);park(loaded);finish(loaded);assert.ok(Math.abs(target.hp-(hp-loaded.damage()*1.2))<1e-8);
  const legion=ready('legion').G;armor(legion);for(let i=1;i<=3;i++){legion.shoot(0,100);assert.equal(legion.arrows.length,i===3?7:1);finish(legion);}
});
test('slow damage upgrades leave typical mid and late game bricks needing multiple hits',()=>{
  const G=ready().G;for(const [level,tier] of [[1,0],[5,10],[10,15],[25,22],[100,35],[1000,50]]){G.state.level=level;G.state.up.arrow=tier;assert.ok(G.damage()<G.baseHp(),`${level}/${tier}`);assert.ok(Math.ceil(G.baseHp()/G.damage())<=6);}
});
test('reset clears the entire rolling build and reopens the first draft',()=>{const G=ready(['titan','mint','heavy','ice']).G;G.reset();assert.equal(G.state.level,1);assert.equal(Object.keys(G.state.skills).length,0);assert.equal(G.state.skillScopeVersion,3);assert.equal(G.phase,'draft');});
test('ordinary homing prioritizes an exposed nearby core instead of steering away from it',()=>{
  const G=ready('seeking').G;G.spawnCore();const arrow=G.addArrow(340,G.core.y,20,0);G.beforePhysics(.1);assert.ok(Math.abs(arrow.body.velocity.y)<1e-8);assert.ok(arrow.body.velocity.x>0);
});
test('weighted draws are unique and observed inclusion matches displayed probabilities',()=>{
  const {G}=boot(),counts=Object.fromEntries(G.skillCatalog.map(s=>[s.id,0])),n=60000;
  G.state.level=50; // Past every minLevel gate so the whole catalog is drawable.
  assert.equal(new Set(G.skillCatalog.map(s=>s.id)).size,81);
  assert.ok(G.skillCatalog.every(s=>Number.isFinite(s.weight)&&s.weight>0));
  assert.ok(Math.abs(G.skillCatalog.reduce((sum,s)=>sum+s.chance,0)-3)<1e-10);
  for(let i=0;i<n;i++){const options=G.rollSkills();assert.equal(new Set(options).size,3);for(const id of options)counts[id]++;}
  for(const s of G.skillCatalog){assert.ok(s.tier in G.skillTiers);assert.ok(Math.abs(counts[s.id]/n-s.chance)<.006,s.id);}
  for(const [common,rare] of [['white','blue'],['blue','gold']])assert.ok(Math.min(...G.skillCatalog.filter(s=>s.tier===common).map(s=>s.chance))>Math.max(...G.skillCatalog.filter(s=>s.tier===rare).map(s=>s.chance)));
});
test('boomerang stays out of the draw until the run reaches level 50',()=>{
  const {G}=boot(),boomerang=G.skillCatalog.find(s=>s.id==='boomerang');
  assert.equal(boomerang.minLevel,50);
  for(const level of [1,25,49]){
    G.state.level=level;
    for(let i=0;i<400;i++)assert.ok(!G.rollSkills().includes('boomerang'),`level ${level}`);
    assert.equal(boomerang.chance,0,`level ${level} chance`);
  }
  G.state.level=50;
  const seen=new Set();
  for(let i=0;i<400;i++)for(const id of G.rollSkills())seen.add(id);
  assert.ok(seen.has('boomerang'));
  assert.ok(boomerang.chance>0);
  // A draft persisted before the gate must be re-rolled rather than offered.
  G.state.level=49;G.state.skillChosenLevel=0;
  G.state.draft={level:49,options:['boomerang','ice','mint']};
  G.prepareDraft();
  assert.ok(!G.state.draft.options.includes('boomerang'));
  assert.equal(G.chooseSkill('boomerang'),false);
  assert.equal(G.skillRank('boomerang'),0);
});
test('migration revokes gated skills from older saves below their unlock level',()=>{
  // An old save that predates the gate, still holding a level-30 boomerang.
  const old=fresh();old.level=30;old.skillChosenLevel=30;old.skills={titan:1,boomerang:1};delete old.skillGateVersion;
  const {G,read}=boot(old);
  assert.deepEqual(Object.keys(G.state.skills),['titan']);
  assert.equal(G.skillRank('boomerang'),0);assert.equal(G.skillRank('titan'),1);
  assert.equal(G.state.skillGateVersion,1);
  assert.deepEqual(Array.from(G.revokedSkills,s=>s.id),['boomerang']);
  G.save();assert.deepEqual(Object.keys(read().skills),['titan']);

  // A save that already reached the gate keeps the skill untouched.
  const high=fresh();high.level=60;high.skillChosenLevel=60;high.skills={boomerang:1};delete high.skillGateVersion;
  const kept=boot(high).G;
  assert.equal(kept.skillRank('boomerang'),1);assert.equal(kept.state.skillGateVersion,1);assert.equal(kept.revokedSkills,undefined);

  // Revoking the only skill reopens the draft for that level.
  const only=fresh();only.level=30;only.skillChosenLevel=30;only.skills={boomerang:1};delete only.skillGateVersion;
  const bare=boot(only).G;
  assert.equal(Object.keys(bare.state.skills).length,0);assert.equal(bare.state.skillChosenLevel,0);assert.equal(bare.phase,'draft');

  // The migration is one-time: re-saving keeps it applied without re-reporting.
  const rerun=boot(read()).G;
  assert.deepEqual(Object.keys(rerun.state.skills),['titan']);assert.equal(rerun.revokedSkills,undefined);
});
test('skill slot count follows the purchased shop tiers up to four',()=>{
  const {G}=boot();assert.equal(G.skillSlots,1);
  G.state.up.slots=1;assert.equal(G.skillSlots,2);
  G.state.up.slots=2;assert.equal(G.skillSlots,3);
  G.state.up.slots=3;assert.equal(G.skillSlots,4);
  G.state.up.slots=9;assert.equal(G.skillSlots,4);assert.equal(G.skillSlotBought(),3);
});
test('weighted draws exclude all equipped slots and probabilities reflect the smaller pool',()=>{
  const G=ready(['echo','titan','ice','railgun']).G;G.clear();G.tick(2.1);
  const counts=Object.fromEntries(G.skillCatalog.map(s=>[s.id,0])),n=40000;
  assert.ok(Math.abs(G.skillCatalog.reduce((sum,s)=>sum+s.chance,0)-3)<1e-10);
  for(let i=0;i<n;i++)for(const id of G.rollSkills()){assert.equal(G.skillRank(id),0);counts[id]++;}
  for(const s of G.skillCatalog){assert.ok(Math.abs(counts[s.id]/n-s.chance)<.007,s.id);if(G.skillRank(s.id))assert.equal(s.chance,0);}
});
test('a rarer equipped loadout lowers the next draft odds for rare and legendary skills',()=>{
  const plain=boot().G;plain.state.level=100;plain.rollSkills();
  const byId=new Map(plain.skillCatalog.map(s=>[s.id,s]));
  assert.equal(plain.skillRarityPressure(),0);
  const baseGold=byId.get('meteor').chance,baseWhite=byId.get('echo').chance;
  // One rare adds a single point of pressure and thins only the rare tiers.
  const rare=ready('titan').G;rare.state.level=100;rare.rollSkills();
  const rareById=new Map(rare.skillCatalog.map(s=>[s.id,s]));
  assert.equal(rare.skillRarityPressure(),1);
  assert.equal(rareById.get('echo').drawWeight,byId.get('echo').weight);
  assert.ok(rareById.get('meteor').drawWeight<byId.get('meteor').weight);
  assert.ok(rareById.get('meteor').chance<baseGold);
  assert.ok(rareById.get('echo').chance>baseWhite);
  for(const G of [plain,rare])assert.ok(Math.abs(G.skillCatalog.reduce((sum,s)=>sum+s.chance,0)-3)<1e-10);
  // A full legendary loadout pushes hardest, yet never inverts the tier ordering.
  const full=ready(['titan','ice','railgun','reaper']).G;full.state.level=100;full.rollSkills();
  assert.equal(full.skillRarityPressure(),6);
  const fullById=new Map(full.skillCatalog.map(s=>[s.id,s]));
  const drawable=full.skillCatalog.filter(s=>s.chance>0);
  assert.ok(fullById.get('meteor').drawWeight<rareById.get('meteor').drawWeight);
  assert.ok(fullById.get('echo').drawWeight===byId.get('echo').weight);
  assert.ok(Math.min(...drawable.filter(s=>s.tier==='white').map(s=>s.chance))>Math.max(...drawable.filter(s=>s.tier==='blue').map(s=>s.chance)));
  assert.ok(Math.min(...drawable.filter(s=>s.tier==='blue').map(s=>s.chance))>Math.max(...drawable.filter(s=>s.tier==='gold').map(s=>s.chance)));
  // Equipped skills still leave the pool, and lower rarities recover the mass.
  assert.equal(fullById.get('titan').chance,0);assert.equal(fullById.get('railgun').chance,0);
});
test('new arrow builds deliver their advertised damage, cadence and projectile counts',()=>{
  const rapid=ready('rapid').G;rapid.shoot(0,100);assert.equal(rapid.nextShotAt,.18);assert.equal(rapid.arrows[0].damage,2.7);
  const heavy=ready('heavy').G;assert.equal(heavy.damage(),3.6);assert.equal(heavy.penetration(),4);
  const rail=ready('railgun').G;assert.equal(rail.damage(),8);assert.equal(rail.penetration(),14);
  const swarm=ready('swarmqueen').G;swarm.shoot(0,100);assert.equal(swarm.arrows.length,9);assert.equal(swarm.arrows.filter(a=>a.homing&&a.damage===3&&a.pierce===3).length,8);
  const growing=ready('growing').G;armor(growing);for(let i=1;i<=12;i++){growing.shoot(0,100);assert.equal(growing.arrows[0].damage,2*(1+Math.min(i,10)*.2));finish(growing);}
});
test('poison, delayed bombs, crossfire and kill-spawn effects execute',()=>{
  for(const [id,expected] of [['poison',93.2],['doubletap',94],['crossfire',92]]){
    const G=ready(id).G;armor(G);G.shoot(0,100);const b=G.bricks[0];G.projectileHit(b,{damage:2});for(let i=0;i<65;i++)G.tick(1/120);assert.ok(Math.abs(b.hp-expected)<1e-8,id);
  }
  const G=ready('nova').G;armor(G);G.shoot(0,100);G.hit(G.bricks[0],100);for(let i=0;i<12;i++)G.tick(1/120);assert.equal(G.arrows.filter(a=>a.homing).length,3);
});
test('snowburst freezes five targets and supernova bursts only on the fourth shot',()=>{
  const ice=ready('snowburst').G;armor(ice);ice.shoot(0,100);park(ice);for(let i=0;i<35;i++)ice.tick(1/120);assert.equal(ice.bricks.filter(b=>b.frozen).length,5);assert.ok(ice.bricks.filter(b=>b.frozen).every(b=>b.hp===94));
  const G=ready('supernova').G;armor(G);const b=G.bricks[0];for(let i=1;i<=4;i++){G.shoot(0,100);park(G);finish(G);assert.equal(b.hp,i===4?85:100);}
});
test('conditional damage rewards fresh targets, damaged targets and a fully drawn bow',()=>{
  const ambush=ready('ambush').G;armor(ambush);const b=ambush.bricks[0];ambush.projectileHit(b,{damage:2});assert.equal(b.hp,94);ambush.projectileHit(b,{damage:2});assert.equal(b.hp,92);
  const follow=ready('opportunist').G;armor(follow);const c=follow.bricks[0];follow.projectileHit(c,{damage:2});assert.equal(c.hp,98);follow.projectileHit(c,{damage:2});assert.equal(c.hp,92);assert.equal(follow.penetration(),4);
  for(const [power,damage,pierce] of [[94,2,2],[95,6,8],[100,6,8]]){const G=ready('sharpshooter').G;G.shoot(0,power);assert.equal(G.arrows[0].damage,damage);assert.equal(G.arrows[0].pierce,pierce);}
});
test('siphon refunds penetration and grows additively for only eight direct kills',()=>{
  const G=ready('siphon').G;armor(G);G.phase='flying';const a=G.addArrow(390,1000,0,-20);G.bricks.forEach(b=>b.hp=1);
  for(let i=0;i<12;i++)G.projectileHit(G.bricks[0],a);
  assert.equal(a.siphonKills,8);assert.equal(a.pierce,10);assert.equal(a.damage,6);
});
test('bankshot splits at most three times and children never split again',()=>{
  const G=ready('bankshot').G,a=G.addArrow(390,1000,0,-20);
  for(let i=0;i<10;i++)G.onRicochet(a);assert.equal(G.arrows.length,7);assert.equal(a.bankshots,3);
  for(const child of G.arrows.slice(1)){assert.ok(child.bankEcho&&child.homing);assert.equal(child.damage,4);assert.equal(child.pierce,2);G.onRicochet(child);}
  assert.equal(G.arrows.length,7);
  const mirror=ready('mirror').G;mirror.shoot(0,100);assert.equal(mirror.arrows.length,5);assert.deepEqual([...new Set(mirror.arrows.slice(1).map(a=>a.body.position.x))],[36,744]);
});
test('minefield fires three pulses once per arrow and frostfire doubles its blast',()=>{
  const G=ready('minefield').G;armor(G);G.shoot(0,100);const a=G.arrows[0],b=G.bricks[0];park(G);
  G.projectileHit(b,a);G.projectileHit(b,a);for(let i=0;i<70;i++)G.tick(1/120);assert.equal(b.hp,84);
  const ice=ready('frostfire').G;armor(ice);ice.shoot(0,100);park(ice);const target=ice.bricks[0];ice.projectileHit(target,ice.arrows[0]);for(let i=0;i<20;i++)ice.tick(1/120);assert.ok(target.frozen);assert.equal(target.hp,92);
});
test('orbital targets the densest cluster and stormfront affects exactly three rows',()=>{
  const G=ready('orbital').G;armor(G);const target=G.bricks.reduce((best,b)=>{const count=G.bricks.filter(t=>Math.hypot(t.x-b.x,t.y-b.y)<160).length;return count>best.count?{b,count}:best;},{count:-1}).b;
  G.shoot(0,100);park(G);finish(G);assert.equal(target.hp,82);assert.ok(G.bricks.filter(b=>Math.hypot(target.x-b.x,target.y-b.y)>=160).every(b=>b.hp===100));
  const storm=ready('stormfront').G;armor(storm);storm.shoot(0,100);park(storm);finish(storm);const hit=storm.bricks.filter(b=>b.hp<100);assert.equal(new Set(hit.map(b=>b.y)).size,3);assert.ok(hit.every(b=>b.hp===94));
});
test('reaper executes only on the third shot and chooses the four weakest bricks',()=>{
  const G=ready('reaper').G;armor(G);const targets=G.bricks.slice(0,4);targets.forEach((b,i)=>b.hp=i+1);const count=G.bricks.length;
  for(let i=1;i<=3;i++){G.shoot(0,100);park(G);finish(G);assert.equal(G.bricks.length,count-(i===3?4:0));}assert.ok(targets.every(b=>!G.bricks.includes(b)));assert.equal(G.damage(),3.2);
});
test('roulette reaches all three modes and applies each mode correctly',()=>{
  const G=ready('roulette').G,seen=new Set();armor(G);
  for(let i=0;i<45;i++){
    G.shoot(0,100);const a=G.arrows[0],mode=a.rouletteMode;seen.add(mode);const hp=G.bricks[0].hp;
    if(mode===0){assert.equal(a.damage,10);assert.equal(a.pierce,12);assert.equal(G.arrows.length,1);}
    if(mode===1){assert.equal(G.arrows.length,9);assert.ok(G.arrows.slice(1).every(a=>a.homing&&a.damage===4));}
    park(G);finish(G);assert.equal(G.bricks[0].hp,hp-(mode===2?5:0));
  }
  assert.equal(seen.size,3);
});
test('thunder lottery sometimes adds six triple-damage arcs and bounty caps at threefold',()=>{
  const G=ready('thunderlottery').G;armor(G);let wins=0;
  for(let i=0;i<25;i++){G.bricks.forEach(b=>b.hp=100);G.shoot(0,100);park(G);G.projectileHit(G.bricks[0],G.arrows[0]);finish(G);const hit=G.bricks.filter(b=>b.hp<=94);if(hit.length){wins++;assert.equal(hit.length,6);}}
  assert.ok(wins>0&&wins<25);
  const bounty=ready('bounty').G,plain=ready().G;for(const [n,multiplier] of [[1,1],[2,1.25],[9,3],[20,3]])assert.equal(bounty.reward('normal',n),Math.round(plain.reward('normal',n)*multiplier));
  const special=ready('specialist').G;armor(special);const b=special.bricks[0];b.type='gold';special.projectileHit(b,{damage:2});assert.equal(b.hp,92);assert.equal(special.reward('gold',1),plain.reward('gold',1)*3);assert.equal(special.reward('normal',1),plain.reward('normal',1));
});
for(const search of ['', '?launcher=1']){
  test(`draft, shooting, reload and next-level behavior are shared (${search||'normal'})`,()=>{
    const {G,read}=boot(null,search);
    assert.equal(G.paused,false);
    assert.equal(G.phase,'draft');
    assert.equal(G.shoot(0,100),false,'choose a skill before shooting in either mode');
    assert.equal(G.chooseSkill(G.state.draft.options[0]),true);
    assert.equal(G.phase,'ready'); // reduced motion in this harness
    assert.equal(G.shoot(0,100),true);
    G.save();
    const loaded=boot(read(),search).G;
    assert.equal(loaded.phase,'ready','an already chosen skill survives reload');
    assert.deepEqual(Object.keys(loaded.state.skills),Object.keys(G.state.skills));
    loaded.clear();loaded.tick(3);
    assert.equal(loaded.state.level,2);
    assert.equal(loaded.phase,'draft','each new level offers a skill in either mode');
    assert.equal(loaded.shoot(0,100),false);
    assert.equal(loaded.chooseSkill(loaded.state.draft.options[0]),true);
    assert.equal(loaded.shoot(0,100),true);
  });
}
