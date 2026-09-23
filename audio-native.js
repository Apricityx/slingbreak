/* Optional host capability. No UA, device, or platform detection. */
(() => {
  'use strict';
  window.createSlingNativeAudio=({intervals,log,onReady})=>{
    const host=window.SlingNativeAudio,Offline=window.OfflineAudioContext||window.webkitOfflineAudioContext;
    if(!host||!Offline)return null;
    let state='idle',session=0,rate=0,info=null,preparationTimer=null;
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
      state='failed';last.clear();
      try{host.release(session);}catch{}
      log('native-fallback',{error:String(error)});
      // Reapply master gain and resume from the next sound/gesture.
      Game.audio?.sync();
    }
    async function render(v,noise){
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
      const bytes=new Uint8Array(pcm.length*4),view=new DataView(bytes.buffer);
      for(let i=0;i<pcm.length;i++)view.setFloat32(i*4,pcm[i],true);
      let binary='';for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
      return btoa(binary);
    }
    async function prepare(){
      if(state!=='idle')return;
      state='preparing';
      preparationTimer=setTimeout(()=>fail(Error('Native preparation timed out')),30000);
      try{
        info=JSON.parse(host.begin());
        if(info.version!==1||!info.session||!info.sampleRate)throw Error(info.error||'Unsupported host');
        session=info.session;rate=info.sampleRate;
        const recipes=[];
        for(const type of ['shoot','tap','boom','ricochet','lightning','frost','prism','gold','core','win','upgrade'])recipes.push(window.SlingSoundRecipe(type));
        for(let n=1;n<=5;n++)recipes.push(window.SlingSoundRecipe('draw',n));
        for(let n=1;n<=17;n+=2)recipes.push(window.SlingSoundRecipe('break',n));
        const noise=new Float32Array(Math.ceil(rate*.25));
        for(let i=0;i<noise.length;i++)noise[i]=Math.random()*2-1;
        for(const recipe of recipes)for(const voice of recipe){
          const v=describe(voice),k=key(v);if(samples.has(k))continue;
          const id=samples.size,data=await render(v,noise);
          if(state!=='preparing')return;
          if(!host.upload(session,id,data))throw Error('Native sample upload rejected');
          samples.set(k,id);
          // Yield between uploads; no synthesis or PCM transfer on the impact path.
          await new Promise(resolve=>setTimeout(resolve,0));
        }
        if(state!=='preparing')return;
        if(!host.commit(session))throw Error('Native stream start failed');
        clearTimeout(preparationTimer);
        state='ready';onReady();sync();
        log('native-ready',{samples:samples.size,audio:snapshot()});
      }catch(error){fail(error);}
    }
    function snapshot(){
      let hostState=null;
      if(session&&state==='ready')try{hostState=JSON.parse(host.snapshot(session));}catch{}
      return {backend:'native-aaudio',state,session,sampleRate:rate,host:hostState||info};
    }
    function sync(){
      if(state!=='ready')return;
      try{
        const silent=!Game.state.sound||Game.paused||document.hidden;
        if(!host.setMuted(session,silent))throw Error('Native stream unavailable');
        if(silent)last.clear();
      }catch(error){fail(error);}
    }
    function play(type,n,x,priority,soundId){
      if(state!=='ready')return false;
      try{
        if(!Number.isFinite(n)||!Number.isFinite(x))return true;
        const voices=window.SlingSoundRecipe(type,n,x).map(describe);
        if(!voices.length)return true;
        const encoded=voices.map(v=>({id:samples.get(key(v)),delay:v.delay,pan:Math.max(-.65,Math.min(.65,(v.x-390)/520)),wet:v.wet}));
        // Return the whole backend to Web Audio so a suspended/muted context is restored.
        if(encoded.some(v=>v.id===undefined))throw Error('Uncached sound parameters');
        const now=performance.now(),intervalMs=(intervals[type]||0)*1000,elapsedMs=now-(last.get(type)??-Infinity);
        if(!priority&&elapsedMs<intervalMs){log('sound-skipped',{soundId,type,reason:'rate-limit',clock:'performance.now',elapsedMs,intervalMs,backend:'native-aaudio'});return true;}
        const result=host.play(session,JSON.stringify({type,priority,voices:encoded}));
        if(result<0)throw Error('Native playback unavailable: '+result);
        if(result===0){log('sound-skipped',{soundId,type,reason:'native-busy-or-muted',backend:'native-aaudio'});return true;}
        if(!priority)last.set(type,now);
        log('native-sound-enqueued',{soundId,type,voices:voices.length,backend:'native-aaudio'});
        return true;
      }catch(error){fail(error);return false;}
    }
    document.addEventListener('visibilitychange',sync);
    window.addEventListener('pagehide',()=>{state='closed';clearTimeout(preparationTimer);try{host.release(session);}catch{}});
    return {get ready(){return state==='ready';},prepare,play,sync,snapshot};
  };
})();
