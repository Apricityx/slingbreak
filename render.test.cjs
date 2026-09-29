const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const Matter=require('./vendor/matter.min.js');
const gameSource=fs.readFileSync(__dirname+'/game.js','utf8');
const renderSource=fs.readFileSync(__dirname+'/render.js','utf8');
const paletteSource=fs.readFileSync(__dirname+'/palette.js','utf8');

// render.js is a DOM renderer, so the harness drives it with a recording 2D
// context instead of a real canvas. Every context call is logged, which lets a
// test distinguish "the board was painted" from "the board stayed blank".
const recordingContext=calls=>new Proxy({},{
  get(t,prop){
    if(prop in t)return t[prop];
    if(prop==='measureText'){t[prop]=()=>({width:10});return t[prop];}
    t[prop]=(...args)=>{calls.push([prop,args]);};
    return t[prop];
  },
  set(t,prop,value){t[prop]=value;if(prop==='fillStyle')calls.push(['fillStyle',[value]]);return true;}
});
// `layers` exposes document.createElement so render.js enables its offscreen
// caches; everything painted into an offscreen canvas lands in layerCalls.
function boot({launcher=false, phase='ready', draftOpen=false, layers=false}={}){
  const calls=[],frames=[],layerCalls=[];
  const ctx=recordingContext(calls);
  const makeElement=()=>({textContent:'',hidden:false,open:false,style:{},classList:{add(){},remove(){},toggle(){},contains:()=>false},addEventListener(){},focus(){},querySelector:()=>makeElement(),querySelectorAll:()=>[]});
  const canvas={width:780,height:760,style:{},tabIndex:0,getContext:()=>ctx,getBoundingClientRect:()=>({width:780,height:760,left:0,top:0,right:780,bottom:760}),addEventListener(){},setPointerCapture(){},focus(){},classList:{add(){},remove(){},contains:()=>false}};
  const dialog=makeElement();dialog.open=draftOpen;
  const elements={game:canvas,'skill-draft':dialog,'power-readout':makeElement()};
  const observers=[];
  function ResizeObserverStub(callback){this.callback=callback;this.observe=()=>{};this.disconnect=()=>{};observers.push(this);}
  const context={
    Matter,console,URLSearchParams,
    location:{search:launcher?'?launcher=1':''},
    devicePixelRatio:1,
    matchMedia:()=>({matches:false,addEventListener(){},removeEventListener(){}}),
    performance:{now:()=>0},
    requestAnimationFrame:callback=>{frames.push(callback);return frames.length;},cancelAnimationFrame(){},
    ResizeObserver:ResizeObserverStub,
    localStorage:{getItem:()=>null,setItem(){}},
    document:{getElementById:id=>elements[id]||makeElement(),querySelector:()=>makeElement(),querySelectorAll:()=>[],fonts:{addEventListener(){}},addEventListener(){},documentElement:{classList:{add(){},remove(){},contains:()=>false}},
      ...(layers?{createElement:()=>{const layer=recordingContext(layerCalls);return {width:0,height:0,getContext:()=>layer};}}:{})},
    window:{addEventListener(){},dispatchEvent(){}},
  };
  vm.createContext(context);
  // index.html loads palette.js in <head>, before any game script.
  vm.runInContext(paletteSource,context);
  vm.runInContext(gameSource,context);
  context.Game=context.window.Game;
  const G=context.Game;
  G.phase=phase;
  G.generate(false);
  G.phase=phase;
  vm.runInContext(renderSource,context);
  return {G,theme:context.window.SlingTheme,calls,layerCalls,observers,frames,step:now=>{assert.equal(frames.length,1);frames.shift()(now);},count:prop=>calls.filter(c=>c[0]===prop).length};
}

