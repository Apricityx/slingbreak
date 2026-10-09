const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'game/src/audio/audio-native.js'),'utf8');
const bossSource=fs.readFileSync(path.join(root,'game/src/bosses/boss-music.js'),'utf8');

async function boot(render=async()=> 'AAAAAA==',batch=false,recipe=[]){
  const calls=[],logs=[];let now=1000,session=0;
  const host={
    capabilities:()=>JSON.stringify({version:2,gain:true,ui:true,music:true,batch}),
    begin:()=>JSON.stringify({version:1,session:++session,sampleRate:48000}),
    commit:()=>true,upload:()=>true,setState:(...args)=>{calls.push(['state',...args]);return true;},release:()=>calls.push(['release']),
    snapshot:()=> '{}',uploadMusic:(...args)=>{calls.push(['upload',...args]);return true;},
    playMusic:(...args)=>{calls.push(['play',...args]);return 1;},
    musicState:(...args)=>{calls.push(['mix',...args]);return true;},
    musicFade:(...args)=>{calls.push(['fade',...args]);return true;}
  };
  if(batch)host.playBatch=(token,json)=>{const requests=JSON.parse(json);calls.push(['batch',token,requests]);return JSON.stringify(requests.map(()=>1));};
  const G={state:{sound:true,volume:35},paused:false,audio:{sync(){}}};
  const document={hidden:false,addEventListener(){}};
   const param=()=>({setValueAtTime(){},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}});
   const window={SlingNativeAudio:host,OfflineAudioContext:class {
     constructor(){this.destination={};}
     createGain(){return {gain:param(),connect(){}};}
     createOscillator(){return {frequency:param(),connect(){},start(){},stop(){}};}
     startRendering(){return Promise.resolve({getChannelData:()=>new Float32Array(1)});}
   },SlingSoundTypes:['tap'],SlingSoundRecipe:()=>recipe,SlingEncodePCM:async()=> 'AAAAAA==',
     SlingRenderMusicVoice:render,addEventListener(){}};
   const context={window,Game:G,document,performance:{now:()=>now},setTimeout:(fn,ms)=>ms<100?setTimeout(fn,ms):1,clearTimeout};
  vm.createContext(context);vm.runInContext(source,context);
  const native=window.createSlingNativeAudio({intervals:{},log:(...args)=>logs.push(args),onReady(){}});
  await native.prepare();
  return {native,host,G,document,calls,logs,setTime:value=>{now=value;}};
}

test('music caches shapes separately from gain and pan, and repairs native eviction',async()=>{
  let renders=0;
  const {native,host,calls}=await boot(async()=>{renders++;return 'AAAAAA==';});
  assert.equal(native.musicPlayback,true);
  await native.musicVoice('pad',1100,{freq:220,vol:.1,pan:-.5});
  let evicted=true;
  host.playMusic=(...args)=>{calls.push(['play',...args]);if(evicted){evicted=false;return -2;}return 1;};
  await native.musicVoice('lead',1100,{freq:220,vol:.2,pan:.5});
  assert.equal(renders,1);
  assert.equal(calls.filter(c=>c[0]==='upload').length,2);
  assert.equal(calls.filter(c=>c[0]==='play').length,3);
  assert.equal(native.snapshot().state,'ready');
});

test('pending music cannot cross pause, background, stop or audio session boundaries',async()=>{
  for(const action of ['pause','background','stop','session']){
    let finish;
    const {native,G,document,calls}=await boot(()=>new Promise(resolve=>{finish=resolve;}));
    const pending=native.musicVoice('pad',1100,{freq:220});
    if(action==='pause'){G.paused=true;native.sync();G.paused=false;native.sync();}
    if(action==='background'){document.hidden=true;native.sync();document.hidden=false;native.sync();}
    if(action==='stop')native.musicMix({},18000,true);
    if(action==='session'){native.disable();await native.prepare();}
    finish('AAAAAA==');await pending;
    assert.equal(calls.filter(c=>c[0]==='play').length,0,action);
    assert.equal(native.snapshot().state,'ready',action);
  }
});

