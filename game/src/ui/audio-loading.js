/* Optional native audio preparation runs alongside the opening animation. */
(() => {
  'use strict';
  const G=window.Game;
  if(!G?.audio?.nativeMusic)return;
  const intro=document.getElementById('intro-audio-status'),settings=document.getElementById('sound-cache-status');
  let finished=false,timer=null,version=0;
  function status(){
    const audio=G.audio.diagnosticSnapshot(),loading=audio.loading;
    let text;
    if(audio.state==='failed')text='声音暂时不可用';
    else if(!G.state.sound||G.state.volume===0)text='声音已关闭';
    else if(finished&&audio.state==='ready')text='声音已准备好';
    else if(audio.state==='ready')text=loading?.music?'正在准备背景音乐':'声音已准备好';
    else if(loading?.total){
      const done=loading.completed||0,total=loading.total;
      const percent=Math.round(done/total*100);
      text=`正在准备音效 · ${done} / ${total} · ${percent}%`;
    }else text='正在准备声音';
    for(const element of [intro,settings])if(element){element.hidden=false;element.textContent=text;}
  }
  function prepare(){
    const current=++version;
    finished=false;clearInterval(timer);status();
    if(!G.state.sound||G.state.volume===0)return;
    timer=setInterval(status,250);
    G.audio.preload().catch(()=>{}).finally(()=>{if(current===version){finished=true;clearInterval(timer);status();}});
  }
  prepare();
  const volume=document.getElementById('sound-volume');
  volume?.addEventListener('input',()=>{
    prepare();
  });
})();
