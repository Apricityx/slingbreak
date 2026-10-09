/* Optional host capability. No UA, device, or platform detection. */
(() => {
  'use strict';
  window.createSlingNativeAudio=({intervals,log,onReady,canOutput=()=>true})=>{
    const host=window.SlingNativeAudio,Offline=window.OfflineAudioContext||window.webkitOfflineAudioContext;
    if(!host||!Offline)return null;
    let capabilities=null;
    try{if(typeof host.capabilities==='function')capabilities=JSON.parse(host.capabilities());}catch{}
    const fullPlayback=capabilities?.version===2&&capabilities.gain&&capabilities.ui;
    const musicPlayback=fullPlayback&&capabilities.music;
    const backend=fullPlayback?'native-audiotrack':'native-aaudio';
    const preparationTimeoutMs=120000;
    let state='idle',session=0,rate=0,info=null,preparationTimer=null,generation=0;
    const pending=[];
    const effectData=new Map();let cacheRate=0,preparing=null,lastError=null;
    const loading={completed:0,rendered:0,total:0,phase:'idle'};
    const synthesis=[];let synthesizing=false;
    let warming=0,warmVersion=0;
    const dispatch=[];let dispatchTimer=null;
    const musicCache=new Map();let musicId=0,musicGeneration=0,musicSuspended=false,musicBytes=0;
    const musicByteLimit=64*1024*1024;
    const batched=fullPlayback&&capabilities.batch===true&&typeof host.playBatch==='function';
    function armPreparationTimeout(){
      clearTimeout(preparationTimer);
      if(state==='preparing'&&!document.hidden)preparationTimer=setTimeout(()=>fail(Error(`Native preparation stalled for ${preparationTimeoutMs}ms`)),preparationTimeoutMs);
    }
    function cancelDispatch(){clearTimeout(dispatchTimer);dispatchTimer=null;dispatch.length=0;}
    function queueDispatch(request){
      if(dispatch.length>=96){
        if(request.priority){const victim=dispatch.findIndex(r=>!r.music&&!r.priority&&r.ui===request.ui);if(victim>=0)dispatch.splice(victim,1);else return;}
        else{log('sound-skipped',{reason:'native-queue-full',backend});return;}
      }
      dispatch.push(request);
      if(dispatchTimer===null)dispatchTimer=setTimeout(flush,0);
    }
    function flush(){
      dispatchTimer=null;
      if(state!=='ready'){dispatch.length=0;return;}
      const requests=dispatch.splice(0),now=performance.now();
      const valid=requests.filter(r=>canOutput()&&Game.state.sound&&Game.state.volume>0&&!document.hidden&&
        (r.music?r.epoch===musicGeneration&&!Game.paused&&now-r.at<=200:(!Game.paused||r.ui)&&now-r.at<500));
      if(!valid.length)return;
      try{
        const encoded=valid.map(r=>r.music?{music:true,id:r.id,delay:Math.max(0,(r.at-now)/1000),pan:r.pan,volume:r.vol,bus:r.bus,wet:r.echo}:
          {ui:r.ui,priority:r.priority,voices:r.voices.map(v=>({...v,delay:Math.max(0,v.delay-(now-r.at)/1000)}))});
        const results=JSON.parse(host.playBatch(session,JSON.stringify(encoded)));
        if(!Array.isArray(results)||results.length!==valid.length)throw Error('Invalid batch response');
        for(let i=0;i<results.length;i++){
          const r=valid[i],result=results[i];
          if(result===-2&&r.music){
            const entry=r.entry;
            if(!host.uploadMusic(session,entry.id,entry.encoded))throw Error('Native music reupload rejected');
            entry.uploaded=true;
            if(performance.now()-r.at>200)continue;
            const retry=host.playMusic(session,r.id,Math.max(0,(r.at-performance.now())/1000),r.pan,r.vol,r.bus,r.echo);
            if(retry<0)throw Error('Native music retry rejected: '+retry);
          }else if(!Number.isInteger(result)||result<0||result>1)throw Error('Native batch request rejected: '+result);
          else if(result===0)log('sound-skipped',{reason:'native-busy-or-muted',backend});
        }
      }catch(error){fail(error);}
    }
    async function drainSynthesis(){
      if(synthesizing)return;
      synthesizing=true;
      try{
        while(synthesis.length){
          const job=synthesis.shift();
          if(job.current!==generation||musicCache.get(job.key)!==job.entry){job.resolve(null);continue;}
          try{const data=await window.SlingRenderMusicVoice(rate,job.shape);job.resolve(job.current===generation?data:null);}catch(error){job.reject(error);}
          if(synthesis.length)await new Promise(resolve=>setTimeout(resolve,0));
        }
      }finally{synthesizing=false;}
    }
    function musicEntry(shape,urgent=false){
      const k=JSON.stringify(shape);let entry=musicCache.get(k);
      if(!entry){
        if(musicCache.size>=128)evictMusic();
        for(let i=synthesis.length-1;i>=0;i--)if(musicCache.get(synthesis[i].key)!==synthesis[i].entry){synthesis[i].resolve(null);synthesis.splice(i,1);}
        entry={id:musicId++};
        const current=generation;
        entry.data=new Promise((resolve,reject)=>{
          const job={shape,current,resolve,reject,key:k,entry};
          if(urgent)synthesis.unshift(job);else synthesis.push(job);
        }).then(data=>{
          if(data)entry.encoded=data;
          if(data&&musicCache.get(k)===entry){
            entry.bytes=Math.floor(data.length*3/4);musicBytes+=entry.bytes;
            while(musicCache.size&&musicBytes>musicByteLimit)evictMusic();
          }
          return data;
        },error=>{
          if(musicCache.get(k)===entry){musicCache.delete(k);}
          throw error;
        });
        musicCache.set(k,entry);drainSynthesis();
      }else{
        musicCache.delete(k);musicCache.set(k,entry);
        if(urgent){const index=synthesis.findIndex(job=>job.entry===entry);if(index>0)synthesis.unshift(synthesis.splice(index,1)[0]);}
      }
      return entry;
    }
    async function warmMusic(options){
      if(!musicPlayback||state!=='ready')return false;
      const current=generation,epoch=musicGeneration;
      const version=++warmVersion;
      warming++;
      try{
        for(const optionsForVoice of options){
          if(current!==generation||epoch!==musicGeneration||version!==warmVersion||state!=='ready'||document.hidden)return false;
          const {pan,vol,echo,...shape}=optionsForVoice,entry=musicEntry(shape);
          const data=await entry.data;
          if(current!==generation||epoch!==musicGeneration||version!==warmVersion||state!=='ready'||document.hidden||!data)return false;
          if(!entry.uploaded){if(!host.uploadMusic(session,entry.id,data))throw Error('Native music warmup upload rejected');entry.uploaded=true;}
          await new Promise(resolve=>setTimeout(resolve,0));
        }
        return true;
      }catch(error){if(current===generation&&epoch===musicGeneration&&version===warmVersion)fail(error);return false;}
      finally{warming--;}
    }
    function evictMusic(){
      const k=musicCache.keys().next().value,entry=musicCache.get(k);
      musicBytes-=entry.bytes||0;musicCache.delete(k);
    }
    const samples=new Map(),last=new Map();
    const describe=voice=>{
      if(voice.kind==='tone'){
        const [delay,freq,end,duration,volume,wave='sine',x=390,wet=false]=voice.args;
        return {kind:'tone',delay,freq,end,duration,volume,wave,x,wet};
      }
      const [delay,duration,volume,freq,filter='highpass',x=390,end=freq]=voice.args;
      return {kind:'noise',delay,duration,volume,freq,filter,x,end,wet:false};
    };
    const key=v=>JSON.stringify([v.kind,v.freq,v.end,v.duration,v.volume,v.wave||v.filter]);
    function fail(error){
      if(state==='closed'||state==='failed')return;
      clearTimeout(preparationTimer);
      cancelDispatch();lastError=String(error);
      const cacheEntries=musicCache.size;
      state='failed';last.clear();
      try{host.release(session);}catch{}
      pending.length=0;samples.clear();++generation;
      while(synthesis.length)synthesis.shift().resolve(null);
      musicCache.clear();musicBytes=0;++musicGeneration;
      log(fullPlayback?'native-error':'native-fallback',{error:lastError,session,generation,cacheEntries});
      // Legacy hosts restore Web Audio; version-2 hosts keep output native-only.
      Game.audio?.sync();
    }
    async function render(v,noise,current){
      const ctx=new Offline(1,Math.ceil(rate*(v.duration+.025)),rate);
      const envelope=ctx.createGain();
      envelope.gain.setValueAtTime(.0001,0);
      envelope.gain.linearRampToValueAtTime(v.volume,.003);
      envelope.gain.exponentialRampToValueAtTime(.0001,v.duration);
      envelope.connect(ctx.destination);
      let source;
      if(v.kind==='tone'){
        source=ctx.createOscillator();source.type=v.wave;
        source.frequency.setValueAtTime(v.freq,0);
        source.frequency.exponentialRampToValueAtTime(Math.max(20,v.end),v.duration);
        source.connect(envelope);
      }else{
        source=ctx.createBufferSource();
        const buffer=ctx.createBuffer(1,noise.length,rate);buffer.getChannelData(0).set(noise);
        source.buffer=buffer;source.loop=true;
        const filter=ctx.createBiquadFilter();filter.type=v.filter;filter.Q.value=.7;
        filter.frequency.setValueAtTime(v.freq,0);
        filter.frequency.exponentialRampToValueAtTime(Math.max(30,v.end),v.duration);
        source.connect(filter);filter.connect(envelope);
      }
      source.start();source.stop(v.duration+.025);
      const pcm=(await ctx.startRendering()).getChannelData(0);
      if(generation!==current)return null;
      if(window.SlingEncodePCM)return window.SlingEncodePCM(pcm);
      const bytes=new Uint8Array(pcm.length*4),view=new DataView(bytes.buffer);
      for(let i=0;i<pcm.length;i++)view.setFloat32(i*4,pcm[i],true);
      let binary='';for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
      return btoa(binary);
    }
    function prepare(){
      if(state==='preparing')return preparing;
      if(state!=='idle')return Promise.resolve();
      preparing=prepareSession();return preparing;
    }
    async function prepareSession(){
      state='preparing';
      const current=++generation;
      armPreparationTimeout();
      try{
        info=JSON.parse(host.begin());
        if(info.version!==1||!info.session||!info.sampleRate)throw Error(info.error||'Unsupported host');
        session=info.session;rate=info.sampleRate;
        lastError=null;
        if(cacheRate!==rate){effectData.clear();musicCache.clear();musicBytes=0;cacheRate=rate;}
        const recipes=[];
        for(const type of window.SlingSoundTypes||['shoot','tap','boom','ricochet','lightning','frost','prism','gold','core','win','upgrade'])if(type!=='draw'&&type!=='break'&&type!=='pick')recipes.push(window.SlingSoundRecipe(type));
        for(let n=0;n<=5;n++)recipes.push(window.SlingSoundRecipe('draw',n));
        for(let n=0;n<=2;n++)recipes.push(window.SlingSoundRecipe('pick',n));
        for(let n=1;n<=17;n+=2)recipes.push(window.SlingSoundRecipe('break',n));
        const noise=new Float32Array(Math.ceil(rate*.25));
        for(let i=0;i<noise.length;i++)noise[i]=Math.random()*2-1;
        const unique=new Map();for(const recipe of recipes)for(const voice of recipe){const v=describe(voice);unique.set(key(v),v);}
        loading.total=unique.size;loading.completed=0;loading.rendered=0;loading.phase='effects';
        for(const [k,v] of unique){
          const id=samples.size,known=effectData.get(k),data=known||await render(v,noise,current);
          if(state!=='preparing'||generation!==current)return;
          if(!known)loading.rendered++;
          if(!host.upload(session,id,data))throw Error('Native sample upload rejected');
          effectData.set(k,data);samples.set(k,id);loading.completed++;
          armPreparationTimeout();
          // Yield between uploads; no synthesis or PCM transfer on the impact path.
          await new Promise(resolve=>setTimeout(resolve,0));
        }
        if(state!=='preparing'||generation!==current)return;
        if(!host.commit(session))throw Error('Native stream start failed');
        clearTimeout(preparationTimer);
        loading.phase='ready';state='ready';onReady();sync();
        const queued=pending.splice(0);
        for(const request of queued)if(performance.now()-request.at<500)play(...request.args);
        log('native-ready',{samples:samples.size,audio:snapshot()});
      }catch(error){if(generation===current)fail(error);}
    }
    function disable(){
      if(state==='idle'||state==='closed')return;
      ++generation;
      while(synthesis.length)synthesis.shift().resolve(null);
      clearTimeout(preparationTimer);
      cancelDispatch();
      // Muting alone leaves the native stream and its render thread running.
      try{if(session)host.release(session);}catch{}
      state='idle';session=0;rate=0;info=null;samples.clear();last.clear();pending.length=0;
      for(const [k,entry] of musicCache){entry.uploaded=false;if(!entry.encoded){musicCache.delete(k);}}
      musicSuspended=false;++musicGeneration;
    }
    function snapshot(){
      let hostState=null;
      if(session&&state==='ready')try{hostState=JSON.parse(host.snapshot(session));}catch{}
      return {backend,state,session,sampleRate:rate,loading:{...loading,music:warming>0,synthesisQueued:synthesis.length},lastError,batch:batched,queued:dispatch.length,musicCache:{entries:musicCache.size,bytes:musicBytes},host:hostState||info};
    }
    function sync(){
      if(state!=='ready')return;
      try{
        const silent=!canOutput()||!Game.state.sound||document.hidden||(!fullPlayback&&(Game.state.volume!==100||Game.paused));
        if(fullPlayback){
          if(!host.setState(session,Game.state.volume/100,silent,!!Game.paused))throw Error('Native stream unavailable');
          const suspended=silent||Game.paused;
          if(suspended)for(let i=dispatch.length-1;i>=0;i--)if(silent||!dispatch[i].ui)dispatch.splice(i,1);
          if(suspended&&!musicSuspended)musicMix({},18000,true);
          musicSuspended=suspended;
        }else if(!host.setMuted(session,silent))throw Error('Native stream unavailable');
        if(silent)last.clear();
      }catch(error){fail(error);}
    }
    function play(type,n,x,priority,soundId,ui=false){
      if(state!=='ready'){
        if(fullPlayback&&state==='preparing'){
          if(pending.length===24)pending.shift();
          pending.push({at:performance.now(),args:[type,n,x,priority,soundId,ui]});
        }
        return !!fullPlayback;
      }
      try{
        if(!Number.isFinite(n)||!Number.isFinite(x))return true;
        const voices=window.SlingSoundRecipe(type,n,x).map(describe);
        if(!voices.length)return true;
        const encoded=voices.map(v=>({id:samples.get(key(v)),delay:v.delay,pan:Math.max(-.65,Math.min(.65,(v.x-390)/520)),wet:v.wet}));
        // Unknown parameters are reported; version-2 hosts retain native-only output.
        if(encoded.some(v=>v.id===undefined))throw Error('Uncached sound parameters');
        const requestKey=ui?'ui:'+type:type;
        const now=performance.now(),intervalMs=(intervals[type]||0)*1000,elapsedMs=now-(last.get(requestKey)??-Infinity);
        if(!priority&&elapsedMs<intervalMs){log('sound-skipped',{soundId,type,reason:'rate-limit',clock:'performance.now',elapsedMs,intervalMs,backend});return true;}
        if(batched){
          queueDispatch({ui,priority,voices:encoded,at:now});
          if(!priority)last.set(requestKey,now);
          return true;
        }
        const result=host.play(session,JSON.stringify({type,priority,ui,voices:encoded}));
        if(result<0)throw Error('Native playback unavailable: '+result);
        if(result===0){log('sound-skipped',{soundId,type,reason:'native-busy-or-muted',backend});return true;}
        if(!priority)last.set(requestKey,now);
        log('native-sound-enqueued',{soundId,type,voices:voices.length,backend});
        return true;
      }catch(error){fail(error);return !!fullPlayback;}
    }
    async function musicVoice(bus,at,options){
      if(!musicPlayback||state!=='ready')return;
      const current=generation,epoch=musicGeneration;
      const {pan=0,vol=.2,echo=false,...shape}=options;
      try{
        const entry=musicEntry(shape,true);
        const data=await entry.data;
        if(!data||current!==generation||epoch!==musicGeneration||state!=='ready'||!canOutput()||!Game.state.sound||Game.state.volume===0||Game.paused||document.hidden)return;
        if(performance.now()-at>200)return;
        if(!entry.uploaded){if(!host.uploadMusic(session,entry.id,data))throw Error('Native music upload rejected');entry.uploaded=true;}
        if(performance.now()-at>200)return;
        if(batched){queueDispatch({music:true,id:entry.id,entry,bus,at,pan,vol,echo,epoch});return;}
        let result=host.playMusic(session,entry.id,Math.max(0,(at-performance.now())/1000),pan,vol,bus,echo);
        if(result===-2){if(!host.uploadMusic(session,entry.id,data))throw Error('Native music reupload rejected');if(performance.now()-at>200)return;result=host.playMusic(session,entry.id,Math.max(0,(at-performance.now())/1000),pan,vol,bus,echo);}
        if(result<0)throw Error('Native music playback unavailable');
      }catch(error){if(current===generation&&epoch===musicGeneration)fail(error);}
    }
    function musicMix(levels,cutoff,stop=false){
      if(stop){++musicGeneration;for(let i=dispatch.length-1;i>=0;i--)if(dispatch[i].music)dispatch.splice(i,1);}
      if(musicPlayback&&state==='ready')try{if(!host.musicState(session,JSON.stringify(levels),cutoff,stop))throw Error('Native music state rejected');}catch(error){fail(error);}
    }
    function musicFade(target,seconds){
      if(musicPlayback&&state==='ready')try{if(!host.musicFade(session,target,seconds))throw Error('Native music fade rejected');}catch(error){fail(error);}
    }
    document.addEventListener('visibilitychange',()=>{armPreparationTimeout();sync();});
    window.addEventListener('pagehide',()=>{disable();effectData.clear();musicCache.clear();musicBytes=0;state='closed';});
    return {fullPlayback,musicPlayback,get ready(){return state==='ready';},get outputEnabled(){return canOutput();},get musicEpoch(){return musicGeneration;},prepare,play,sync,disable,snapshot,musicVoice,musicMix,musicFade,warmMusic};
  };
})();