test('late notes drop and current synthesis errors stop native output without fallback',async()=>{
  let finish;
  const {native,calls,setTime}=await boot(()=>new Promise(resolve=>{finish=resolve;}));
  const pending=native.musicVoice('pad',1100,{freq:220});
  setTime(1400);finish('AAAAAA==');await pending;
  assert.equal(calls.filter(c=>c[0]==='play').length,0);
  const failed=await boot(async()=>{throw Error('synthesis failed');});
  await failed.native.musicVoice('pad',1100,{freq:220});
  assert.equal(failed.native.snapshot().state,'failed');
  assert.equal(failed.logs[failed.logs.length-1][0],'native-error');
});

test('music cache remains bounded across mute and is reuploaded without resynthesis',async()=>{
  let renders=0;
  const {native,calls}=await boot(async()=>{renders++;return 'AAAAAA==';});
  for(let n=0;n<140;n++)await native.musicVoice('pad',1100,{freq:220+n});
  assert.equal(native.snapshot().musicCache.entries,128);
  native.disable();
  assert.equal(native.snapshot().musicCache.entries,128);
  assert.equal(native.snapshot().musicCache.bytes,768);
  await native.prepare();
  const before=calls.filter(c=>c[0]==='upload').length;
  await native.musicVoice('pad',1100,{freq:359});
  assert.equal(renders,140);
  assert.equal(calls.filter(c=>c[0]==='upload').length,before+1);
});

test('warmup renders one voice at a time and uploads without playback',async()=>{
  let active=0,max=0,renders=0;
  const {native,calls}=await boot(async()=>{active++;max=Math.max(max,active);renders++;await new Promise(resolve=>setTimeout(resolve,1));active--;return 'AAAAAA==';});
  await native.warmMusic([{freq:220},{freq:330},{freq:220,vol:.1,pan:-.5}]);
  assert.equal(max,1);assert.equal(renders,2);
  assert.equal(calls.filter(c=>c[0]==='play').length,0);
  assert.equal(calls.filter(c=>c[0]==='upload').length,2);
  await native.musicVoice('pad',1100,{freq:220});
  assert.equal(renders,2);
  assert.equal(calls.filter(c=>c[0]==='upload').length,2);
});

test('batch bridge coalesces notes, repairs eviction and cancels queued old epochs',async()=>{
  const {native,host,calls,G,setTime}=await boot(undefined,true);
  await native.musicVoice('pad',1100,{freq:220});
  await native.musicVoice('lead',1120,{freq:330});
  assert.equal(calls.filter(c=>c[0]==='batch').length,0);
  setTime(1020);
  await new Promise(resolve=>setTimeout(resolve,5));
  const batch=calls.find(c=>c[0]==='batch')[2];
  assert.equal(batch.length,2);assert.equal(batch[0].delay,.08);assert.equal(batch[1].delay,.1);
  host.playBatch=(token,json)=>{calls.push(['batch',token,JSON.parse(json)]);return '[-2]';};
  await native.musicVoice('pad',1100,{freq:220});
  await new Promise(resolve=>setTimeout(resolve,5));
  assert.equal(calls.filter(c=>c[0]==='upload').length,3);
  assert.equal(calls.filter(c=>c[0]==='play').length,1);
  const before=calls.length;
  await native.musicVoice('pad',1100,{freq:220});native.musicMix({},18000,true);
  await new Promise(resolve=>setTimeout(resolve,5));
  assert.equal(calls.slice(before).filter(c=>c[0]==='batch').length,0);
  await native.musicVoice('pad',1100,{freq:220});G.paused=true;native.sync();
  await new Promise(resolve=>setTimeout(resolve,5));
  assert.equal(calls.slice(before).filter(c=>c[0]==='batch').length,0);
});

test('queued batch expires late notes and bounds overload before crossing the bridge',async()=>{
  const {native,calls,setTime}=await boot(undefined,true);
  for(let n=0;n<120;n++)await native.musicVoice('pad',1100,{freq:220});
  assert.equal(native.snapshot().queued,96);
  setTime(1400);await new Promise(resolve=>setTimeout(resolve,5));
  assert.equal(calls.filter(c=>c[0]==='batch').length,0);
});

