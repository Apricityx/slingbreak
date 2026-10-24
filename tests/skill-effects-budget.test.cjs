const ROOT=require('node:path').resolve(__dirname,'..');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');

function boot(){
  const calls={flash:0,layout:0};
  const fake=()=>({style:{setProperty:()=>{}},dataset:{},classList:{add:()=>calls.flash++,remove:()=>{}},
    before:()=>{},querySelector:()=>fake(),replaceChildren:()=>{},append:()=>{},setAttribute:()=>{},
    addEventListener:()=>{},innerHTML:'',textContent:'',hidden:false,open:false,showModal:()=>{},close:()=>{}});
  const earnings=fake();
  Object.defineProperty(earnings,'offsetWidth',{get(){calls.layout++;return 0;}});
  const skill={id:'mint',name:'黄金时代'};
  const G={state:{skills:{mint:1}},time:100,phase:'flying',reduced:true,skillCatalog:[skill],skillSlots:1,
    activeSkills:()=>[skill],outgoingSkill:()=>null,skillRank:id=>id==='mint'?1:0,
    awardBrick:()=>0,clear:()=>0,generate:()=>0};
  const context={window:{Game:G},document:{createElement:fake,getElementById:id=>id==='earnings'?earnings:fake(),
    documentElement:fake()},lucide:{createIcons:()=>{}}};
  vm.createContext(context);
  const source=fs.readFileSync(ROOT+'/game/src/effects/skill-effects.js','utf8')
    .replace('  refresh();\n})();','  G.testEffects=effects;refresh();\n})();');
  vm.runInContext(fs.readFileSync(ROOT+'/game/src/theme/colors.js','utf8'),context,{filename:'colors.js'});
  vm.runInContext(source,context,{filename:'skill-effects.js'});
  return {G,calls};
}

test('the economy HUD flash is throttled to one forced layout per 0.35s',()=>{
  const {G,calls}=boot();
  G.awardBrick();G.awardBrick();
  assert.equal(calls.flash,1,'same instantaneous burst must lay out the earnings panel once');
  assert.equal(calls.layout,1);
  G.time=100.34;G.awardBrick();
  assert.equal(calls.flash,1,'inside the throttle window');
  G.time=100.36;G.awardBrick();
  assert.equal(calls.flash,2);assert.equal(calls.layout,2);
  G.time=200;for(let i=0;i<5;i++)G.awardBrick();
  assert.equal(calls.flash,3,'a later synchronous batch also restarts at most once');
});

test('forced skill effects keep at most one full draw budget per simulation instant',()=>{
  const {G}=boot();
  for(let i=0;i<40;i++)G.skillFX('mint',i,0,{force:true});
  assert.equal(G.testEffects.length,24);
  G.time=101;
  for(let i=0;i<5;i++)G.skillFX('mint',i,0,{force:true});
  assert.equal(G.testEffects.length,29);
  G.time=102;G.skillFX('mint',0,0,{force:true});
  assert.equal(G.testEffects.length,30);
  G.generate();
  assert.equal(G.testEffects.length,0);
  G.phase='ready';for(let i=0;i<10;i++)G.skillFX('mint',i,0,{force:true});
  assert.equal(G.testEffects.length,10,'non-flight UI effects stay outside the burst budget');
  G.phase='flying';for(let i=0;i<30;i++)G.skillFX('mint',i,0,{force:true});
  assert.equal(G.testEffects.length,34,'generation resets the per-instant budget');
  assert.equal(G.testEffects.filter(e=>e.budgeted).map(e=>e.x).join(','),
    '6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29',
    'the ring keeps the latest 24 budgeted impacts');
});
