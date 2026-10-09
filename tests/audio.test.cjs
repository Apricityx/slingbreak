const ROOT=require('node:path').resolve(__dirname,'..');
const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');

const audioSource=fs.readFileSync(ROOT+'/game/src/audio/audio.js','utf8');
const nativeSource=fs.readFileSync(ROOT+'/game/src/audio/audio-native.js','utf8');
function boot(volume,fullPlayback=false){
  const contexts=[],native={fullPlayback,prepared:0,disabled:0,ready:false,
    prepare(){this.prepared++;},disable(){this.disabled++;this.ready=false;},sync(){},play(){return false;}};
  const param=()=>({value:0,cancelScheduledValues(){},setTargetAtTime(v){this.value=v;},setValueAtTime(v){this.value=v;},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}});
  class AudioContext {
     constructor(){this.state='running';this.currentTime=0;this.sampleRate=44100;this.destination={};this.master=null;this.closed=false;this.stopped=0;this.nodes=[];contexts.push(this);}
     node(extra={}){const node={connections:[],stops:[],connect(target){this.connections.push(target);},disconnect(){},start(){},stop:(t)=>{this.stopped++;node.stops.push(t);},...extra};this.nodes.push(node);return node;}
    createGain(){const node=this.node({gain:param()});this.master??=node;return node;}
    createWaveShaper(){return this.node();}
    createDelay(){return this.node({delayTime:param()});}
    createConstantSource(){return this.node();}
    createBuffer(channels,length){return {getChannelData:()=>new Float32Array(length)};}
    createOscillator(){return this.node({frequency:param()});}
    createStereoPanner(){return this.node({pan:param()});}
    close(){this.closed=true;this.state='closed';return Promise.resolve();}
  }
  const G={state:{sound:volume>0,volume},paused:false};
  const window={AudioContext,createSlingNativeAudio:()=>native,SlingSoundRecipe:()=>[{kind:'tone',args:[0,440,220,.1,.2]}]};
   const listeners={},document={hidden:false,addEventListener(type,handler){listeners[type]=handler;}};
  const ctx={Game:G,window,document,performance:{now:()=>0},Float32Array,Math,console};
  vm.createContext(ctx);vm.runInContext(audioSource,ctx);
   return {G,contexts,native,document,listeners};
}

test('zero volume never creates audio or prepares native samples',()=>{
  const {G,contexts,native}=boot(0);
  G.audio.unlock();G.sound('shoot');G.audio.sync();
  assert.equal(contexts.length,0);
  assert.equal(native.prepared,0);
});

test('version-2 native owns all volumes, preparation and paused UI output without realtime Web Audio',()=>{
  const {G,contexts,native,document}=boot(35,true);
  G.audio.unlock();G.sound('shoot');assert.equal(contexts.length,0);
  native.ready=true;
  const requests=[];native.play=(...args)=>{requests.push(args);return true;};
  G.sound('forge');G.paused=true;G.audio.sync();G.audio.cue('deal');G.sound('shoot');
  assert.equal(contexts.length,0);assert.equal(native.disabled,0);
  assert.equal(requests.length,2);assert.equal(requests[1][5],true);
  G.state.volume=70;G.audio.sync();assert.equal(native.ready,true);
  document.hidden=true;G.audio.cue('gold');assert.equal(requests.length,2);
  G.state.volume=0;G.audio.sync();assert.equal(native.ready,false);
});

test('partial volume scales Web Audio and zero releases its context immediately',()=>{
  const {G,contexts,native}=boot(100);
  G.audio.unlock();assert.equal(native.prepared,1);
  assert.equal(contexts.length,1);
  G.state.volume=35;G.audio.sync();G.sound('shoot');
  assert.equal(native.disabled>0,true);
  assert.ok(Math.abs(contexts[0].master.gain.value-.245)<1e-10);
  G.state.volume=0;G.state.sound=false;G.audio.sync();
  assert.equal(contexts[0].closed,true);
  assert.ok(contexts[0].stopped>0,'sources and keep-alive stop');
  G.sound('shoot');G.audio.unlock();
  assert.equal(contexts.length,1,'no new audio work at zero');
  G.state.volume=60;G.state.sound=true;G.audio.unlock();
  assert.equal(contexts.length,2,'audio can resume after leaving zero');
  assert.ok(Math.abs(contexts[1].master.gain.value-.42)<1e-10);
});

test('native backend is released when volume changes away from 100',()=>{
  const {G,contexts,native}=boot(100);
  native.ready=true;G.audio.unlock();
  assert.equal(contexts.length,0);
  G.state.volume=70;G.audio.sync();G.audio.unlock();
  assert.equal(native.ready,false);
  assert.equal(contexts.length,1);
  G.state.volume=0;G.state.sound=false;G.audio.sync();
  assert.equal(contexts[0].closed,true);
});