test('effect batches preserve priority, UI isolation and relative delays on pause',async()=>{
  const {native,calls,G,setTime}=await boot(undefined,true,[{kind:'tone',args:[.1,440,220,.1,.2]}]);
  native.play('tap',1,390,false,1);
  native.play('tap',1,390,true,2);
  native.play('tap',1,390,false,3,true);
  assert.equal(calls.filter(c=>c[0]==='batch').length,0);
  setTime(1020);await new Promise(resolve=>setTimeout(resolve,5));
  const batch=calls.find(c=>c[0]==='batch')[2];
  assert.equal(batch.length,3);assert.equal(batch[0].voices[0].delay,.08);
  assert.equal(batch[1].priority,true);assert.equal(batch[2].ui,true);
  native.play('tap',1,390,true,4);native.play('tap',1,390,false,5,true);
  G.paused=true;native.sync();await new Promise(resolve=>setTimeout(resolve,5));
  const last=calls.filter(c=>c[0]==='batch').pop()[2];
  assert.equal(last.length,1);assert.equal(last[0].ui,true);
});

test('preloaded output stays silent until explicitly unlocked',async()=>{
  const {native,calls}=await boot();
  // The full audio module supplies this gate; verify it without a realtime context.
  let unlocked=false;
  const sourceContext={window:{},Game:{state:{sound:true,volume:100}},document:{hidden:false,addEventListener(){}}};
  sourceContext.window={SlingNativeAudio:{capabilities:()=>'{"version":2,"gain":true,"ui":true,"music":true}',
    begin:()=>'{"version":1,"session":1,"sampleRate":48000}',commit:()=>true,
    setState:(token,gain,silent)=>{calls.push(['silent',silent]);return true;},musicState:()=>true},
    OfflineAudioContext:class {},SlingSoundTypes:[],SlingSoundRecipe:()=>[],addEventListener(){}};
  Object.assign(sourceContext,{setTimeout,clearTimeout});
  vm.createContext(sourceContext);vm.runInContext(source,sourceContext);
  const preloaded=sourceContext.window.createSlingNativeAudio({intervals:{},log(){},onReady(){},canOutput:()=>unlocked});
  await preloaded.prepare();assert.equal(calls.filter(c=>c[0]==='silent').pop()[1],true);
  unlocked=true;preloaded.sync();assert.equal(calls.filter(c=>c[0]==='silent').pop()[1],false);
  assert.equal(native.ready,true);
});

test('warmup completion after pause cancellation cannot upload or fail the new epoch',async()=>{
  let reject,attempt=0;
  const {native,G,calls}=await boot(()=>++attempt===1?new Promise((resolve,no)=>{reject=no;}):Promise.resolve('AAAAAA=='));
  const pending=native.warmMusic([{freq:220}]);
  G.paused=true;native.sync();G.paused=false;native.sync();
  reject(Error('cancelled synthesis'));await pending;
  assert.equal(native.snapshot().state,'ready');
  assert.equal(calls.filter(c=>c[0]==='upload').length,0);
  await native.musicVoice('pad',1100,{freq:220});
  assert.equal(native.snapshot().state,'ready');assert.equal(attempt,2);
});

