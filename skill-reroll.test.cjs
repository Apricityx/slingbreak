const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const Matter=require('./vendor/matter.min.js');
function boot(saved){
  let storage=saved?JSON.stringify(saved):null,seed=4711;
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const context={Matter,Math:math,console,window:{},URLSearchParams,location:{search:''},matchMedia:()=>({matches:true}),localStorage:{getItem:()=>storage,setItem:(k,v)=>storage=v},document:{getElementById:()=>({})}};
  vm.createContext(context);for(const file of ['game.js','skills.js','skill-expansion.js'])vm.runInContext(fs.readFileSync(__dirname+'/'+file,'utf8'),context);
  const G=context.window.Game;G.burst=G.float=G.ring=()=>{};return{G,read:()=>JSON.parse(storage)};
}
const fresh=(extra={})=>({level:1,coins:0,total:0,best:0,comboRulesVersion:2,legacyBest:0,up:{power:0,arrow:0,brick:0,comboCap:0,slots:3,rerollCap:0},sound:true,board:null,skills:{},skillScopeVersion:3,skillChosenLevel:0,draft:null,skillRuntime:null,skillGateVersion:1,...extra});
// A level with its skill already picked, so the run sits in 'ready'.
function ready(ids,extra){
  const result=boot(fresh(extra)),G=result.G;
  G.state.skills=Object.fromEntries(ids.map(id=>[id,1]));G.state.skillChosenLevel=G.state.level;G.state.draft=null;G.invalidateSkillCache();G.phase='ready';
  return result;
}
const nextLevel=G=>{G.clear();G.tick(2.1);};

test('old saves migrate to one empty charge slot',()=>{
  const save=fresh();delete save.up.rerollCap;
  const {G}=boot(save);
  assert.equal(G.state.up.rerollCap,0);assert.equal(G.rerollCap(),1);assert.equal(G.rerolls(),0);assert.equal(G.state.rerollGrantLevel,0);
  // Over-cap or garbage charges are clamped on load.
  assert.equal(boot(fresh({rerolls:9})).G.rerolls(),1);
  assert.equal(boot(fresh({rerolls:-3,up:{...fresh().up,rerollCap:'x'}})).G.rerolls(),0);
});

test('every fifth clear banks one charge, capped, and never twice for one level',()=>{
  const {G,read}=ready(['titan']);G.state.up.rerollCap=1;
  const gains=[];
  for(let level=1;level<=15;level++){
    assert.equal(G.state.level,level);
    G.clear();gains.push(G.rerollGained?level:0);G.tick(2.1);
    G.state.skillChosenLevel=G.state.level;G.state.draft=null;G.phase='ready';
  }
  assert.deepEqual(gains.filter(Boolean),[5,10]);
  assert.equal(G.rerolls(),2);assert.equal(G.rerollCap(),2);
  assert.equal(read().rerolls,2);
  // Jumping back across level 15 does not pay it again.
  G.state.level=15;G.state.rerolls=0;G.phase='ready';G.clear();
  assert.equal(G.rerollGained,false);assert.equal(G.rerolls(),0);
});

test('shop raises the charge cap with escalating prices and is excluded from forge',()=>{
  const {G}=ready(['forge']);G.state.coins=1e12;
  const prices=[];
  for(let i=0;i<G.rerollCapUpgrades;i++){prices.push(G.cost('rerollCap'));assert.equal(G.buy('rerollCap'),true);}
  assert.ok(prices.every((p,i)=>!i||p>prices[i-1]));
  assert.equal(G.rerollCap(),G.rerollCapMax);assert.equal(G.buy('rerollCap'),false);
  assert.equal(G.state.up.rerollCap,G.rerollCapUpgrades,'forge bonus never lands on the cap');
  assert.ok(!G.state.skillRuntime.forge,'forge charge kept for a real upgrade');
});

test('draft reroll spends one charge and deals three new options',()=>{
  const {G,read}=boot(fresh({rerolls:1}));
  assert.equal(G.phase,'draft');
  const before=[...G.state.draft.options];
  assert.equal(G.rerollDraft(),true);
  const after=G.state.draft.options;
  assert.equal(after.length,3);assert.ok(after.every(id=>!before.includes(id)));
  assert.equal(G.rerolls(),0);assert.equal(G.rerollDraft(),false,'no charge left');
  // The rerolled draft is what reloads, so closing the tab cannot undo it.
  const loaded=boot(read()).G;
  assert.deepEqual([...loaded.state.draft.options],[...after]);assert.equal(loaded.rerolls(),0);
  assert.equal(loaded.chooseSkill(after[0]),true);
});

test('in-run swap: offer costs a charge, keeps the queue position and survives reload',()=>{
  const {G,read}=ready(['titan','mint','ice'],{rerolls:2,up:{...fresh().up,rerollCap:1}});
  assert.equal(G.offerSwap('nope'),null,'only equipped skills can be swapped');
  const offer=G.offerSwap('mint');
  assert.ok(offer);assert.equal(offer.options.length,3);assert.equal(G.rerolls(),1);
  assert.ok(offer.options.every(id=>!G.skillRank(id)));
  // Reopening the dialog shows the same offer for free.
  const loaded=boot(read()).G;loaded.phase='ready';
  assert.deepEqual([...loaded.swapOffer('mint').options],[...offer.options]);assert.equal(loaded.rerolls(),1);
  assert.equal(G.swapOffer('titan'),null);
  // A second roll avoids the first three.
  const second=G.offerSwap('mint');
  assert.ok(second.options.every(id=>!offer.options.includes(id)));assert.equal(G.rerolls(),0);
  assert.equal(G.swapSkill('mint',offer.options[0]),false,'stale candidate');
  const pick=second.options[1];
  assert.equal(G.swapSkill('mint',pick),true);
  assert.deepEqual(Object.keys(G.state.skills),['titan',pick,'ice']);
  assert.equal(G.skillRank('mint'),0);assert.equal(G.skillRank(pick),1);
  assert.equal(G.state.swapOffer,null);assert.equal(G.swapSkill('mint',pick),false);
  assert.deepEqual(Object.keys(boot(read()).G.state.skills),['titan',pick,'ice']);
});

test('swaps are blocked outside the ready phase and expire with the level',()=>{
  const {G}=ready(['titan'],{rerolls:1});
  G.phase='flying';assert.equal(G.offerSwap('titan'),null);assert.equal(G.rerolls(),1);
  G.phase='ready';const offer=G.offerSwap('titan');assert.ok(offer);
  G.phase='flying';assert.equal(G.swapSkill('titan',offer.options[0]),false);
  G.phase='ready';nextLevel(G);
  assert.equal(G.swapOffer('titan'),null,'offers belong to the level they were rolled on');
});

test('reset clears charges, cap and any pending offer',()=>{
  const {G}=ready(['titan'],{rerolls:1});G.offerSwap('titan');
  G.reset();
  assert.equal(G.rerolls(),0);assert.equal(G.state.up.rerollCap,0);assert.equal(G.state.swapOffer,null);assert.equal(G.state.rerollGrantLevel,0);
});
