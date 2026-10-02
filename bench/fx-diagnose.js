/* Test-only timing probes. Loaded before production scripts only with --diagnose=1. */
(() => {
  'use strict';
  const totals=new Map(),stack=[],slow=[],longtasks=[];
  let enabled=false,context='',sequence=0,slowDropped=0;
  function run(name,fn,self,args){
    if(!enabled)return fn.apply(self,args);
    const entry={name,start:performance.now(),child:0,context,id:++sequence,parent:stack.length?stack[stack.length-1].id:null};
    stack.push(entry);
    try{return fn.apply(self,args);}finally{
      const end=performance.now(),ms=end-entry.start;stack.pop();
      if(stack.length)stack[stack.length-1].child+=ms;
      let total=totals.get(name);if(!total){total={name,count:0,totalMs:0,selfMs:0,maxMs:0};totals.set(name,total);}
      total.count++;total.totalMs+=ms;total.selfMs+=Math.max(0,ms-entry.child);total.maxMs=Math.max(total.maxMs,ms);
      if(ms>=8){if(slow.length<1200)slow.push({name,start:entry.start,ms,selfMs:Math.max(0,ms-entry.child),context:entry.context,id:entry.id,parent:entry.parent});else slowDropped++;}
    }
  }
  const wrap=(name,fn)=>function(...args){return run(name,fn,this,args);};
  const patch=(obj,key,name)=>{const fn=obj?.[key];if(typeof fn==='function')obj[key]=wrap(name,fn);};
  if(typeof PerformanceObserver==='function')try{const observer=new PerformanceObserver(list=>{
    if(enabled)for(const e of list.getEntries())longtasks.push({start:e.startTime,ms:e.duration,name:e.name});
  });observer.observe({entryTypes:['longtask']});}catch{}
  patch(Storage.prototype,'setItem','storage.setItem');patch(JSON,'stringify','JSON.stringify');
  for(const method of ['getBoundingClientRect','animate'])patch(Element.prototype,method,'DOM.'+method);
  for(const key of ['offsetWidth','offsetHeight']){const d=Object.getOwnPropertyDescriptor(HTMLElement.prototype,key);
    if(d?.get&&d.configurable)Object.defineProperty(HTMLElement.prototype,key,{...d,get:wrap('DOM.'+key,d.get)});
  }
  const probe=new Map();
  for(const method of ['drawImage','getImageData','createRadialGradient','createLinearGradient','stroke','fill','fillText','strokeText']){
    patch(CanvasRenderingContext2D.prototype,method,'canvas.'+method);
  }
  window.__FXDiagnose={wrap,patch,run,
    begin(label){enabled=true;context=label;performance.mark('fxdiag:'+label);},
    label(label){context=label;},end(){enabled=false;context='';},
    reset(){if(stack.length)throw Error('Cannot reset inside a timed scope');totals.clear();slow.length=0;longtasks.length=0;sequence=0;slowDropped=0;},
    scope(name,fn){return run(name,fn,null,[]);},
    get data(){return {totals:[...totals.values()],slow:[...slow],longtasks:[...longtasks],slowDropped};},
    // Experiment counters are descriptive, never alter game damage or rewards.
    counters:probe};
})();
