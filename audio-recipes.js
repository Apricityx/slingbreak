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
    }else if(type==='upgrade'){
      [440,554,659,880].forEach((f,i)=>tone(t+i*.065,f,f,.25,.12,'triangle',390,true));
    }
    return voices;
  };
})();
