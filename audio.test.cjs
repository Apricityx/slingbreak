const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');

const audioSource=fs.readFileSync(__dirname+'/audio.js','utf8');
const nativeSource=fs.readFileSync(__dirname+'/audio-native.js','utf8');
function boot(volume){
  const contexts=[],native={prepared:0,disabled:0,ready:false,
    prepare(){this.prepared++;},disable(){this.disabled++;this.ready=false;},sync(){},play(){return false;}};
  const param=()=>({value:0,cancelScheduledValues(){},setTargetAtTime(v){this.value=v;},setValueAtTime(v){this.value=v;},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}});
  class AudioContext {
    constructor(){this.state='running';this.currentTime=0;this.sampleRate=44100;this.destination={};this.master=null;this.closed=false;this.stopped=0;contexts.push(this);}
    node(extra={}){return {connect(){},disconnect(){},start(){},stop:()=>{this.stopped++;},...extra};}
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
  const document={hidden:false,addEventListener(){}};
  const ctx={Game:G,window,document,performance:{now:()=>0},Float32Array,Math,console};
  vm.createContext(ctx);vm.runInContext(audioSource,ctx);
  return {G,contexts,native};
}

test('zero volume never creates audio or prepares native samples',()=>{
  const {G,contexts,native}=boot(0);
  G.audio.unlock();G.sound('shoot');G.audio.sync();
  assert.equal(contexts.length,0);
  assert.equal(native.prepared,0);
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