test('dialog cues play in full on an isolated bus while gameplay stays paused',()=>{
  const {G,contexts}=boot(60);
  G.audio.unlock();G.sound('shoot');
  const ctx=contexts[0],game=ctx.nodes.find(node=>node.effectType==='shoot');
  G.paused=true;G.audio.sync();
  G.audio.cue('deal');
  const cue=ctx.nodes.find(node=>node.effectType==='deal');
  assert.equal(G.paused,true,'a cue never changes simulation pause');
  assert.equal(ctx.master.gain.value,0,'gameplay bus remains muted');
  assert.deepEqual(game.stops,[.125,.04],'pause stops the gameplay voice');
  assert.deepEqual(cue.stops,[.125],'cue retains its full scheduled envelope');
  const uiBus=cue.connections[0].connections[0].connections[0];
  assert.notEqual(uiBus,game.connections[0].connections[0].connections[0]);
  assert.equal(uiBus.connections[0].gain.value,.42,'UI bus uses the configured volume');
  G.audio.sync();
  assert.deepEqual(cue.stops,[.125],'repeated pause sync does not truncate UI voices');
  G.sound('shoot');
  assert.equal(ctx.nodes.filter(node=>node.effectType==='shoot').length,1,'no gameplay synthesis while paused');
  G.state.volume=30;G.audio.sync();
  assert.equal(uiBus.connections[0].gain.value,.21);
  G.state.volume=0;G.audio.sync();G.audio.cue('deal');
  assert.equal(ctx.closed,true);assert.equal(contexts.length,1);
});

test('dialog cues respect mute and visibility, and pause sync preserves UI rate limits',()=>{
  const muted=boot(0);muted.G.audio.cue('deal');
  assert.equal(muted.contexts.length,0);assert.equal(muted.native.prepared,0);
  const {G,contexts,document,listeners}=boot(50);G.paused=true;
  document.hidden=true;G.audio.cue('deal');assert.equal(contexts.length,0);
  document.hidden=false;G.audio.cue('tick');G.audio.sync();G.audio.cue('tick');
  const ctx=contexts[0],cue=ctx.nodes.find(node=>node.effectType==='tick');
  assert.equal(ctx.nodes.filter(node=>node.effectType==='tick').length,1);
  document.hidden=true;listeners.visibilitychange();
  assert.deepEqual(cue.stops,[.125,.04],'backgrounding stops UI cues too');
});

test('dialog cues do not unmute or disable a ready native gameplay backend',()=>{
  const {G,contexts,native}=boot(100);native.ready=true;G.paused=true;
  let nativePlays=0;native.play=()=>{nativePlays++;return true;};
  G.audio.cue('gold');G.audio.sync();
  assert.equal(G.paused,true);assert.equal(native.ready,true);assert.equal(native.disabled,0);
  assert.equal(nativePlays,0,'paused UI cues do not use globally muted native playback');
  assert.equal(contexts.length,1);assert.equal(contexts[0].closed,false);
  const cue=contexts[0].nodes.find(node=>node.effectType==='gold');
  assert.deepEqual(cue.stops,[.125]);
  G.paused=false;G.audio.sync();G.sound('shoot');
  assert.equal(nativePlays,1,'gameplay still uses native audio after the dialog');
  cue.onended();G.audio.sync();assert.equal(contexts[0].closed,true);
});

test('disabling native audio cancels sample preparation and releases its stream',async()=>{
  let finishRender,uploads=0,commits=0,releases=0;
  const pending=new Promise(resolve=>{finishRender=resolve;});
  const param=()=>({setValueAtTime(){},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}});
  class OfflineAudioContext {
    constructor(){this.destination={};}
    createGain(){return {gain:param(),connect(){}};}
    createOscillator(){return {frequency:param(),connect(){},start(){},stop(){}};}
    startRendering(){return pending;}
  }
  const host={begin:()=>JSON.stringify({version:1,session:7,sampleRate:44100}),
    release:()=>{releases++;},upload:()=>{uploads++;return true;},commit:()=>{commits++;return true;}};
  const window={SlingNativeAudio:host,OfflineAudioContext,
    SlingSoundRecipe:()=>[{kind:'tone',args:[0,440,220,.1,.2]}],addEventListener(){}};
  const ctx={window,Game:{state:{sound:true,volume:100},paused:false},document:{addEventListener(){}},
    setTimeout:()=>1,clearTimeout(){},Float32Array,console};
  vm.createContext(ctx);vm.runInContext(nativeSource,ctx);
  const native=window.createSlingNativeAudio({intervals:{},log(){},onReady(){}});
  const preparing=native.prepare();
  native.disable();
  finishRender({getChannelData:()=>new Float32Array(10)});
  await preparing;
  assert.equal(releases,1);
  assert.equal(uploads,0);assert.equal(commits,0);
  assert.equal(native.snapshot().state,'idle');
});