test('preparation watchdog pauses while hidden and resets after every upload',async()=>{
  const timeouts=new Map(),listeners={};let sequence=0,finish;
  const param=()=>({setValueAtTime(){},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}});
  const context={window:{},Game:{state:{sound:true,volume:100}},document:{hidden:false,addEventListener:(type,fn)=>{listeners[type]=fn;}},
    setTimeout:(fn,ms)=>{const id=++sequence;if(ms<100)queueMicrotask(fn);else timeouts.set(id,{fn,ms});return id;},clearTimeout:id=>timeouts.delete(id)};
  let uploads=0;
  context.window={SlingNativeAudio:{begin:()=>'{"version":1,"session":1,"sampleRate":48000}',upload:()=>{uploads++;return true;},commit:()=>true,setMuted:()=>true},
    OfflineAudioContext:class {constructor(){this.destination={};}createGain(){return {gain:param(),connect(){}};}
      createOscillator(){return {frequency:param(),connect(){},start(){},stop(){}};}
      startRendering(){return new Promise(resolve=>{finish=()=>resolve({getChannelData:()=>new Float32Array(1)});});}},
    SlingEncodePCM:async()=> 'AAAAAA==',SlingSoundTypes:['tap'],SlingSoundRecipe:()=>[{kind:'tone',args:[0,440,220,.1,.2]}],addEventListener(){}};
  vm.createContext(context);vm.runInContext(source,context);
  const native=context.window.createSlingNativeAudio({intervals:{},log(){},onReady(){}});
  const preparing=native.prepare();assert.equal([...timeouts.values()][0].ms,120000);
  context.document.hidden=true;listeners.visibilitychange();assert.equal(timeouts.size,0);
  context.document.hidden=false;listeners.visibilitychange();assert.equal(timeouts.size,1);
  finish();await preparing;
  assert.equal(uploads,1);assert.equal(timeouts.size,0);assert.equal(native.ready,true);
});

test('chunked PCM encoder yields and preserves little-endian samples across boundaries',async()=>{
  let yields=0;
  const window={};
  const context={window,Uint8Array,DataView,btoa:binary=>Buffer.from(binary,'binary').toString('base64'),
    setTimeout:fn=>{yields++;queueMicrotask(fn);}};
  vm.createContext(context);vm.runInContext(fs.readFileSync(path.join(root,'game/src/audio/audio-music.js'),'utf8'),context);
  const pcm=Float32Array.from({length:25001},(_,i)=>Math.sin(i)*.5);
  const data=Buffer.from(await window.SlingEncodePCM(pcm),'base64');
  assert.equal(yields,2);assert.equal(data.length,pcm.length*4);
  for(let i=0;i<pcm.length;i++)assert.equal(data.readFloatLE(i*4),pcm[i]);
});

test('music cache updates LRU order on hits',async()=>{
  let renders=0;
  const {native}=await boot(async()=>{renders++;return 'AAAAAA==';});
  for(let n=0;n<128;n++)await native.musicVoice('pad',1100,{freq:220+n});
  await native.musicVoice('pad',1100,{freq:220});
  await native.musicVoice('pad',1100,{freq:999});
  await native.musicVoice('pad',1100,{freq:220});
  assert.equal(renders,129,'recently used entry survives eviction');
  await native.musicVoice('pad',1100,{freq:221});
  assert.equal(renders,130,'least recently used entry is rendered again');
});

test('boss music restores native mix after pause and session rebuild without realtime contexts',()=>{
  const calls=[];let epoch=0,now=1000;
  const native={ready:true,prepare(){},get musicEpoch(){return epoch;},
    musicVoice:(...args)=>calls.push(['voice',...args]),musicMix:(...args)=>{calls.push(['mix',...args]);if(args[2])epoch++;},
    musicFade:(...args)=>calls.push(['fade',...args])};
  const score={mix:[{pad:1}],bpm:()=>120,bars:1,events:()=>[],stab:[60],stinger:[60]};
  const G={state:{sound:true,volume:35},phase:'ready',paused:false,audio:{nativeMusic:native},
    boss:()=>({boss:'eye',phase:1,intro:true}),bossDefs:{eye:{score,music:()=>({mood:'fight'})}}};
  const document={hidden:false,addEventListener(){}};
  const context={window:{Game:G,AudioContext:class {constructor(){throw Error('realtime context');}}},document,
    performance:{now:()=>now},setInterval(){}};
  vm.createContext(context);vm.runInContext(bossSource,context);
  G.music.update();assert.equal(G.music.state.backend,'native-audiotrack');
  G.paused=true;now+=40;G.music.update();
  const before=calls.filter(c=>c[0]==='mix').length;
  G.paused=false;now+=40;G.music.update();
  assert.equal(calls.filter(c=>c[0]==='mix').length,before+1);
  epoch++;now+=40;G.music.update();
  assert.equal(calls.filter(c=>c[0]==='mix').length,before+2);
  assert.equal(calls.filter(c=>c[0]==='voice').length,0);
});
