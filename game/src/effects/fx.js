(() => {
  'use strict';
  const G=window.Game,TAU=Math.PI*2;
  // Shared, bounded raster atlas. Effects keep their colour, motion and crisp
  // silhouette; expensive vector/gradient work happens once, not per particle.
  const cache=new Map(),MAX_BYTES=16*1024*1024,MAX_ENTRIES=384;
  let bytes=0,hits=0,misses=0;
  let signatureBuilds=0,buildBudget=Infinity;
  const warmJobs=[],warmKeys=new Set();let warmScheduled=false,warmGeneration=0;
  function sprite(key,w,h,paint){
    let entry=cache.get(key);
    if(entry){hits++;cache.delete(key);cache.set(key,entry);return entry;}
    if(typeof document==='undefined'||typeof document.createElement!=='function')return null;
    const el=document.createElement('canvas'),ctx=el.getContext?.('2d');if(!ctx)return null;
    w=Math.max(1,Math.ceil(w));h=Math.max(1,Math.ceil(h));
    if(w*h*4>MAX_BYTES)return null;
    el.width=w;el.height=h;paint(ctx,w,h);
    entry={el,w,h,bytes:w*h*4};cache.set(key,entry);bytes+=entry.bytes;misses++;
    while(bytes>MAX_BYTES||cache.size>MAX_ENTRIES){const oldest=cache.keys().next().value;bytes-=cache.get(oldest).bytes;cache.delete(oldest);}
    return entry;
  }
  const alpha=(color,a)=>{
    if(/^#[\da-f]{6}$/i.test(color)){const n=parseInt(color.slice(1),16);return `rgba(${n>>16&255},${n>>8&255},${n&255},${a})`;}
    return a?color:'transparent';
  };
  const density=()=>Math.min(1.5,Math.max(.5,(G.view?.scale||.5)*Math.min((typeof devicePixelRatio==='number'?devicePixelRatio:1)*(window.SlingStage?.k||1),G.state.performanceMode?1:2)));
  function radial(ctx,x,y,r,stops,inner=0){
    if(!(r>0))return true;
    const size=r>200?384:160;
    const key='radial:'+size+':'+inner+':'+stops.map(s=>s.join(':')).join('|');
    const s=sprite(key,size,size,(g,w)=>{
      const gradient=g.createRadialGradient(w/2,w/2,w/2*inner,w/2,w/2,w/2);
      for(const [at,color] of stops)gradient.addColorStop(at,color);
      g.fillStyle=gradient;g.beginPath();g.arc(w/2,w/2,w/2,0,TAU);g.fill();
      // Large low-opacity nebulae otherwise magnify 8-bit alpha bands when
      // stretched. Bake subtle deterministic dither once, never per frame.
      if(size>200&&typeof g.getImageData==='function'){
        const pixels=g.getImageData(0,0,w,w);if(pixels?.data){const data=pixels.data;
          for(let i=3;i<data.length;i+=4){const a=data[i];if(a>2&&a<253)data[i]=a+((Math.imul(i,1597334677)>>>27)%5)-2;}
          g.putImageData(pixels,0,0);
        }
      }
    });
    if(!s)return false;
    ctx.drawImage(s.el,x-r,y-r,r*2,r*2);return true;
  }
  function glow(ctx,x,y,r,color,opacity=1){
    ctx.save();ctx.globalAlpha*=opacity;
    const drawn=radial(ctx,x,y,r,[[0,color],[.35,alpha(color,.45)],[1,'transparent']]);ctx.restore();return drawn;
  }
  function signature(ctx,paint,id,t,r,color,accent,stage){
    if(!(r>0)||!id)return false;
    // Local aura is small and nearly static; impacts get 16 animation poses,
    // smoothly faded/scaled by the caller. Avoid 81 unbounded frame atlases.
    const p=G.reduced?.55:Math.round(Math.max(0,Math.min(1,t))*16)/16;
    const radius=r<=24?16:r<=96?64:r<=160?128:192;
    const d=Math.round(density()*2)/2,pad=radius*1.35+5,size=Math.ceil(pad*2*d);
    const keyFor=pose=>`signature:${id}:${stage==='aura'?'aura':'impact'}:${pose}:${radius}:${d}:${color}:${accent}:${G.reduced}`;
    const key=keyFor(p);
    // New effects must not build seven full atlases on their first frame.
    // Spend at most two cache builds per production frame; a miss beyond that
    // budget reuses an adjacent pose or paints crisp vectors, without delaying feedback.
    if(ctx&&!cache.has(key)){
      if(signatureBuilds>=buildBudget){
        // Reuse an adjacent cached pose for this frame (at most 1/16 lifetime),
        // not dozens of uncached complex vectors. No different skill/colour/density.
        if(!G.reduced)for(const pose of [p-1/16,p+1/16]){const adjacent=keyFor(pose),s=cache.get(adjacent);
          if(!s)continue;hits++;cache.delete(adjacent);cache.set(adjacent,s);
          const half=pad*r/radius;ctx.drawImage(s.el,-half,-half,half*2,half*2);return true;
        }
        return false;
      }
      signatureBuilds++;
    }
    const s=sprite(key,size,size,g=>{g.translate(size/2,size/2);g.scale(d,d);paint(g,id,p,radius,color,accent,stage);});
    if(!s)return false;
    if(ctx){const half=pad*r/radius;ctx.drawImage(s.el,-half,-half,half*2,half*2);}return true;
  }
  function scheduleWarm(delay=0){
    if(warmScheduled||!warmJobs.length||typeof window==='undefined')return;
    const idle=typeof window.requestIdleCallback==='function',timer=typeof window.setTimeout==='function';
    if(!idle&&!timer)return;warmScheduled=true;const generation=warmGeneration;
    const run=()=>{
      if(generation!==warmGeneration)return;warmScheduled=false;
      // Never prebuild while arrows, dragging, a modal or gameplay needs the CPU.
      if(G.phase!=='ready'||G.paused||G.drag||G.arrows?.length||window.SlingBreakIntro?.active||
        typeof document!=='undefined'&&document.querySelector?.('dialog[open]')){scheduleWarm(250);return;}
      const job=warmJobs.shift();warmKeys.delete(job.key);
      if(!G.skillRank||G.skillRank(job.id))signature(null,job.paint,job.id,job.t,job.r,job.color,job.accent,job.stage);
      scheduleWarm();
    };
    // One small atlas pose per idle callback; Chrome 89 gets the same bounded
    // setTimeout fallback when requestIdleCallback is unavailable.
    if(delay&&timer)window.setTimeout(run,delay);
    else if(idle)window.requestIdleCallback(run,{timeout:1000});else window.setTimeout(run,32);
  }
  function prewarm(paint,id,color,accent){
    const poses=G.reduced?[.55]:Array.from({length:17},(_,i)=>i/16);
    for(const t of poses){const key=`${id}:${t}:${color}:${accent}:${G.reduced}`;
      if(warmKeys.has(key)||warmJobs.length>=72)continue;
      warmKeys.add(key);warmJobs.push({key,paint,id,t,r:75,color,accent,stage:'impact'});
    }
    scheduleWarm();
  }
  function vignette(ctx,w,h,color,opacity){
    const s=sprite(`vignette:${color}:${Math.round(h)}`,256,Math.ceil(h/w*256),(g,sw,sh)=>{
      const gradient=g.createRadialGradient(sw/2,sh*.45,sh*.3,sw/2,sh*.45,sh*.75);
      gradient.addColorStop(0,alpha(color,0));gradient.addColorStop(1,color);g.fillStyle=gradient;g.fillRect(0,0,sw,sh);
    });
    if(!s)return false;
    ctx.save();ctx.globalAlpha*=opacity;ctx.drawImage(s.el,0,0,w,h);ctx.restore();return true;
  }
  function layer(ctx,key,w,h,time,paint,resolution=.4,hz=24){
    const sw=Math.ceil(w*resolution),sh=Math.ceil(h*resolution);
    const s=sprite(`layer:${key}:${sw}:${sh}`,sw,sh,()=>{});if(!s)return false;
    const stamp=Math.floor(time*hz);
    if(s.stamp!==stamp){const g=s.el.getContext('2d');g.setTransform(1,0,0,1,0,0);g.clearRect(0,0,sw,sh);g.save();g.scale(resolution,resolution);paint(g);g.restore();s.stamp=stamp;}
    ctx.drawImage(s.el,0,0,w,h);return true;
  }
  function hole(ctx,x,y,r){
    return radial(ctx,x,y,r,[[0,'#000000'],[.6,'rgba(0,0,0,.8)'],[1,'transparent']]);
  }
  function shade(ctx,w,h,x,y,inner,outer,color){
    const res=256/w,sw=256,sh=Math.ceil(h*res);
    const s=sprite(`shade:${w}:${h}:${x}:${y}:${inner}:${outer}:${color}`,sw,sh,g=>{
      const gradient=g.createRadialGradient(x*res,y*res,inner*res,x*res,y*res,outer*res);
      gradient.addColorStop(0,'transparent');gradient.addColorStop(1,color);g.fillStyle=gradient;g.fillRect(0,0,sw,sh);
    });if(!s)return false;ctx.drawImage(s.el,0,0,w,h);return true;
  }
  function shards(ctx,list,time,color,edge,life=1.4,limit=96){
    ctx.save();ctx.fillStyle=color;ctx.strokeStyle=edge;ctx.lineWidth=1;
    const start=Math.max(0,list.length-limit);
    for(let step=0;step<4;step++){
      ctx.beginPath();let count=0;
      for(let i=start;i<list.length;i++){
        const p=list[i],k=1-(time-p.born)/life;if(k<=0||Math.min(3,k*4|0)!==step)continue;
        const c=Math.cos(p.a)*p.s,s=Math.sin(p.a)*p.s;
        ctx.moveTo(p.x+s,p.y-c);ctx.lineTo(p.x+c*.6-s*.4,p.y+s*.6+c*.4);
        ctx.lineTo(p.x-c*.5-s*.5,p.y-s*.5+c*.5);ctx.closePath();count++;
      }
      if(count){ctx.globalAlpha=(step+.5)/4*.8;ctx.fill();ctx.stroke();}
    }
    ctx.restore();
  }
  G.fx={sprite,radial,glow,signature,prewarm,vignette,layer,hole,shade,shards,
    beginFrame:()=>{signatureBuilds=0;buildBudget=2;},
    clear:()=>{cache.clear();bytes=0;warmJobs.length=0;warmKeys.clear();warmGeneration++;warmScheduled=false;},
    stats:()=>({entries:cache.size,bytes,hits,misses,maxBytes:MAX_BYTES,warmPending:warmJobs.length})};
  window.SlingTheme?.onChange(()=>{G.fx.clear();G.prepareSkillFx?.();});
})();
