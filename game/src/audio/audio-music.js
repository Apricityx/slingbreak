/* Offline instrument synthesis. No output device or realtime AudioContext. */
(() => {
  'use strict';
  // Split PCM encoding into small tasks so long pads do not stall the UI.
  window.SlingEncodePCM=async pcm=>{
    let encoded='';
    // Full chunks are multiples of three bytes; only the final chunk is padded.
    for(let at=0;at<pcm.length;at+=12288){
      const count=Math.min(12288,pcm.length-at),bytes=new Uint8Array(count*4),view=new DataView(bytes.buffer);
      for(let i=0;i<count;i++)view.setFloat32(i*4,pcm[at+i],true);
      let binary='';
      for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
      encoded+=btoa(binary);
      if(at+count<pcm.length)await new Promise(resolve=>setTimeout(resolve,0));
    }
    return encoded;
  };
  window.SlingRenderMusicVoice=async(rate,{type='sine',freq=220,to,detune=0,dur=.2,attack=.004,hold=0,cutoff,cutTo,q=.8,ftype='lowpass',buffer=false})=>{
    const Offline=window.OfflineAudioContext||window.webkitOfflineAudioContext;
    const end=attack+hold+dur,offline=new Offline(1,Math.ceil((end+.05)*rate),rate);
    const src=buffer?offline.createBufferSource():offline.createOscillator();
    if(buffer){
      const noise=offline.createBuffer(1,rate,rate),data=noise.getChannelData(0);
      for(let i=0;i<data.length;i++)data[i]=Math.random()*2-1;
      src.buffer=noise;src.loop=true;
    }else{
      src.type=type;src.frequency.setValueAtTime(freq,0);
      if(to)src.frequency.exponentialRampToValueAtTime(Math.max(20,to),dur);
      src.detune.value=detune;
    }
    let head=src;
    if(cutoff){const f=offline.createBiquadFilter();f.type=ftype;f.Q.value=q;f.frequency.setValueAtTime(cutoff,0);if(cutTo)f.frequency.exponentialRampToValueAtTime(Math.max(30,cutTo),dur);head.connect(f);head=f;}
    const env=offline.createGain();env.gain.setValueAtTime(.0001,0);env.gain.linearRampToValueAtTime(1,attack);
    if(hold)env.gain.setValueAtTime(1,attack+hold);
    env.gain.exponentialRampToValueAtTime(.0001,end);head.connect(env);env.connect(offline.destination);
    src.start(0);src.stop(end+.05);
    return window.SlingEncodePCM((await offline.startRendering()).getChannelData(0));
  };
})();
