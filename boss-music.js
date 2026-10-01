(() => {
  'use strict';
  // Adaptive boss score. A boss def may carry `score` (pure data + an events
  // function) and `music()` (its current mood). The music runs on its own
  // Web Audio graph, separate from the low-latency effects engine, with a
  // look-ahead scheduler. Layers build phase by phase, and mood changes
  // (stun, eclipse, devour, collapse, or a score's own moods) reshape the mix in real time.
  const G=window.Game;
  const midi=n=>440*Math.pow(2,(n-69)/12);
  let ctx=null,master=null,tone=null,delay=null,buses={},noise=null;
  let step=0,nextAt=0,state={score:null,phase:0,mood:'',twin:false},active=false,level=-1,muted=true;

  function build(){
    const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return false;
    ctx=new Audio({latencyHint:'playback'});
    master=ctx.createGain();master.gain.value=0;
    tone=ctx.createBiquadFilter();tone.type='lowpass';tone.frequency.value=18000;tone.Q.value=.6;
    const limit=ctx.createDynamicsCompressor();limit.threshold.value=-10;limit.ratio.value=6;limit.attack.value=.004;limit.release.value=.2;
    tone.connect(master);master.connect(limit);limit.connect(ctx.destination);
    // A tempo-free echo for the bright parts.
    delay=ctx.createDelay(1);delay.delayTime.value=.34;
    const fb=ctx.createGain(),wet=ctx.createGain();fb.gain.value=.32;wet.gain.value=.28;
    delay.connect(fb);fb.connect(delay);delay.connect(wet);wet.connect(tone);
    for(const id of ['pad','bass','drums','arp','lead','bell','fx']){const g=ctx.createGain();g.gain.value=0;g.connect(tone);buses[id]=g;}
    noise=ctx.createBuffer(1,ctx.sampleRate,ctx.sampleRate);
    const d=noise.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;
    return true;
  }
  // One voice: oscillator or noise → optional filter → envelope → pan → bus (+ echo).
  function voice(bus,t,{type='sine',freq=220,to,detune=0,dur=.2,vol=.2,attack=.004,hold=0,cutoff,cutTo,q=.8,ftype='lowpass',pan=0,echo=false,buffer=false}){
    const src=buffer?ctx.createBufferSource():ctx.createOscillator();
    if(buffer){src.buffer=noise;src.loop=true;}else{src.type=type;src.frequency.setValueAtTime(freq,t);if(to)src.frequency.exponentialRampToValueAtTime(Math.max(20,to),t+dur);src.detune.value=detune;}
    let head=src;
    if(cutoff){const f=ctx.createBiquadFilter();f.type=ftype;f.Q.value=q;f.frequency.setValueAtTime(cutoff,t);if(cutTo)f.frequency.exponentialRampToValueAtTime(Math.max(30,cutTo),t+dur);head.connect(f);head=f;}
    const env=ctx.createGain(),end=t+attack+hold+dur;
    env.gain.setValueAtTime(.0001,t);env.gain.linearRampToValueAtTime(vol,t+attack);
    if(hold)env.gain.setValueAtTime(vol,t+attack+hold);
    env.gain.exponentialRampToValueAtTime(.0001,end);
    head.connect(env);
    const p=ctx.createStereoPanner?ctx.createStereoPanner():null;
    if(p){p.pan.value=pan;env.connect(p);p.connect(buses[bus]);if(echo)p.connect(delay);}
    else{env.connect(buses[bus]);if(echo)env.connect(delay);}
    src.start(t);src.stop(end+.05);
    src.onended=()=>{src.disconnect();env.disconnect();p?.disconnect();};
  }
  // Instruments.
  const play={
    pad:(t,e,beat)=>{for(const n of e.notes)for(const d of [-9,9])voice('pad',t,{type:'sawtooth',freq:midi(n),detune:d,attack:beat*1.5,hold:beat*12,dur:beat*4,vol:.045*(e.vel||1),cutoff:900+(e.bright||0)*1400,q:.4});},
    bass:(t,e,beat)=>{
      voice('bass',t,{type:'square',freq:midi(e.note),dur:beat*(e.len||.9),vol:.13*e.vel,cutoff:1400,cutTo:180,q:4});
      voice('bass',t,{type:'sine',freq:midi(e.note),dur:beat*(e.len||.9)+.05,vol:.22*e.vel});
    },
    lead:(t,e,beat)=>{
      const len=e.len*beat*.25,o={freq:midi(e.note),attack:.012,hold:Math.max(0,len-.05),dur:.18,pan:e.pan||0,echo:true};
      voice('lead',t,{...o,type:'sawtooth',detune:-6,vol:.07*e.vel,cutoff:3200,cutTo:1600,q:1.2});
      voice('lead',t,{...o,type:'triangle',detune:7,vol:.06*e.vel});
    },
    arp:(t,e)=>voice('arp',t,{type:'triangle',freq:midi(e.note),dur:.16,vol:.07*e.vel,pan:e.pan||0,echo:true}),
    bell:(t,e)=>{voice('bell',t,{type:'sine',freq:midi(e.note),dur:1.4,vol:.06*e.vel,echo:true});voice('bell',t,{type:'sine',freq:midi(e.note)*2.76,dur:.5,vol:.02*e.vel});},
    kick:(t,e)=>{voice('drums',t,{type:'sine',freq:150,to:42,dur:.32,vol:.5*e.vel});voice('drums',t,{buffer:true,dur:.02,vol:.08*e.vel,cutoff:3000,ftype:'highpass'});},
    snare:(t,e)=>{voice('drums',t,{buffer:true,dur:.16,vol:.2*e.vel,cutoff:1800,ftype:'bandpass',q:.7});voice('drums',t,{type:'triangle',freq:210,to:120,dur:.1,vol:.12*e.vel});},
    hat:(t,e)=>voice('drums',t,{buffer:true,dur:e.open?.18:.04,vol:.06*e.vel,cutoff:7500,ftype:'highpass',pan:.2}),
    // Clockwork: a woodblock tick-tock and a music-box chime.
    tick:(t,e)=>{voice('drums',t,{buffer:true,dur:.014,vol:.07*e.vel,cutoff:e.hi?5200:3600,ftype:'bandpass',q:5,pan:e.hi?.25:-.25});voice('drums',t,{type:'square',freq:e.hi?3200:2400,dur:.02,vol:.02*e.vel,cutoff:1500,ftype:'highpass',pan:e.hi?.25:-.25});},
    box:(t,e)=>{voice('arp',t,{type:'sine',freq:midi(e.note),dur:.55,vol:.07*e.vel,pan:e.pan||0,echo:true});voice('arp',t,{type:'sine',freq:midi(e.note)*4,dur:.08,vol:.014*e.vel,pan:e.pan||0});}
  };
  const fx={
    crash:t=>{voice('fx',t,{buffer:true,dur:1.6,vol:.16,cutoff:5000,cutTo:1500,ftype:'highpass'});voice('fx',t,{type:'sine',freq:90,to:32,dur:.9,vol:.4});},
    riser:(t,len)=>voice('fx',t,{buffer:true,attack:len,dur:.1,vol:.12,cutoff:300,cutTo:6000,ftype:'bandpass',q:2}),
    chord:(t,notes,{vol=.08,dur=1.2,bell=false}={})=>{for(const n of notes){voice('fx',t,{type:'sawtooth',freq:midi(n),attack:.01,dur,vol,cutoff:3000,cutTo:600});if(bell)voice('fx',t,{type:'sine',freq:midi(n+12),dur:dur*1.5,vol:vol*.6,echo:true});}}
  };
  // Bus levels per phase, then reshaped by mood.
  function mix(score,phase,mood){
    const base=score.mix[Math.min(phase,score.mix.length)-1]||score.mix[0],m={...base};
    const shape=score.moods?.[mood];if(shape)for(const k in shape)m[k]=shape[k]<0?m[k]*-shape[k]:shape[k];
    return m;
  }
  function apply(prev){
    const t=ctx.currentTime,{score,phase,mood}=state,levels=mix(score,phase,mood);
    for(const id in buses)buses[id].gain.setTargetAtTime(levels[id]??(id==='fx'?1:0),t,mood==='stun'?.05:.4);
    // A score may set its own filter per mood (score.filter) and which moods open with a riser (score.riser).
    const cut=score.filter?.[mood]??(mood==='eclipse'?520:mood==='intro'?1600:18000);
    tone.frequency.setTargetAtTime(cut,t,cut<1000?.3:.6);
    const beat=60/score.bpm(phase,mood);
    if(prev.phase&&phase>prev.phase)fx.crash(t+.02);
    if(mood==='stun'&&prev.mood!=='stun')fx.chord(t+.02,score.stab,{vol:.07,dur:1.1,bell:true});
    if((mood==='devour'||score.riser?.includes(mood))&&prev.mood!==mood)fx.riser(t,beat*8);
    if(mood==='dying'&&prev.mood!=='dying'){
      fx.riser(t,1.2);fx.crash(t+1.3);fx.chord(t+1.3,score.stinger,{vol:.06,dur:5,bell:true});
      master.gain.cancelScheduledValues(t);master.gain.setValueAtTime(master.gain.value,t);master.gain.linearRampToValueAtTime(level,t+1.4);master.gain.linearRampToValueAtTime(.0001,t+6.5);
    }
  }
  // Look-ahead scheduling in sixteenth-note steps.
  function schedule(){
    const {score,phase,mood,twin}=state,beat=60/score.bpm(phase,mood),dt=beat/4;
    if(nextAt<ctx.currentTime)nextAt=ctx.currentTime+.05;
    while(nextAt<ctx.currentTime+.14){
      if(mood!=='dying')for(const e of score.events(step,phase,mood,twin))play[e.i]?.(nextAt,e,beat);
      step=(step+1)%(16*score.bars);nextAt+=dt;
    }
  }
  function update(){
    const m=G.boss?.(),d=m&&G.bossDefs?.[m.boss],score=d?.score;
    const on=!!score&&G.state.sound&&G.state.volume>0&&G.phase!=='clearing';
    if(!on){if(active)stop();return;}
    if(!ctx&&!build())return;
    if(ctx.state==='suspended')ctx.resume().catch(()=>{});
    const age=G.bossApi?.introAge?.()??Infinity,dying=G.riftState?.().dying;
    const pick=dying?{mood:'dying'}:!m.intro||age<2.6?{mood:'intro'}:d.music?.()||{mood:'fight'};
    const next={score,phase:m.phase,mood:pick.mood,twin:!!pick.twin};
    const silent=G.paused||document.hidden;
    const want=silent?0:.55*G.state.volume/100;
    if(!active){active=true;step=0;nextAt=ctx.currentTime+.08;state={score:null,phase:0,mood:'',twin:false};}
    if(want!==level||silent!==muted){
      level=want;muted=silent;
      if(state.mood!=='dying'){master.gain.cancelScheduledValues(ctx.currentTime);master.gain.setTargetAtTime(want,ctx.currentTime,silent?.05:.8);}
    }
    if(next.score!==state.score||next.phase!==state.phase||next.mood!==state.mood||next.twin!==state.twin){const prev=state;state=next;apply(prev);}
    if(!silent)schedule();else nextAt=ctx.currentTime+.08;
  }
  function stop(){
    active=false;level=-1;
    if(!ctx)return;const t=ctx.currentTime;
    master.gain.cancelScheduledValues(t);master.gain.setTargetAtTime(0,t,.4);
    state={score:null,phase:0,mood:'',twin:false};
  }
  if(typeof setInterval==='function'&&typeof document!=='undefined'&&document.addEventListener){
    setInterval(()=>{try{update();}catch{}},40);
    // Browsers need a gesture before audio can start.
    for(const type of ['pointerdown','keydown'])document.addEventListener(type,()=>{if(ctx?.state==='suspended')ctx.resume().catch(()=>{});},{capture:true,passive:true});
  }
  G.music={update,stop,get state(){return {...state,active,step,running:ctx?.state};}};
})();
