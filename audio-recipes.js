/* Shared voice descriptions for realtime Web Audio and offline/native playback. */
(() => {
  'use strict';
  window.SlingSoundRecipe=(type,n=1,x=390)=>{
    const voices=[],t=0;
    const tone=(...args)=>voices.push({kind:'tone',args});
    const noise=(...args)=>voices.push({kind:'noise',args});
    if(type==='draw'){
      const f=125+n*33;tone(t,f,f*1.16,.09,.075,'triangle');noise(t,.04,.025,1100,'bandpass');
    }else if(type==='shoot'){
      tone(t,205,49,.2,.27,'triangle');tone(t,510,140,.09,.075);
      noise(t,.16,.24,3100,'bandpass',x,650);
    }else if(type==='tap'){
      tone(t,230,100,.09,.19,'triangle',x);noise(t,.045,.14,1800,'highpass',x);
    }else if(type==='break'){
      const notes=[0,3,7,10,12,15,19,22,24],f=390*Math.pow(2,notes[Math.min(8,Math.floor((n-1)/2))]/12);
      tone(t,155,53,.115,.2,'triangle',x);noise(t,.085,.23,1700,'highpass',x);
      tone(t,f,f*.995,.2,.1,'sine',x,true);tone(t+.014,f*1.505,f*1.5,.13,.045,'sine',x,true);
    }else if(type==='boom'){
      tone(t,135,32,.5,.52,'sine',x);tone(t,74,40,.25,.16,'triangle',x);
      noise(t,.36,.52,1900,'lowpass',x,150);noise(t,.055,.2,3200,'highpass',x);
    }else if(type==='ricochet'){
      [790,1277,2061].forEach((f,i)=>tone(t+i*.004,f,f*.86,.18-i*.035,.13/(i+1),'sine',x,true));
      noise(t,.035,.22,2600,'highpass',x);tone(t,145,80,.08,.16,'triangle',x);
    }else if(type==='lightning'){
      noise(t,.19,.32,4800,'bandpass',x,450);tone(t,1600,150,.16,.13,'sawtooth',x);
      noise(t+.035,.045,.24,3300,'highpass',x);tone(t,180,60,.12,.18,'triangle',x);
    }else if(type==='frost'){
      [1397,2093,2794].forEach((f,i)=>tone(t+i*.03,f,f*.98,.3,.09,'sine',x,true));noise(t,.19,.21,4700,'highpass',x);
    }else if(type==='prism'){
      [0,1].forEach(i=>tone(t+i*.025,380,1400,.26,.14,'triangle',x+(i?160:-160),true));
      tone(t+.07,1760,1320,.22,.08,'sine',x,true);noise(t,.045,.13,3200,'highpass',x);
    }else if(type==='gold'){
      [1319,1760,2093].forEach((f,i)=>tone(t+i*.055,f,f,.25,.16,'sine',x,true));noise(t,.04,.08,4200,'highpass',x);
    }else if(type==='core'){
      tone(t,110,880,.7,.14,'triangle',390,true);noise(t,.55,.13,400,'bandpass',390,4000);
      [523,659,784,1047].forEach((f,i)=>tone(t+.35+i*.085,f,f,.4,.095,'sine',390,true));
    }else if(type==='win'){
      tone(t,160,28,.9,.6);noise(t,.75,.55,2300,'lowpass',390,120);
      [523,659,784,1047,1319].forEach((f,i)=>{tone(t+.13+i*.08,f,f,.65,.13,'sine',390,true);tone(t+.13+i*.08,f/2,f/2,.45,.07,'triangle');});
    }else if(type==='reroll'){
      // Skill reroll: an airy riffle sweeping up into a bright pair.
      noise(t,.32,.16,900,'bandpass',x,5200);tone(t,180,720,.3,.09,'triangle',x,true);
      [880,1319].forEach((f,i)=>tone(t+.2+i*.05,f,f,.24,.07,'sine',x,true));
    }else if(type==='upgrade'){
      [440,554,659,880].forEach((f,i)=>tone(t+i*.065,f,f,.25,.12,'triangle',390,true));
    // Abyss rift boss (milestone.js).
    }else if(type==='abyss'){
      tone(t,62,36,1.5,.5,'sawtooth');tone(t,93,52,1.2,.22,'triangle');noise(t,1.1,.35,620,'lowpass',390,90);
      [196,294,392].forEach((f,i)=>tone(t+.2,f,f*1.02,1.1-i*.2,.07/(i+1),'sine',390+(i-1)*120,true));tone(t+.12,220,440,.8,.05,'triangle',390,true);
    }else if(type==='eyehit'){
      tone(t,124,46,.24,.42,'sine',x);noise(t,.08,.3,900,'lowpass',x);tone(t+.02,880,620,.2,.08,'triangle',x,true);
    }else if(type==='shatter'){
      [2637,3136,3951,4699].forEach((f,i)=>tone(t+i*.018,f,f*.9,.24,.06,'sine',x,true));noise(t,.32,.3,5200,'highpass',x,2400);
    }else if(type==='void'){
      tone(t,320,38,.65,.26,'sine',x);noise(t,.55,.22,720,'bandpass',x,110);
    }else if(type==='hydra'){
      tone(t,440,880,.12,.12,'triangle',x-80);tone(t+.04,440,880,.12,.12,'triangle',x+80);noise(t,.05,.12,2400,'highpass',x);
    }else if(type==='anchor'){
      noise(t,.26,.34,1500,'bandpass',x,300);tone(t,210,88,.32,.24,'triangle',x);[1175,1568].forEach((f,i)=>tone(t+.05+i*.04,f,f,.3,.07,'sine',x,true));
    }else if(type==='shard'){
      [3136,3951].forEach((f,i)=>tone(t+i*.02,f,f*.92,.16,.05,'sine',x,true));noise(t,.12,.16,5600,'highpass',x);
    // Forge colossus, star serpent, chrono sovereign (boss-*.js).
    }else if(type==='forge'){
      tone(t,48,30,1.6,.55,'sawtooth');noise(t,1.3,.4,380,'lowpass',390,70);tone(t+.1,96,60,1.1,.2,'square');
      [131,196,262].forEach((f,i)=>tone(t+.28,f,f,1-i*.15,.08/(i+1),'triangle',390+(i-1)*120,true));[1047,1568].forEach((f,i)=>tone(t+.3+i*.03,f,f*.99,.8,.04,'sine',390,true));
    }else if(type==='clang'){
      [523,1109,1661,2489].forEach((f,i)=>tone(t,f,f*.985,.7-i*.12,.11/(i+1),'sine',x,true));noise(t,.06,.3,3800,'highpass',x);tone(t,90,45,.3,.3,'triangle',x);
    }else if(type==='meteor'){
      noise(t,.5,.32,900,'bandpass',x,160);tone(t,380,70,.5,.2,'sawtooth',x);tone(t+.35,80,34,.4,.4,'sine',x);
    }else if(type==='serpent'){
      noise(t,1.2,.3,2600,'bandpass',390,5200);tone(t,70,44,1.3,.42,'sawtooth');
      tone(t+.1,330,660,.7,.06,'triangle',390,true);[440,659,880].forEach((f,i)=>tone(t+.25,f,f*1.01,1-i*.2,.06/(i+1),'sine',390+(i-1)*140,true));
    }else if(type==='hiss'){
      noise(t,.7,.16,5200,'highpass',x,2600);tone(t,180,90,.5,.06,'sawtooth',x);
    }else if(type==='devour'){
      tone(t,55,32,1.8,.45,'sawtooth');noise(t,1.6,.34,300,'lowpass',390,1400);[98,92,87].forEach((f,i)=>tone(t+.25+i*.3,f,f*.9,.7,.12,'triangle',390,true));
    }else if(type==='regrow'){
      noise(t,.6,.14,800,'bandpass',x,3600);tone(t,220,660,.6,.1,'triangle',x,true);[880,1319].forEach((f,i)=>tone(t+.35+i*.06,f,f,.35,.05,'sine',x,true));
    }else if(type==='gulp'){
      tone(t,140,40,.45,.5,'sine',x);noise(t,.3,.25,500,'lowpass',x,120);
    }else if(type==='bell'){
      [220,440,587,880,1175].forEach((f,i)=>tone(t,f,f,1.6-i*.2,.2/(i+1),'sine',x,true));noise(t,.05,.18,2600,'highpass',x);
    }else if(type==='chime'){
      [1568,2093,2637].forEach((f,i)=>tone(t+i*.04,f,f,.45,.08,'sine',x,true));
    }else if(type==='tick'){
      tone(t,2400,2200,.05,.07,'square',x);noise(t,.03,.1,5200,'highpass',x);
    }else if(type==='jam'){
      [0,.07,.14].forEach((d,i)=>noise(t+d,.05,.2,1800+i*600,'bandpass',x));tone(t,90,60,.4,.3,'triangle',x);
      [392,523,784].forEach((f,i)=>tone(t+.22,f,f*1.01,.9-i*.15,.07/(i+1),'sine',x+(i-1)*120,true));
    }else if(type==='timestop'){
      tone(t,1200,90,.7,.22,'sine',390,true);noise(t,.5,.2,1200,'bandpass',390,200);tone(t+.05,60,40,.8,.3,'triangle');
    }
    return voices;
  };
})();
