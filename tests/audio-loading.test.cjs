const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../game/src/ui/audio-loading.js'),'utf8');

function boot(volume=100,native=true){
  const elements=Object.fromEntries(['intro-audio-status','sound-cache-status','sound-volume'].map(id=>[id,{hidden:true,textContent:'',addEventListener(type,handler){this[type]=handler;}}]));
  const timers=new Map(),pending=[];let sequence=0,preloads=0;
  const snapshot={state:'idle',loading:{completed:0,total:180}};
  const G={state:{volume,sound:volume>0},audio:{nativeMusic:native?{}:null,diagnosticSnapshot:()=>snapshot,
    preload(){preloads++;return new Promise(resolve=>pending.push(resolve));}}};
  const context={window:{Game:G},document:{getElementById:id=>elements[id]},setInterval:fn=>{const id=++sequence;timers.set(id,fn);return id;},clearInterval:id=>timers.delete(id)};
  vm.createContext(context);vm.runInContext(source,context);
  return {G,elements,timers,pending,snapshot,get preloads(){return preloads;}};
}

test('audio loading shows actual progress and failure without blocking or writing saves',async()=>{
  const {elements,timers,pending,snapshot}=boot();
  snapshot.state='preparing';snapshot.loading.completed=90;
  for(const fn of timers.values())fn();
  assert.equal(elements['intro-audio-status'].textContent,'正在准备音效 · 90 / 180 · 50%');
  snapshot.state='failed';pending[0]();
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(elements['sound-cache-status'].textContent,'声音暂时不可用');
  assert.equal(timers.size,0);
});

test('initial mute starts no work; enabling sound starts preparation and stale completions cannot finish a newer load',async()=>{
  const state=boot(0),{G,elements,timers,pending,snapshot}=state;
  assert.equal(state.preloads,0);assert.equal(timers.size,0);
  assert.equal(elements['sound-cache-status'].textContent,'声音已关闭');
  G.state.volume=35;G.state.sound=true;snapshot.state='preparing';elements['sound-volume'].input();
  G.state.volume=0;G.state.sound=false;elements['sound-volume'].input();
  G.state.volume=35;G.state.sound=true;elements['sound-volume'].input();
  assert.equal(state.preloads,2);assert.equal(timers.size,1);
  pending[0]();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(timers.size,1,'old completion does not remove the new status timer');
  snapshot.state='ready';pending[1]();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(timers.size,0);assert.equal(elements['sound-cache-status'].textContent,'声音已准备好');
});

test('ordinary browsers keep the native cache status hidden',()=>{
  const state=boot(100,false);
  assert.equal(state.preloads,0);assert.equal(state.timers.size,0);
  assert.equal(state.elements['intro-audio-status'].hidden,true);
  assert.equal(state.elements['sound-cache-status'].hidden,true);
});