// Regression: a hit changes hp and starts a flash in the same frame. The flash
// frames paint live, and the cached board must still be rebuilt afterwards
// instead of blitting the pre-hit board (stale hp / resurrected bricks).
const settle=G=>{for(const b of G.bricks)b.flash=0;for(const o of G.obstacles)o.flash=0;G.shake=0;};
const layerBricks=layerCalls=>layerCalls.filter(c=>c[0]==='roundRect').length;
for(const [name,act] of [
  ['a damaged brick',G=>{const b=G.bricks.find(b=>b.type==='normal');b.hp=b.max-.5;b.flash=.16;}],
  ['a destroyed brick',G=>{const b=G.bricks[0];G.bricks.splice(0,1);G.bricks[0].flash=.16;G.shake=1.5;return b;}],
]){
  test(`the cached board repaints ${name} once its hit flash ends`,()=>{
    const {G,layerCalls,step}=boot({phase:'ready',layers:true});
    G.paused=true;
    step(20);
    assert.ok(layerBricks(layerCalls)>0,'first frame builds the board layer');
    layerCalls.length=0;step(40);
    assert.equal(layerBricks(layerCalls),0,'an unchanged board is blitted from cache');
    act(G);step(60);
    settle(G);layerCalls.length=0;step(80);
    // Two rounded fills per brick, three per barrier.
    assert.equal(layerBricks(layerCalls),G.bricks.length*2+G.obstacles.length*3,'board layer must be rebuilt with the post-hit bricks');
  });
}

// A theme switch must not leave the cached board in the old palette.
test('switching theme rebuilds the cached board in the new palette',()=>{
  const {G,theme,layerCalls,step}=boot({phase:'ready',layers:true});
  G.paused=true;settle(G);
  step(20);step(40);
  const fills=()=>layerCalls.filter(c=>c[0]==='fillStyle').map(c=>c[1][0]);
  assert.ok(fills().includes(theme.palettes.light.brick.normal),'light board uses the light brick fill');
  layerCalls.length=0;step(60);
  assert.equal(layerBricks(layerCalls),0,'settled board is cached');
  theme.set('dark');step(80);
  assert.ok(layerBricks(layerCalls)>0,'theme change invalidates the board layer');
  assert.ok(fills().includes(theme.palettes.dark.brick.normal),'rebuilt board uses the dark brick fill');
  assert.ok(!fills().includes(theme.palettes.light.brick.normal),'no light brick fill leaks into the dark layer');
  assert.equal(G.colors.normal,theme.palettes.dark.brick.normal,'particle colours follow the theme too');
});

for(const launcher of [false,true]){
test(`the frame loop paints before any input (${launcher?'launcher':'normal'})`,()=>{
  const {G,calls,count,step,frames}=boot({launcher,phase:'ready'});
  step(20);
  assert.ok(G.time>0,'simulation must advance without a gesture or native entry');
  assert.equal(frames.length,1,'keep exactly one running frame loop');
  assert.ok(G.bricks.length>0,'board should have bricks to paint');
  // Two rounded fills per brick; the sling only contributes five power pips.
  assert.ok(count('roundRect')>G.bricks.length,'bricks must be painted');
  assert.ok(calls.some(c=>c[0]==='fillText'),'board labels must be painted');
});

test(`an open draft dialog hides the board (${launcher?'launcher':'normal'})`,()=>{
  const {count,step}=boot({launcher,phase:'draft',draftOpen:true});
  step(20);
  // Only the five sling power pips remain; no brick geometry is emitted.
  assert.equal(count('roundRect'),5,'board must stay hidden while the draft dialog is open');
});

test(`resize is repainted by the next frame (${launcher?'launcher':'normal'})`,()=>{
  const {observers,calls,step,count}=boot({launcher,phase:'ready'});
  step(20);
  calls.length=0;
  const before=calls.length;
  observers[0].callback([]);
  assert.equal(calls.length,before,'the frame loop owns repainting once it is running');
  step(40);
  assert.ok(count('roundRect')>5,'resize must not leave the board blank');
});
}
