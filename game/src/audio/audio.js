(() => {
  'use strict';
  const G=Game;
  const diagnostics=window.SlingAudioDiagnostics;
  const log=(event,data)=>{if(diagnostics?.enabled)diagnostics.record(event,data);};
  let soundSequence=0,activeSound=null,requestedHint=null;
  let context,master,mix,echo,uiMaster,uiMix,uiEcho,noiseBuffer,keepAlive,resumeAttempt=null;
  const sources=new Set(),lastRequestMs=new Map();
  let currentType='',priorityVoice=false,uiVoice=false;
  let unlocked=false,preloadPromise=null;
  const enabled=()=>G.state.sound&&G.state.volume>0;
   // Version-2 hosts own all output; older mute-only hosts retain Web Audio
   // for partial gain and isolated dialog cues.
   const useNative=()=>enabled()&&(native?.fullPlayback||G.state.volume===100);
  const intervals={draw:.065,break:.018,boom:.055,lightning:.06,frost:.07,prism:.06,gold:.06,ricochet:.035,tap:.03,eyehit:.035,shatter:.05,void:.08,hydra:.05,anchor:.08,shard:.04,clang:.06,meteor:.08,bell:.2,chime:.05,timestop:.3,hiss:.4,devour:1,gulp:.2,regrow:.8,tick:.08,jam:.5};
  const native=window.createSlingNativeAudio?.({intervals,log,canOutput:()=>unlocked,onReady(){
    // Switch only after every sample is uploaded and the native stream is running.
    if(!useNative()){native?.disable();return;}
    G.audio.sync();
    lastRequestMs.clear();
  }});
  function closeContext(){
    if(!context)return;
    const old=context;
    context=null;master=null;mix=null;echo=null;uiMaster=null;uiMix=null;uiEcho=null;noiseBuffer=null;resumeAttempt=null;
    for(const source of sources)try{source.stop();}catch{}
    sources.clear();lastRequestMs.clear();
    try{keepAlive?.stop();}catch{}
    keepAlive=null;
    old.onstatechange=null;
    old.close().catch(()=>{});
  }
  const ensure=(fromGesture=false)=>{
    if(!context){
      const Audio=window.AudioContext||window.webkitAudioContext;
      if(!Audio)return false;
      // Prefer the standard interactive category; the browser chooses the
      // actual buffer size, so this hint does not guarantee low latency.
      // Keep the device's native sample rate to avoid an extra resampling stage.
      try{context=new Audio({latencyHint:'interactive'});requestedHint='interactive';}catch(error){
        log('context-fallback',{hint:'interactive',error:diagnostics?.errorInfo(error)});
        try{context=new Audio({latencyHint:0});requestedHint=0;}catch(error){log('context-fallback',{hint:0,error:diagnostics?.errorInfo(error)});context=new Audio();requestedHint='default';}
      }
      log('context-created',{requestedHint,state:context.state,sampleRate:context.sampleRate,baseLatency:context.baseLatency??null,outputLatency:context.outputLatency??null,highBaseLatency:Number.isFinite(context.baseLatency)?context.baseLatency>=.05:null,baseLatencyThresholdMs:50});
      master=context.createGain();master.gain.value=G.paused||document.hidden?0:.7*G.state.volume/100;
      mix=context.createGain();
      // Dialog cues have their own bus: pausing gameplay must not cut their
      // envelopes or briefly unmute impacts already queued on the game bus.
      uiMaster=context.createGain();uiMaster.gain.value=document.hidden?0:.7*G.state.volume/100;
      uiMix=context.createGain();
      // Limit peaks without the DynamicsCompressor's mandatory look-ahead delay.
      const ceiling=context.createWaveShaper(),curve=new Float32Array(2048);
      for(let i=0;i<curve.length;i++)curve[i]=.9*Math.tanh((i/(curve.length-1)*2-1)*1.4);
      ceiling.curve=curve;
      // Avoid additional oversampling work in the limiter.
      ceiling.oversample='none';
      mix.connect(master);master.connect(ceiling);ceiling.connect(context.destination);
      uiMix.connect(uiMaster);uiMaster.connect(ceiling);
      const delayBus=bus=>{
        const delay=context.createDelay(.4),feedback=context.createGain(),wet=context.createGain();
        delay.delayTime.value=.105;feedback.gain.value=.18;wet.gain.value=.16;
        delay.connect(feedback);feedback.connect(delay);delay.connect(wet);wet.connect(bus);
        return delay;
      };
      echo=delayBus(mix);uiEcho=delayBus(uiMix);
       // Maintain a low-level source while running. Its effect on backend
       // suspension and audible latency is device-dependent and unverified.
       const keepGain=context.createGain();keepGain.gain.value=.00001;
       if(context.createConstantSource){
         keepAlive=context.createConstantSource();keepAlive.connect(keepGain);keepGain.connect(mix);keepAlive.start();
       }else{
         keepAlive=context.createOscillator();keepAlive.frequency.value=1;keepAlive.connect(keepGain);keepGain.connect(mix);keepAlive.start();
       }
       noiseBuffer=context.createBuffer(1,Math.ceil(context.sampleRate*.25),context.sampleRate);
      const samples=noiseBuffer.getChannelData(0);for(let i=0;i<samples.length;i++)samples[i]=Math.random()*2-1;
    }
    if((context.state==='suspended'||context.state==='interrupted')&&(fromGesture||!resumeAttempt)){
      // A touch-down resume can stay pending until activation. Always retry
      // synchronously on a later gesture, especially touch-end or click.
      const attempt=context.resume();resumeAttempt=attempt;
      const resumeAt=diagnostics?.enabled?performance.now():0;
      log('resume-request',{fromGesture,state:context.state});
      attempt.then(()=>{log('resume-success',{durationMs:performance.now()-resumeAt,audio:G.audio.diagnosticSnapshot()});G.audio.sync();}).catch(error=>{log('resume-error',{error:diagnostics?.errorInfo(error)});}).finally(()=>{
        if(resumeAttempt===attempt)resumeAttempt=null;
      });
    }
    if(!context.onstatechange)context.onstatechange=()=>{
      log('context-state',{audio:G.audio.diagnosticSnapshot()});
      if(context.state==='running')G.audio.sync();
    };
    // Never queue stale impact sounds while the output device is waking up.
    return context.state==='running';
  };
   function voice(source,t,duration,volume,x,filter,spacious=false){
     const envelope=context.createGain(),pan=context.createStereoPanner?context.createStereoPanner():context.createGain();
    envelope.gain.setValueAtTime(.0001,t);envelope.gain.linearRampToValueAtTime(volume,t+.003);
    envelope.gain.exponentialRampToValueAtTime(.0001,t+duration);
     if(pan.pan)pan.pan.value=Math.max(-.65,Math.min(.65,(x-390)/520));
    if(filter){source.connect(filter);filter.connect(envelope);}else source.connect(envelope);
    envelope.connect(pan);pan.connect(uiVoice?uiMix:mix);if(spacious)pan.connect(uiVoice?uiEcho:echo);
    source.effectType=currentType;source.priority=priorityVoice;source.ui=uiVoice;sources.add(source);
    source.onended=()=>{sources.delete(source);source.disconnect();filter?.disconnect();envelope.disconnect();pan.disconnect();};
    source.start(t);source.stop(t+duration+.025);
    if(diagnostics?.enabled)log('voice-scheduled',{soundId:activeSound?.id,type:currentType,scheduledTime:t,currentTime:context.currentTime,offsetMs:(t-context.currentTime)*1000,durationMs:duration*1000,source:source.buffer?'noise':'tone'});
  }
  const tone=(t,freq,end,duration,volume,type='sine',x=390,spacious=false)=>{
    const osc=context.createOscillator();osc.type=type;osc.frequency.setValueAtTime(freq,t);
    osc.frequency.exponentialRampToValueAtTime(Math.max(20,end),t+duration);
    voice(osc,t,duration,volume,x,null,spacious);
  };
  const noise=(t,duration,volume,freq,type='highpass',x=390,end=freq)=>{
     const source=context.createBufferSource(),filter=context.createBiquadFilter();source.buffer=noiseBuffer;source.loop=true;
    filter.type=type;filter.Q.value=.7;filter.frequency.setValueAtTime(freq,t);
    filter.frequency.exponentialRampToValueAtTime(Math.max(30,end),t+duration);
    voice(source,t,duration,volume,x,filter);
  };
   G.audio={
     get nativeMusic(){return native?.musicPlayback?native:null;},
    diagnosticSnapshot(){
      if(native?.ready)return native.snapshot();
       if(native?.fullPlayback)return native.snapshot();
       if(!context)return {state:'not-created',backend:'web-audio',native:native?.snapshot()};
      const now=performance.now(),currentTime=context.currentTime;
      let output=null;
      try{
        if(context.getOutputTimestamp){
          const stamp=context.getOutputTimestamp();
          output={contextTime:stamp.contextTime,performanceTime:stamp.performanceTime};
          if(Number.isFinite(stamp.performanceTime)&&Number.isFinite(stamp.contextTime)&&stamp.performanceTime>0&&stamp.contextTime>0){
            // A clock offset is not an end-to-end audio latency measurement.
            output.timestampOffsetMs=now-stamp.performanceTime;
            output.timestampInFuture=stamp.performanceTime>now;
          }
        }
      }catch(error){output={error:diagnostics?.errorInfo(error)};}
      return {backend:'web-audio',native:native?.snapshot(),state:context.state,currentTime,atMs:now,requestedHint,sampleRate:context.sampleRate,
        baseLatency:context.baseLatency??null,outputLatency:context.outputLatency??null,output,
        activeSources:sources.size,resumePending:!!resumeAttempt,masterGain:master?.gain.value,
        soundEnabled:G.state.sound,paused:G.paused,hidden:document.hidden};
    },
    get latency(){
      if(native?.ready)return native.snapshot();
      return context?{state:context.state,sampleRate:context.sampleRate,baseLatency:context.baseLatency??null,outputLatency:context.outputLatency??null}:null;
    },
     preload(){
       if(!native?.fullPlayback||!enabled())return Promise.resolve();
       if(!preloadPromise)preloadPromise=(async()=>{await native.prepare();if(native.ready)await G.music?.preload?.();})().finally(()=>{preloadPromise=null;});
       return preloadPromise;
     },
     unlock(){unlocked=true;if(enabled())try{if(useNative())native?.prepare();if(native?.ready&&useNative())native.sync();else if(!native?.fullPlayback)ensure(true);}catch(error){log('unlock-error',{error:diagnostics?.errorInfo(error)});}},
    cue(type,n=1,x=390){playSound(type,n,x,false,true);},
    sync(){
      if(!enabled()){native?.disable();closeContext();return;}
      if(useNative())native?.sync();else native?.disable();
       const nativeReady=native?.ready&&useNative();
       if(native?.fullPlayback){closeContext();return;}
      if(nativeReady&&![...sources].some(source=>source.ui)){closeContext();return;}
      if(!context)return;
      const silent=G.paused||document.hidden||nativeReady,t=context.currentTime;
      log('audio-sync',{silent,state:context.state,currentTime:t});
      master.gain.cancelScheduledValues(t);master.gain.setTargetAtTime(silent?0:.7*G.state.volume/100,t,.012);
      uiMaster.gain.cancelScheduledValues(t);uiMaster.gain.setTargetAtTime(document.hidden?0:.7*G.state.volume/100,t,.012);
      if(silent){for(const source of sources)if(!source.ui||document.hidden)try{source.stop(t+.04);}catch{}}
      if(document.hidden)lastRequestMs.clear();
      else if(silent)for(const key of lastRequestMs.keys())if(!key.startsWith('ui:'))lastRequestMs.delete(key);
    }
  };
  const unlock=()=>G.audio.unlock();
  document.addEventListener('pointerdown',unlock,{capture:true,passive:true});
  document.addEventListener('pointerup',unlock,{capture:true,passive:true});
  document.addEventListener('touchend',unlock,{capture:true,passive:true});
  document.addEventListener('click',unlock,{capture:true,passive:true});
  document.addEventListener('keydown',unlock,{capture:true});
  document.addEventListener('visibilitychange',()=>G.audio.sync());
  function playSound(type,n=1,x=390,priority=false,ui=false){
    // Do not synthesize, prepare samples, wake an audio device or even trace
    // individual game impacts while the volume is zero.
    if(!enabled()||document.hidden)return;
    const tracing=diagnostics?.enabled;
    activeSound=tracing?{id:++soundSequence,type,atMs:performance.now()}:null;
    if(tracing)log('sound-request',{...activeSound,n,x,priority,lastInput:diagnostics.lastInput,audio:G.audio.diagnosticSnapshot()});
    const skip=(reason,details)=>{if(tracing)log('sound-skipped',{soundId:activeSound.id,type,reason,...details});};
    if(G.paused&&!ui){skip('paused');return;}
    try{
       // Version-2 native hosts have separate game/UI buses; v1 UI uses Web Audio.
       if((!ui||native?.fullPlayback)&&useNative())native?.prepare();
       if((!ui||native?.fullPlayback)&&useNative()&&native?.play(type,n,x,priority,activeSound?.id,ui))return;
       if(native?.fullPlayback)return;
      if(!ensure(ui)){skip('context-not-running');return;}
      const t=context.currentTime,requestMs=performance.now();
      const requestKey=ui?'ui:'+type:type;
       if(priority){
         // Keep decisive destruction cues immediate instead of building an audible backlog.
         const priorityLimit=36;
         if(sources.size>priorityLimit){
          const victims=[...sources].sort((a,b)=>(a.priority?(a.effectType===type?1:2):0)-(b.priority?(b.effectType===type?1:2):0));
           for(const source of victims){if(sources.size<=priorityLimit)break;try{source.stop(context.currentTime+.006);}catch{}sources.delete(source);}
        }
      }else{
        // Throttle real requests independently of the audio clock's updates.
        // Keep the audio clock for sample scheduling and envelope timing only.
        const intervalMs=(intervals[type]||0)*1000;
        const elapsedMs=requestMs-(lastRequestMs.get(requestKey)??-Infinity);
        if(elapsedMs<intervalMs){skip('rate-limit',{clock:'performance.now',elapsedMs,intervalMs});return;}
      }
       if(!priority&&sources.size>28&&type!=='win'&&type!=='core'){skip('voice-limit');return;}
      if(!priority)lastRequestMs.set(requestKey,requestMs);
      currentType=type;priorityVoice=priority;uiVoice=ui;
      for(const voice of window.SlingSoundRecipe(type,n,x)){
        const args=voice.args.slice();args[0]+=t;
        (voice.kind==='tone'?tone:noise)(...args);
      }
    }catch(error){log('sound-error',{soundId:activeSound?.id,type,error:diagnostics?.errorInfo(error)});}
    finally{if(tracing)log('sound-dispatch-end',{soundId:activeSound.id,type,durationMs:performance.now()-activeSound.atMs,audio:G.audio.diagnosticSnapshot()});}
  }
  G.sound=(type,n=1,x=390,priority=false)=>playSound(type,n,x,priority);
})();
