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
  const calls=[];
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
    requestAnimationFrame:()=>0,cancelAnimationFrame(){},
    ResizeObserver:ResizeObserverStub,
    localStorage:{getItem:()=>null,setItem(){}},
    document:{getElementById:id=>elements[id]||makeElement(),querySelector:()=>makeElement(),querySelectorAll:()=>[],fonts:{addEventListener(){}},addEventListener(){},documentElement:{classList:{add(){},remove(){},contains:()=>false}}},
    window:{addEventListener(){},dispatchEvent(){}},
  };
  context.window.Game=context.window.Game;
  vm.createContext(context);
  vm.runInContext(gameSource,context);
  context.Game=context.window.Game;
  const G=context.Game;
  G.phase=phase;
  G.generate(false);
  G.phase=phase;
  vm.runInContext(renderSource,context);
  return {G,calls,observers,count:prop=>calls.filter(c=>c[0]===prop).length};
}

test('launcher preview paints the board during the suppressed draft phase',()=>{
  const {G,calls,count}=boot({launcher:true,phase:'draft',draftOpen:false});
  assert.ok(G.bricks.length>0,'board should have bricks to paint');
  // Two rounded fills per brick; the sling only contributes five power pips.
  assert.ok(count('roundRect')>G.bricks.length,'bricks must be painted before the player enters');
  assert.ok(calls.some(c=>c[0]==='fillText'),'board labels must be painted');
});

test('an open draft dialog still hides the board',()=>{
  const {G,count}=boot({launcher:true,phase:'draft',draftOpen:true});
  // Only the five sling power pips remain; no brick geometry is emitted.
  assert.equal(count('roundRect'),5,'board must stay hidden while the draft dialog is open');
});

test('the launcher repaints when the canvas resizes before the loop starts',()=>{
  const {observers,calls,count}=boot({launcher:true,phase:'ready'});
  assert.equal(observers.length,1,'render.js should observe the canvas');
  const before=calls.length;
  observers[0].callback([]);
  assert.ok(calls.length>before,'resize must repaint while no animation frame is running');
  assert.ok(count('roundRect')>0);
});

test('a running animation loop does not double paint on resize',()=>{
  const {observers,calls}=boot({launcher:false,phase:'ready'});
  const before=calls.length;
  observers[0].callback([]);
  assert.equal(calls.length,before,'the frame loop owns repainting once it is running');
});
