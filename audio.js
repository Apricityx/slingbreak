(() => {
  'use strict';
  const G=Game;
  const diagnostics=window.SlingAudioDiagnostics;
  const log=(event,data)=>{if(diagnostics?.enabled)diagnostics.record(event,data);};
  let soundSequence=0,activeSound=null,requestedHint=null;
  let context,master,mix,echo,noiseBuffer,keepAlive,resumeAttempt=null;
  const sources=new Set(),lastRequestMs=new Map();
  let currentType='',priorityVoice=false;
  const intervals={draw:.065,break:.018,boom:.055,lightning:.06,frost:.07,prism:.06,gold:.06,ricochet:.035,tap:.03};
  const native=window.createSlingNativeAudio?.({intervals,log,onReady(){
    // Switch only after every sample is uploaded and the native stream is running.
    if(context){master.gain.cancelScheduledValues(context.currentTime);master.gain.value=0;
      for(const source of sources)try{source.stop();}catch{}
      // A late suspend completion must not leave the fallback context asleep.
      context.suspend().then(()=>{if(!native?.ready)ensure();}).catch(()=>{});
    }
    lastRequestMs.clear();
  }});
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
      master=context.createGain();master.gain.value=G.paused?0:.7;
      mix=context.createGain();
      // Limit peaks without the DynamicsCompressor's mandatory look-ahead delay.
      const ceiling=context.createWaveShaper(),curve=new Float32Array(2048);
      for(let i=0;i<curve.length;i++)curve[i]=.9*Math.tanh((i/(curve.length-1)*2-1)*1.4);
      ceiling.curve=curve;
      // Avoid additional oversampling work in the limiter.
      ceiling.oversample='none';
      mix.connect(master);master.connect(ceiling);ceiling.connect(context.destination);
      echo=context.createDelay(.4);echo.delayTime.value=.105;
      const feedback=context.createGain(),wet=context.createGain();feedback.gain.value=.18;wet.gain.value=.16;
       echo.connect(feedback);feedback.connect(echo);echo.connect(wet);wet.connect(mix);
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
    envelope.connect(pan);pan.connect(mix);if(spacious)pan.connect(echo);
    source.effectType=currentType;source.priority=priorityVoice;sources.add(source);
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
    diagnosticSnapshot(){
      if(native?.ready)return native.snapshot();
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
    unlock(){if(G.state.sound)try{native?.prepare();if(native?.ready)native.sync();else ensure(true);}catch(error){log('unlock-error',{error:diagnostics?.errorInfo(error)});}},
    sync(){
      native?.sync();
      if(native?.ready)return;
      if(!context)return;
      const silent=!G.state.sound||G.paused,t=context.currentTime;
      log('audio-sync',{silent,state:context.state,currentTime:t});
      master.gain.cancelScheduledValues(t);master.gain.setTargetAtTime(silent?0:.7,t,.012);
        if(silent){for(const source of sources)try{source.stop(t+.04);}catch{}lastRequestMs.clear();}
    }
  };
  const unlock=()=>G.audio.unlock();
  document.addEventListener('pointerdown',unlock,{capture:true,passive:true});
  document.addEventListener('pointerup',unlock,{capture:true,passive:true});
  document.addEventListener('touchend',unlock,{capture:true,passive:true});
  document.addEventListener('click',unlock,{capture:true,passive:true});
  document.addEventListener('keydown',unlock,{capture:true});
  G.sound=(type,n=1,x=390,priority=false)=>{
    const tracing=diagnostics?.enabled;
    activeSound=tracing?{id:++soundSequence,type,atMs:performance.now()}:null;
    if(tracing)log('sound-request',{...activeSound,n,x,priority,lastInput:diagnostics.lastInput,audio:G.audio.diagnosticSnapshot()});
    const skip=(reason,details)=>{if(tracing)log('sound-skipped',{soundId:activeSound.id,type,reason,...details});};
    if(!G.state.sound||G.paused){skip(G.paused?'paused':'muted');return;}
    try{
      native?.prepare();
      if(native?.play(type,n,x,priority,activeSound?.id))return;
      if(!ensure()){skip('context-not-running');return;}
      const t=context.currentTime,requestMs=performance.now();
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
        const elapsedMs=requestMs-(lastRequestMs.get(type)??-Infinity);
        if(elapsedMs<intervalMs){skip('rate-limit',{clock:'performance.now',elapsedMs,intervalMs});return;}
      }
       if(!priority&&sources.size>28&&type!=='win'&&type!=='core'){skip('voice-limit');return;}
      if(!priority)lastRequestMs.set(type,requestMs);
      currentType=type;priorityVoice=priority;
      for(const voice of window.SlingSoundRecipe(type,n,x)){
        const args=voice.args.slice();args[0]+=t;
        (voice.kind==='tone'?tone:noise)(...args);
      }
    }catch(error){log('sound-error',{soundId:activeSound?.id,type,error:diagnostics?.errorInfo(error)});}
    finally{if(tracing)log('sound-dispatch-end',{soundId:activeSound.id,type,durationMs:performance.now()-activeSound.atMs,audio:G.audio.diagnosticSnapshot()});}
  };
})();
