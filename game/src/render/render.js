(() => {
  'use strict';
  const G=Game,canvas=document.getElementById('game'),mainCtx=canvas.getContext('2d');
  // Drawing helpers paint into `ctx`; cached layers swap it for an offscreen context.
  let ctx=mainCtx;
  const paintInto=(target,fn)=>{const previous=ctx;ctx=target;try{fn();}finally{ctx=previous;}};
  // Every board colour comes from the active theme (palette.js). A theme switch
  // invalidates the cached board layer and core glow so both repaint once.
  const theme=window.SlingTheme;let P=theme.canvas;
  theme.onChange(()=>{P=theme.canvas;boardLayerValid=false;coreGlow.key='';});
  // Hide the board only while the skill draft dialog is actually open.
  const draftDialog=document.getElementById('skill-draft');
  const draftModalOpen=()=>G.holdDraft||G.phase==='draft'&&!!draftDialog?.open;
  let hpLabels=new WeakMap();
  let boardLayerValid=false;
  document.fonts?.addEventListener('loadingdone',()=>{hpLabels=new WeakMap();boardLayerValid=false;});
  const hpLabel=b=>{
    const hp=Math.ceil(b.hp),cached=hpLabels.get(b);
    if(cached&&cached.hp===hp&&cached.w===b.w&&cached.h===b.h&&cached.type===b.type)return cached;
    const text=G.fmt(hp),baseSize=Math.min(b.type==='normal'?23:22,b.h*.65);
    let size=baseSize;
    if(b.type!=='normal'){
      ctx.font=`500 ${baseSize}px "DM Sans", "Noto Sans SC", sans-serif`;
      size*=Math.min(1,(b.w/2-6)/Math.max(1,ctx.measureText(text).width));
    }
    const result={hp,w:b.w,h:b.h,type:b.type,text,size};hpLabels.set(b,result);return result;
  };
   let scale=1,offsetX=0,offsetY=0,cssW=780,cssH=760,prediction=null;
  const resize=()=>{
      // cssW/cssH are stage layout px (fixed on every device, see stage.js); the
      // backing store follows on-screen density (stage scale × DPR) so the board
      // stays sharp, capped so extreme DPR screens don't bloat the buffer.
       const r=canvas.getBoundingClientRect(),stageK=window.SlingStage?.k||1,dpr=Math.min((devicePixelRatio||1)*stageK,G.state.performanceMode?1:2);
     cssW=canvas.clientWidth||r.width;cssH=canvas.clientHeight||r.height;canvas.width=Math.round(cssW*dpr);canvas.height=Math.round(cssH*dpr);prediction=null;boardLayerValid=false;
     scale=Math.min(cssW/G.W,cssH/1100);G.H=cssH/scale;offsetX=(cssW-G.W*scale)/2;offsetY=0;G.origin.y=Math.min(G.H-180,970);
     G.drag=null;G.pointer=null;
    G.view={scale,offsetX,offsetY,width:cssW,height:cssH};
  };
   new ResizeObserver(resize).observe(canvas);window.addEventListener?.('stagechange',resize);G.resizeCanvas=resize;resize();
  const line=(x,y,tx,ty,color,width=1)=>{ctx.strokeStyle=color;ctx.lineWidth=width;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(tx,ty);ctx.stroke();};
  const forceCompat=new URLSearchParams(location.search).get('forceCompat')==='1';
  const useRoundedRectFallback=forceCompat||typeof ctx.roundRect!=='function';
  const rounded=(x,y,w,h,r,color)=>{
    ctx.fillStyle=color;ctx.beginPath();
    const radius=Math.max(0,Math.min(r,Math.abs(w)/2,Math.abs(h)/2));
    if(!useRoundedRectFallback){
      ctx.roundRect(x,y,w,h,radius);
    }else if(radius===0){
      ctx.rect(x,y,w,h);
    }else{
      ctx.moveTo(x+radius,y);ctx.lineTo(x+w-radius,y);
      ctx.arcTo(x+w,y,x+w,y+radius,radius);
      ctx.lineTo(x+w,y+h-radius);ctx.arcTo(x+w,y+h,x+w-radius,y+h,radius);
      ctx.lineTo(x+radius,y+h);ctx.arcTo(x,y+h,x,y+h-radius,radius);
      ctx.lineTo(x,y+radius);ctx.arcTo(x,y,x+radius,y,radius);
      ctx.closePath();
    }
    ctx.fill();
  };
  if(useRoundedRectFallback){
    console.info('[SlingBreak] rounded rectangle compatibility mode enabled');
  }
  const circle=(x,y,r,color)=>{ctx.fillStyle=color;ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill();};
  const label=(text,x,y,size=12,color=P.label,font='DM Sans',weight=500)=>{ctx.font=`${weight} ${size}px "${font}", "Noto Sans SC", sans-serif`;ctx.fillStyle=color;ctx.textAlign='center';ctx.fillText(text,x,y);};
  function glyph(type,x,y,color){
    ctx.save();ctx.translate(x,y);ctx.strokeStyle=color;ctx.fillStyle=color;ctx.lineWidth=1.65;ctx.lineCap='round';ctx.lineJoin='round';
    if(type==='bomb'){for(let i=0;i<8;i++){const a=i*Math.PI/4;line(Math.cos(a)*3,Math.sin(a)*3,Math.cos(a)*8,Math.sin(a)*8,color,1.6);}circle(0,0,2,color);}
    if(type==='lightning'){ctx.beginPath();ctx.moveTo(1,-9);ctx.lineTo(-6,1);ctx.lineTo(0,1);ctx.lineTo(-2,9);ctx.lineTo(6,-2);ctx.lineTo(1,-2);ctx.closePath();ctx.fill();}
    if(type==='frost'){for(let i=0;i<6;i++){ctx.rotate(Math.PI/3);line(0,0,0,-8,color,1.5);line(0,-5,-3,-7,color,1.3);line(0,-5,3,-7,color,1.3);}}
    if(type==='prism'){line(0,8,0,0,color,1.6);line(0,0,-6,-6,color,1.6);line(0,0,6,-6,color,1.6);line(-6,-6,-6,-2,color,1.6);line(-6,-6,-2,-6,color,1.6);line(6,-6,6,-2,color,1.6);line(6,-6,2,-6,color,1.6);}
    if(type==='gold'){ctx.beginPath();ctx.arc(0,0,8,0,Math.PI*2);ctx.stroke();label('¥',0,4,11,color);}
    // Abyss rift bricks (milestone.js).
    if(type==='void'){ctx.beginPath();for(let i=0;i<=28;i++){const a=i*.42,r=1+i*.29;i?ctx.lineTo(Math.cos(a)*r,Math.sin(a)*r):ctx.moveTo(1,0);}ctx.stroke();circle(0,0,1.8,color);}
    if(type==='hydra'){line(0,9,0,1,color,1.7);line(0,1,-6,-7,color,1.7);line(0,1,6,-7,color,1.7);circle(-6,-7,2,color);circle(6,-7,2,color);}
    if(type==='shard'){ctx.beginPath();ctx.moveTo(0,-9);ctx.lineTo(6,0);ctx.lineTo(0,9);ctx.lineTo(-6,0);ctx.closePath();ctx.stroke();line(0,-9,0,9,color,1);}
    if(type==='anchor'){ctx.beginPath();ctx.arc(0,-6,2.6,0,Math.PI*2);ctx.stroke();line(0,-3.4,0,8,color,1.7);line(-4,-1,4,-1,color,1.5);ctx.beginPath();ctx.arc(0,2,7,.35,Math.PI-.35);ctx.stroke();}
    // Milestone boss bricks (boss-*.js).
    if(type==='plate'){ctx.strokeRect(-7,-6,14,12);[[-4,-3],[4,-3],[-4,3],[4,3]].forEach(([x,y])=>circle(x,y,1.3,color));}
    if(type==='magma'){ctx.beginPath();ctx.moveTo(0,-9);ctx.quadraticCurveTo(7,-1,5,4);ctx.quadraticCurveTo(3,9,0,9);ctx.quadraticCurveTo(-3,9,-5,4);ctx.quadraticCurveTo(-7,-1,0,-9);ctx.stroke();circle(0,4,2,color);}
    if(type==='scale'){ctx.beginPath();ctx.moveTo(-7,-3);ctx.quadraticCurveTo(0,-11,7,-3);ctx.stroke();ctx.beginPath();ctx.moveTo(-7,4);ctx.quadraticCurveTo(0,-4,7,4);ctx.stroke();}
    if(type==='star'){ctx.beginPath();for(let i=0;i<10;i++){const a=-Math.PI/2+i*Math.PI/5,r=i%2?3.6:8.5;i?ctx.lineTo(Math.cos(a)*r,Math.sin(a)*r):ctx.moveTo(Math.cos(a)*r,Math.sin(a)*r);}ctx.closePath();ctx.fill();}
    if(type==='hour'){line(-6,-8,6,-8,color,1.6);line(-6,8,6,8,color,1.6);ctx.beginPath();ctx.moveTo(-5,-8);ctx.lineTo(5,8);ctx.moveTo(5,-8);ctx.lineTo(-5,8);ctx.stroke();circle(0,5,1.6,color);}
    ctx.restore();
  }
  function arrow(x,y,angle,color=P.arrow.shaft,alpha=1){
    ctx.save();ctx.globalAlpha=alpha;ctx.translate(x,y);ctx.rotate(angle);ctx.lineCap='round';line(-29,0,4,0,color,2.3);
    ctx.fillStyle=color;ctx.beginPath();ctx.moveTo(10,0);ctx.lineTo(0,-4);ctx.lineTo(0,4);ctx.closePath();ctx.fill();
    line(-23,0,-29,-4,P.arrow.fletch,2);line(-23,0,-29,4,P.arrow.fletch,2);ctx.restore();
  }
  function drawCore(){
    const c=G.core;if(!c)return;
    const age=G.time-c.born,pulse=Math.sin(G.time*3);
    // Materialise: a scan line sweeps in, four brackets converge, then the
    // diamond snaps into place with an elastic overshoot and a quarter spin.
    const t=Math.max(0,Math.min(1,(age-.25)/.85)),entrance=t===0?0:t===1?1:2**(-10*t)*Math.sin((t*10-.75)*2*Math.PI/3)+1;
    if(age<1.2){
      const sweep=Math.min(1,age/.45),fade=1-Math.max(0,(age-.6)/.6);
      ctx.save();ctx.globalAlpha=fade*.8;ctx.strokeStyle=P.core.line;ctx.lineWidth=2;
      line(c.x-330*sweep,c.y,c.x-60,c.y,P.core.line,2);line(c.x+60,c.y,c.x+330*sweep,c.y,P.core.line,2);
      const gap=58-38*Math.min(1,age/.5)**2,arm=12;
      for(const [sx,sy] of [[-1,-1],[1,-1],[1,1],[-1,1]]){
        ctx.beginPath();ctx.moveTo(c.x+sx*gap,c.y+sy*(gap-arm));ctx.lineTo(c.x+sx*gap,c.y+sy*gap);ctx.lineTo(c.x+sx*(gap-arm),c.y+sy*gap);ctx.stroke();
      }
      ctx.restore();
    }
    ctx.save();ctx.translate(c.x,c.y);ctx.scale(entrance,entrance);ctx.rotate((1-Math.min(1,t*1.4))*-Math.PI/2);
    ctx.strokeStyle=P.core.ring;ctx.lineWidth=1;ctx.globalAlpha=.5;
    for(let i=0;i<2;i++){ctx.save();ctx.rotate(G.time*(i?-.5:.4));ctx.setLineDash([12,8,3,8]);ctx.beginPath();ctx.arc(0,0,40+i*10+pulse*2,0,Math.PI*2);ctx.stroke();ctx.restore();}
    ctx.globalAlpha=1;ctx.rotate(Math.PI/4);
    // The pulsing glow is quantised to 1/4 px so a settled core can blit a
    // cached shadow sprite instead of re-blurring every frame.
    const blur=G.reduced?0:Math.round((18+pulse*6)*4)/4;
    // A drifting core (milestone.js) moves every frame, so it blurs live.
    if(!(blur&&age>=1.1&&!G.shake&&!c.drifting&&drawCoreGlowSprite(blur,c))){ctx.shadowColor=P.core.glow;ctx.shadowBlur=blur;}
    rounded(-21,-21,42,42,4,P.core.face);ctx.shadowBlur=0;ctx.strokeStyle=P.core.frame;ctx.lineWidth=1.5;ctx.strokeRect(-14,-14,28,28);ctx.fillStyle=P.core.heart;ctx.fillRect(-4,-4,8,8);ctx.restore();
    label('THE CORE',c.x,49,9,P.core.label,'DM Sans',600);
  }
  // Shadow-only sprites of the settled core, keyed by blur and device placement.
  // shadowBlur/shadowOffset ignore the transform, so the shape is drawn far off
  // the sprite and only its shadow is offset back in; the crisp face is still
  // painted live on top, exactly as a direct shadowed fill would composite.
  const coreGlow={key:'',sprites:new Map()},GLOW_OFFSET=4096;
  function drawCoreGlowSprite(blur,c){
    if(typeof document.createElement!=='function')return false;
    const dpr=canvas.width/cssW,s=scale*dpr;
    const cx=(offsetX+c.x*scale)*dpr,cy=(offsetY+c.y*scale)*dpr;
    const key=`${s}:${cx}:${cy}`;
    if(coreGlow.key!==key){coreGlow.key=key;coreGlow.sprites.clear();}
    let sprite=coreGlow.sprites.get(blur);
    if(!sprite){
      // Half-diagonal of the rotated 42px square plus Skia's ~3σ blur reach.
      const reach=Math.ceil(21*Math.SQRT2*s+blur*1.5+4),size=reach*2;
      const ox=Math.floor(cx)-reach,oy=Math.floor(cy)-reach;
      const el=document.createElement('canvas');el.width=size;el.height=size;
      const g=el.getContext('2d');
      g.setTransform(s*Math.SQRT1_2,s*Math.SQRT1_2,-s*Math.SQRT1_2,s*Math.SQRT1_2,cx-ox-GLOW_OFFSET,cy-oy);
      g.shadowColor=P.core.glow;g.shadowBlur=blur;g.shadowOffsetX=GLOW_OFFSET;
      paintInto(g,()=>rounded(-21,-21,42,42,4,P.core.face));
      sprite={el,ox,oy};coreGlow.sprites.set(blur,sprite);
    }
    ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.drawImage(sprite.el,sprite.ox,sprite.oy);ctx.restore();
    return true;
  }
   const PREDICTION_MAX=720,PREDICTION_FADE_START=500;
   const predictionColor=ready=>{
     const t=Math.max(0,Math.min(1,1-(G.nextShotAt-G.time)/.5)),eased=t*t*t;
     const start=P.aim.charging.match(/\w{2}/g).map(v=>parseInt(v,16)),end=ready.match(/\w{2}/g).map(v=>parseInt(v,16));
     return `rgb(${start.map((v,i)=>Math.round(v+(end[i]-v)*eased)).join(',')})`;
   };
   const smoothPrediction=(current,now)=>{
     if(!current.from)return current.path;
     const blend=Math.min(1,(now-current.at)/48),ease=1-(1-blend)**3,from=current.from,path=current.path,display=current.display;
     display.length=path.length;
     for(let i=0;i<path.length;i++){
       const start=from[Math.min(i,from.length-1)],end=path[i],point=display[i]||{};
       point.x=start.x+(end.x-start.x)*ease;point.y=start.y+(end.y-start.y)*ease;display[i]=point;
     }
     return display;
   };
  function drawSling(){
    const {x,y}=G.origin,d=G.drag,px=x+(d?.dx||0),py=y+(d?.dy||0);
    ctx.save();ctx.globalAlpha=.72;ctx.setLineDash([4,6]);ctx.strokeStyle=P.sling.range;ctx.lineWidth=1.5;ctx.beginPath();ctx.arc(x,y,79,0,Math.PI*2);ctx.stroke();ctx.restore();
    const S=P.sling;circle(x,y,48,S.pad);
    ctx.lineCap='round';line(x,y+53,x,y+16,S.frame,12);line(x,y+16,x-23,y-14,S.frame,10);line(x,y+16,x+23,y-14,S.frame,10);
    line(x-23,y-14,px,py,S.band,3);line(x+23,y-14,px,py,S.band,3);
    line(px-5,py,px+5,py,S.pouch,5);circle(x-23,y-14,3,S.knob);circle(x+23,y-14,3,S.knob);
     if(['ready','flying'].includes(G.phase)){
      const angle=d?Math.atan2(-d.dy,-d.dx):-Math.PI/2+G.keyboardAngle;
      arrow(px,py-4,angle);
      if(d&&d.dy>5){
        const len=Math.hypot(d.dx,d.dy),speed=G.speed()*(.56+.44*Math.min(1,len/100));
         const key=[Math.round(d.dx),Math.round(d.dy),G.predictionVersion,G.physicsStep,G.speed()].join(':');
         const now=performance.now();
         const interval=33;
         if(!prediction||prediction.key!==key&&now-prediction.at>=interval){
           const path=G.predictPath(x,y,-d.dx/len*speed,-d.dy/len*speed,PREDICTION_MAX),from=prediction?.display||prediction?.path;
           prediction={key,at:now,path,from:from?.map(point=>({x:point.x,y:point.y})),display:path.map(point=>({x:point.x,y:point.y}))};
         }
         const path=smoothPrediction(prediction,now);
        let travelled=0;
         // Enhanced glow for better feel — shadowBlur bumped from 5→9
         ctx.save();ctx.strokeStyle=predictionColor(P.aim.line);ctx.lineWidth=2.6;ctx.lineCap='round';ctx.lineJoin='round';ctx.shadowColor=predictionColor(P.aim.glow);ctx.shadowBlur=9;
        for(let i=1;i<path.length;i++){
          const a=path[i-1],b=path[i],segment=Math.hypot(b.x-a.x,b.y-a.y),fade=Math.min(1,Math.max(0,(PREDICTION_MAX-travelled)/(PREDICTION_MAX-PREDICTION_FADE_START)));
          if(fade<=0)break;ctx.globalAlpha=.9*fade;ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke();travelled+=segment;
        }
        ctx.restore();travelled=0;
         const dotColor=predictionColor(P.aim.dot);
         // Trail dots slightly larger (2.8→3.0) and a touch more opaque for snappier read
         path.forEach((p,i)=>{if(i>0)travelled+=Math.hypot(p.x-path[i-1].x,p.y-path[i-1].y);if(i%6===0){const fade=Math.min(1,Math.max(0,(PREDICTION_MAX-travelled)/(PREDICTION_MAX-PREDICTION_FADE_START)));ctx.globalAlpha=.9*fade;circle(p.x,p.y,3.0,dotColor);}});ctx.globalAlpha=1;
      }else{
         ctx.save();ctx.globalAlpha=.8;ctx.setLineDash([4,7]);line(x,y-65,x+Math.sin(G.keyboardAngle)*40,y-110,predictionColor(P.aim.keyboard),1.7);ctx.restore();
      }
    }
    for(let i=0;i<5;i++){const active=d&&Math.hypot(d.dx,d.dy)>i*20;rounded(x-22+i*10,y+75,5,4,1,active?S.meterOn:S.meterOff);}
  }
  function drawPointer(){
    const p=G.pointerPos;if(!p||G.pointerType==='touch')return;
    ctx.save();ctx.translate(p.x,p.y);const ink=P.pointer;ctx.strokeStyle=ink;ctx.fillStyle=ink;ctx.lineWidth=2;ctx.lineCap='round';
    line(-9,0,-3,0,ink,2);line(3,0,9,0,ink,2);line(0,-9,0,-3,ink,2);line(0,3,0,9,ink,2);
    circle(0,0,2,ink);ctx.restore();
  }
  function boardItemEntrance(item){
    ctx.save();
    if(!G.boardEntrance)return 1;
    const o=G.boardEntrance.origin;
    if(o){
      // Impact ripple: bricks pop in outward from where the drafted skill landed,
      // blown slightly away from the origin before springing back into place.
      const dx=item.x-o.x,dy=item.y-o.y,d=Math.hypot(dx,dy)||1;
      const p=Math.max(0,Math.min(1,(G.time-G.boardEntrance.start-Math.min(.55,d/1600))/.46));
      const back=1+2.70158*(p-1)**3+1.70158*(p-1)**2,push=24*(1-p)**2,size=.72+.28*back;
      ctx.translate(item.x+dx/d*push,item.y+dy/d*push);ctx.scale(size,size);ctx.translate(-item.x,-item.y);
      const alpha=Math.min(1,p*2.4);ctx.globalAlpha=alpha;
      return alpha;
    }
    const delay=Math.max(0,(item.y-170)/60)*.035+(item.x/780)*.045;
    const progress=Math.max(0,Math.min(1,(G.time-G.boardEntrance.start-delay)/.42));
    const eased=1-(1-progress)**3,size=.88+.12*eased;
    ctx.translate(item.x,item.y-26*(1-eased));ctx.scale(size,size);ctx.translate(-item.x,-item.y);
    ctx.globalAlpha=eased;
    return eased;
  }
   // Particles are tiny solid squares. Painting them one at a time pays a full
   // save/restore, a translate+rotate and a colour-string parse per particle,
   // which dominates the frame once there are hundreds of them. Instead bucket
   // them by paint style (colour + quantised alpha) and emit one path fill per
   // style: no per-particle transform or state churn, and each colour is parsed
   // once per frame instead of once per particle. Buckets are reused across
   // frames, so the steady state allocates nothing.
   const PARTICLE_ALPHA_STEPS = 8;
   const particleColorIds = new Map();
   const particleBuckets = [];
   const drawParticles = () => {
     for (const p of G.particles) {
       // Colour id is cached on the particle so the per-frame hot loop does no
       // string hashing or allocation; alpha is quantised into fixed steps.
       let id = p._pid;
       if (id === undefined) {
         id = particleColorIds.get(p.color);
         if (id === undefined) { id = particleColorIds.size; particleColorIds.set(p.color, id); }
         p._pid = id;
       }
       const alpha = p.life * 2;
       const step = alpha >= 1 ? PARTICLE_ALPHA_STEPS : alpha <= 0 ? 0 : (alpha * PARTICLE_ALPHA_STEPS) | 0;
       const index = id * (PARTICLE_ALPHA_STEPS + 1) + step;
       let bucket = particleBuckets[index];
       if (bucket === undefined) particleBuckets[index] = bucket = { color: p.color, alpha: step / PARTICLE_ALPHA_STEPS, list: [] };
       bucket.list.push(p);
     }
     ctx.globalAlpha = 1;
     for (const bucket of particleBuckets) {
       if (bucket === undefined) continue;
       const list = bucket.list;
       if (list.length === 0) continue;
       if (bucket.alpha > 0) {
         ctx.globalAlpha = bucket.alpha;
         ctx.fillStyle = bucket.color;
         ctx.beginPath();
         for (let i = 0; i < list.length; i++) {
           const p = list[i], half = p.size / 2;
           ctx.rect(p.x - half, p.y - half, p.size, p.size);
         }
         ctx.fill();
       }
       list.length = 0;
     }
     ctx.globalAlpha = 1;
   };
    function drawRings(){
      // Bound overdraw even if a debug harness fills the array directly.
      // Giant core/boss pulses remain visible alongside the freshest impacts.
      const limit=G.reduced?12:24,start=Math.max(0,G.rings.length-limit);
      const paint=r=>{const t=r.life/r.max,energy=r.energy||1;
        ctx.globalAlpha=Math.min(.85,t*.65*energy);ctx.strokeStyle=r.color;ctx.lineWidth=energy>1?2.8:2;
        ctx.beginPath();ctx.arc(r.x,r.y,r.r*(1-t),0,Math.PI*2);ctx.stroke();
      };
      let heroes=0;for(let i=start-1;i>=0&&heroes<3;i--)if(G.rings[i].r>=260){paint(G.rings[i]);heroes++;}
      for(let i=start;i<G.rings.length;i++)paint(G.rings[i]);ctx.globalAlpha=1;
    }
    function drawBolts(){
      const limit=G.reduced?24:48,start=Math.max(0,G.bolts.length-limit),stamp=Math.floor(G.time*24);
      ctx.strokeStyle=P.bolt;ctx.lineCap='round';ctx.lineJoin='round';
      for(let step=0;step<4;step++){
        ctx.beginPath();let count=0;
        for(let n=start;n<G.bolts.length;n++){
          const b=G.bolts[n],alpha=Math.min(1,b.life*4);if(Math.min(3,alpha*4|0)!==step)continue;
          let path=b._path;if(!path)b._path=path=new Float32Array(10);
          if(b._stamp!==stamp){for(let i=1;i<6;i++){const jitter=Math.sin((stamp+n*13+i*7)*2.17)*9;
            path[(i-1)*2]=b.x+(b.tx-b.x)*i/6+jitter;path[(i-1)*2+1]=b.y+(b.ty-b.y)*i/6-jitter*.7;
          }b._stamp=stamp;}
          ctx.moveTo(b.x,b.y);for(let i=0;i<10;i+=2)ctx.lineTo(path[i],path[i+1]);ctx.lineTo(b.tx,b.ty);count++;
        }
        if(count){ctx.globalAlpha=(step+.5)/4;ctx.lineWidth=2.5;ctx.stroke();
          if(!G.reduced){
            // Only the newest eight arcs get the wide corona. Their thin
            // electrical cores, including older arcs, remain fully visible.
            ctx.beginPath();let glow=0;
            for(let n=Math.max(start,G.bolts.length-8);n<G.bolts.length;n++){const b=G.bolts[n];
              if(Math.min(3,Math.min(1,b.life*4)*4|0)!==step)continue;
              ctx.moveTo(b.x,b.y);for(let i=0;i<10;i+=2)ctx.lineTo(b._path[i],b._path[i+1]);ctx.lineTo(b.tx,b.ty);glow++;
            }
            if(glow){ctx.globalAlpha*=.18;ctx.lineWidth=5;ctx.stroke();}
          }
        }
      }
      ctx.globalAlpha=1;
    }
    function render(){
    G.flushUi?.();G.flushVisuals?.();
    G.fx?.beginFrame();
    const dpr=canvas.width/cssW;ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,cssW,cssH);
    ctx.save();ctx.translate(offsetX,offsetY);ctx.scale(scale,scale);
    if(!G.reduced && G.shake)ctx.translate((Math.random()-.5)*G.shake,(Math.random()-.5)*G.shake);
    ctx.strokeStyle=P.guide;ctx.lineWidth=1;ctx.setLineDash([3,7]);ctx.beginPath();ctx.moveTo(85,G.origin.y-130);ctx.lineTo(695,G.origin.y-130);ctx.stroke();ctx.setLineDash([]);
    if(!draftModalOpen()){
    // Milestone bosses (boss-*.js) paint their body under the bricks.
    G.drawBossBackdrop?.(ctx);
    drawBoardCached();
    drawCore();
    G.drawSkillMechanics?.(ctx);
    G.drawSkillEffects?.(ctx,'field');
    }
    drawRings();drawBolts();
    // Arrow trail alpha bumped from .3→.45, dot radius from 1.8→2.2 for snappier feel
    G.arrows.forEach(a=>{if(!a.skillVisual){ctx.fillStyle=a.color||P.arrow.trail;
      for(let step=0;step<3;step++){ctx.globalAlpha=(step+1)/3*.45;ctx.beginPath();
        for(let i=0;i<a.trail.length;i+=G.arrows.length>24?2:1)if(Math.min(2,i/a.trail.length*3|0)===step){const p=a.trail[i];ctx.moveTo(p.x+2.2,p.y);ctx.arc(p.x,p.y,2.2,0,Math.PI*2);}
        ctx.fill();
      }
    }ctx.globalAlpha=1;arrow(a.body.position.x,a.body.position.y,Math.atan2(a.body.velocity.y,a.body.velocity.x),a.color||P.arrow.shaft);});
    drawSling();
    G.drawSkillEffects?.(ctx,'front');
    drawParticles();
    for(let i=Math.max(0,G.texts.length-48);i<G.texts.length;i++){const p=G.texts[i];ctx.globalAlpha=Math.min(1,p.life*2);label(p.text,p.x,p.y,p.size,p.color,'DM Sans',600);}ctx.globalAlpha=1;
    if(G.coreFlash>0){ctx.fillStyle=`rgba(${P.coreFlash},${G.coreFlash*.13})`;ctx.fillRect(0,0,780,G.H);}
    drawPointer();
    ctx.restore();
  }
  // Bricks and barriers are static between hits, so the settled board is
  // rasterised once into a device-resolution layer and blitted 1:1. Anything
  // animating (entrance, hit flash, screen shake) paints live as before.
  const boardLayer=typeof document.createElement==='function'?document.createElement('canvas'):null;
  const boardLayerCtx=boardLayer?.getContext?.('2d')||null;
  const typeIds={normal:1,bomb:2,lightning:3,frost:4,prism:5,gold:6,void:7,hydra:8,shard:9,anchor:10,plate:11,magma:12,scale:13,star:14,hour:15};
  let boardState=[],nextBoardState=[];
  const boardChanged=()=>{
    const s=nextBoardState;s.length=0;
    for(const b of G.bricks)if(!b.orbit)s.push(b.x,b.y,b.w,b.h,Math.ceil(b.hp),b.hp<b.max?1:0,b.max,typeIds[b.type]||0,b.frozen?1:0);
    s.push(-1);
    for(const o of G.obstacles)s.push(o.x,o.y,o.w,o.h);
    let changed=s.length!==boardState.length;
    for(let i=0;!changed&&i<s.length;i++)changed=s[i]!==boardState[i];
    if(changed){nextBoardState=boardState;boardState=s;}
    return changed;
  };
  const boardAnimating=()=>{
    if(G.boardEntrance||(!G.reduced&&G.shake))return true;
    for(const b of G.bricks)if(b.flash>0&&!b.orbit)return true;
    for(const o of G.obstacles)if(o.flash>0)return true;
    return false;
  };
  function drawBoardCached(){
    // A change seen while painting live (e.g. hp drops in the same frame the
    // hit flash starts) must still invalidate the layer for when it settles.
    if(boardChanged())boardLayerValid=false;
    // Orbiting bricks move every frame, so they stay out of the cached layer.
    if(!boardLayerCtx||boardAnimating()){drawBoard();drawOrbiting();return;}
    if(!boardLayerValid){
      if(boardLayer.width!==canvas.width||boardLayer.height!==canvas.height){boardLayer.width=canvas.width;boardLayer.height=canvas.height;}
      const dpr=canvas.width/cssW;
      boardLayerCtx.save();boardLayerCtx.setTransform(1,0,0,1,0,0);boardLayerCtx.clearRect(0,0,boardLayer.width,boardLayer.height);
      boardLayerCtx.setTransform(dpr*scale,0,0,dpr*scale,dpr*offsetX,dpr*offsetY);
      paintInto(boardLayerCtx,drawBoard);
      boardLayerCtx.restore();boardLayerValid=true;
    }
    ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.drawImage(boardLayer,0,0);ctx.restore();
    drawOrbiting();
  }
  function drawOrbiting(){for(const b of G.bricks)if(b.orbit&&!b.skin)drawBrick(b);}
  function drawBoard(){
    for(const b of G.bricks)if(!b.orbit)drawBrick(b);
    drawObstacles();
  }
  function drawBrick(b){
    {
      const alpha=boardItemEntrance(b);
      const color=b.frozen?P.frozen:P.brick[b.type];
      rounded(b.x-b.w/2,b.y-b.h/2+3,b.w,b.h,5,b.frozen?color:P.brickEdge[b.type]||color);
      rounded(b.x-b.w/2,b.y-b.h/2,b.w,b.h-1,5,color);
      if(b.flash>0){ctx.globalAlpha=b.flash*3*alpha;rounded(b.x-b.w/2,b.y-b.h/2,b.w,b.h,5,P.flash);ctx.globalAlpha=alpha;}
      const ink=P.brickInk[b.type];
      if(b.type!=='normal'){
        const showHp=b.max>1;
        ctx.save();ctx.translate(b.x-(showHp?b.w/4:0),b.y);
        const size=showHp?Math.min(1,b.h/32,b.w/64):Math.min(1,b.h/27);
        ctx.scale(size,size);glyph(b.type,0,0,ink);ctx.restore();
        if(showHp){
          const {text,size:fontSize}=hpLabel(b);
          label(text,b.x+b.w/4,b.y+fontSize/3,fontSize,ink);
        }
      }
       else if(b.max>1){const {text,size}=hpLabel(b);label(text,b.x,b.y+size/3,size,ink);}
      else{ctx.globalAlpha=.45*alpha;line(b.x-7,b.y,b.x+7,b.y,ink,1.1);ctx.globalAlpha=alpha;}
      if(b.hp<b.max){ctx.strokeStyle=P.crack;ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(b.x-b.w/2+5,b.y-b.h/2);ctx.lineTo(b.x-b.w/2+10,b.y-3);ctx.lineTo(b.x-b.w/2+6,b.y+2);ctx.stroke();}
      if(b.frozen){ctx.strokeStyle=P.frozenEdge;ctx.lineWidth=1;ctx.strokeRect(b.x-b.w/2+2,b.y-b.h/2+2,b.w-4,b.h-4);}
      ctx.restore();
    }
  }
  function drawObstacles(){
    for(const o of G.obstacles){
      const alpha=boardItemEntrance(o);
      const left=o.x-o.w/2,top=o.y-o.h/2,O=P.obstacle;
      rounded(left,top+3,o.w,o.h,4,O.shadow);rounded(left,top,o.w,o.h,4,O.face);
      line(left+6,top+3,left+o.w-6,top+3,O.rim,1);
      ctx.save();ctx.beginPath();ctx.rect(left+3,top+5,o.w-6,o.h-10);ctx.clip();
      for(let x=left-20;x<left+o.w;x+=11)line(x,top+o.h,x+o.h,top,O.stripe,3);
      ctx.restore();
      rounded(o.x-8,o.y-6,16,12,3,O.plate);line(o.x-4,o.y,o.x+4,o.y,O.slot,2);
      [left+5,left+o.w-5].forEach(x=>circle(x,o.y,1.3,O.rivet));
      if(o.flash>0){ctx.globalAlpha=o.flash*3*alpha;rounded(left,top,o.w,o.h,4,O.flash);ctx.globalAlpha=alpha;}
      ctx.restore();
    }
  }
  // Client px → canvas layout px (undoes the stage scale), then → world units.
  const point=e=>{const r=canvas.getBoundingClientRect(),k=r.width/cssW||1;return{x:((e.clientX-r.left)/k-offsetX)/scale,y:((e.clientY-r.top)/k-offsetY)/scale};};
  let drawStep=0;
  const updatePointer=e=>{if(e.pointerType!=='touch'){G.pointerType=e.pointerType;G.pointerPos=point(e);}};
   const powerReadout=document.querySelector('#power-readout b');
   const updateDrag=e=>{const p=point(e);if(e.pointerType!=='touch'){G.pointerType=e.pointerType;G.pointerPos=p;}let dx=p.x-G.origin.x,dy=p.y-G.origin.y;dy=Math.max(0,dy);const len=Math.hypot(dx,dy);if(len>105){dx*=105/len;dy*=105/len;}G.drag={dx,dy};const power=Math.min(100,len),step=Math.floor(power/20);if(step>drawStep)G.sound('draw',step);drawStep=step;const text=Math.round(power)+'%';if(powerReadout.textContent!==text)powerReadout.textContent=text;};
  canvas.addEventListener('pointerenter',updatePointer);
  canvas.addEventListener('pointerleave',()=>{if(!G.drag)G.pointerPos=null;});
  canvas.addEventListener('pointerdown',e=>{
     if(G.paused||!['ready','flying'].includes(G.phase)||e.button>0)return;
    const p=point(e);if(Math.hypot(p.x-G.origin.x,p.y-G.origin.y)>120)return;
    G.audio.unlock();updatePointer(e);drawStep=0;canvas.setPointerCapture(e.pointerId);canvas.focus({preventScroll:true});G.drag={dx:0,dy:0};G.pointer=e.pointerId;G.ui();
  });
  canvas.addEventListener('pointermove',e=>{if(G.drag&&G.pointer===e.pointerId)updateDrag(e);else updatePointer(e);});
  canvas.addEventListener('pointerup',e=>{if(!G.drag||G.pointer!==e.pointerId)return;const {dx,dy}=G.drag;G.drag=null;G.pointer=null;G.shoot(dx,dy);G.ui();});
  const cancel=()=>{G.drag=null;G.pointer=null;G.pointerPos=null;G.ui();};canvas.addEventListener('pointercancel',cancel);canvas.addEventListener('lostpointercapture',()=>{if(G.drag)cancel();});
  canvas.addEventListener('keydown',e=>{
     if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown',' '].includes(e.key))return;e.preventDefault();if(G.paused||!['ready','flying'].includes(G.phase))return;
    if(e.key==='ArrowLeft')G.keyboardAngle=Math.max(-1.1,G.keyboardAngle-.07);
    if(e.key==='ArrowRight')G.keyboardAngle=Math.min(1.1,G.keyboardAngle+.07);
    if(e.key==='ArrowUp')G.keyboardPower=Math.min(1,G.keyboardPower+.05);
    if(e.key==='ArrowDown')G.keyboardPower=Math.max(.2,G.keyboardPower-.05);
    if(e.key===' '&&!e.repeat)G.shoot(-Math.sin(G.keyboardAngle)*100*G.keyboardPower,Math.cos(G.keyboardAngle)*100*G.keyboardPower);
  });
   let last=performance.now(),acc=0;
   function frame(now){const gap=now-last;if(gap>50&&window.SlingAudioDiagnostics?.enabled)window.SlingAudioDiagnostics.record('frame-gap',{durationMs:gap,hidden:document.hidden,paused:G.paused});const delta=Math.min(gap/1000,.05);last=now;acc+=delta;let steps=0;while(acc>=G.physicsStep&&steps++<4){G.tick(G.physicsStep);acc-=G.physicsStep;}if(steps===4)acc=0;render();requestAnimationFrame(frame);}
   requestAnimationFrame(frame);
})();
