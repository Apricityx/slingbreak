const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const source=fs.readFileSync(__dirname+'/launcher-mode.js','utf8');

function boot(search='?launcher=1'){
  const elements=new Map(),events={},calls=[];
  function element(){return {hidden:true,textContent:'',style:{},attributes:{},classList:{add(){}},
    replaceChildren(...children){this.children=children;},setAttribute(key,value){this.attributes[key]=value;},
    addEventListener(name,callback){this[name]=callback;},focus(){calls.push('focus');}};}
  const window={AndroidSlingBreakLauncher:{onPageReady:()=>calls.push('pageReady'),enterGame:()=>calls.push('enterGame'),scriptError:error=>calls.push(['error',error])},
    addEventListener:(name,callback)=>events[name]=callback,
    dispatchEvent:()=>calls.push('dispatchEvent')};
  // The loading header must not even read the minigame: the native game can be
  // entered while the minigame is paused, choosing a skill, or failed to load.
  Object.defineProperty(window,'Game',{get(){throw new Error('launcher header accessed minigame state');}});
  vm.runInNewContext(source,{window,URLSearchParams,location:{search},document:{
    documentElement:element(),getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id);},
    createTextNode:text=>({textContent:String(text)}),createElement:element,
  }});
  return {api:window.SlingBreakLauncher,elements,events,calls};
}

test('launcher header updates progress and enters the native game once without touching gameplay',()=>{
  const {api,elements,calls}=boot();
  api.pageReady();api.enterGame();
  assert.deepEqual(calls,['pageReady'],'native entry is gated on readiness');
  api.setProgress(42,'加载模组');
  assert.equal(elements.get('launcher-progress-label').textContent,'加载模组');
  assert.equal(elements.get('launcher-progress-bar').style.width,'42%');
  assert.equal(elements.get('launcher-progress-track').attributes['aria-valuenow'],42);
  api.setReady();api.setReady();api.setProgress(10,'旧进度');
  assert.equal(elements.get('launcher-progress-bar').style.width,'100%');
  assert.equal(elements.get('launcher-ready-button').hidden,false);
  assert.deepEqual(calls,['pageReady'],'readiness must not steal focus or dispatch gameplay events');
  elements.get('launcher-ready-button').click();api.enterGame();
  assert.deepEqual(calls,['pageReady','enterGame']);
});

test('launcher forwards script errors and rejected promises to the native bridge',()=>{
  const {events,calls}=boot();
  events.error({message:'script failed'});
  events.unhandledrejection({reason:'promise failed'});
  assert.deepEqual(calls,[['error','script failed'],['error','promise failed']]);
});

test('ordinary pages do not activate the launcher header or bridge',()=>{
  const {api,elements,events,calls}=boot('');
  assert.equal(api,undefined);
  assert.equal(elements.size,0);
  assert.deepEqual(events,{});
  assert.deepEqual(calls,[]);
});
