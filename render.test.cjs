const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const Matter=require('./vendor/matter.min.js');
const gameSource=fs.readFileSync(__dirname+'/game.js','utf8');
const renderSource=fs.readFileSync(__dirname+'/render.js','utf8');

// render.js is a DOM renderer, so the harness drives it with a recording 2D
// context instead of a real canvas. Every context call is logged, which lets a
// test distinguish "the board was painted" from "the board stayed blank".
function boot({launcher=false, phase='ready', draftOpen=false}={}){
  const calls=[],frames=[];
  const target={};
  const ctx=new Proxy(target,{
    get(t,prop){
      if(prop in t)return t[prop];
      if(prop==='measureText'){t[prop]=()=>({width:10});return t[prop];}
      t[prop]=(...args)=>{calls.push([prop,args]);};
      return t[prop];
    },
    set(t,prop,value){t[prop]=value;return true;}
  });
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
    document:{getElementById:id=>elements[id]||makeElement(),querySelector:()=>makeElement(),querySelectorAll:()=>[],fonts:{addEventListener(){}},addEventListener(){},documentElement:{classList:{add(){},remove(){},contains:()=>false}}},
    window:{addEventListener(){},dispatchEvent(){}},
  };
  vm.createContext(context);
  vm.runInContext(gameSource,context);
  context.Game=context.window.Game;
  const G=context.Game;
  G.phase=phase;
  G.generate(false);
  G.phase=phase;
  vm.runInContext(renderSource,context);
  return {G,calls,observers,frames,step:now=>{assert.equal(frames.length,1);frames.shift()(now);},count:prop=>calls.filter(c=>c[0]===prop).length};
}

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
