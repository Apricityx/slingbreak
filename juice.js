(() => {
  'use strict';
  // Game feel: escalating combo feedback, near-core slow motion, big-chain
  // hit-stop, merged income tallies, record moments and the per-level report.
  // Everything wraps existing entry points; balance and rewards are untouched.
  const G=Game,$=id=>document.getElementById(id);
  const motion=matchMedia('(prefers-reduced-motion: reduce)'),still=()=>motion.matches;
  const arena=$('arena'),canvas=$('game'),combo=$('combo');
  const tierNames=['','连击','势不可挡','满倍率'],tierColors=['#566e37','#5f8a2f','#c9812a','#d0572c'];
  const tierOf=kills=>{const cap=G.comboCapKills();return kills>=cap?3:kills>=Math.max(5,Math.ceil(cap*.66))?2:kills>=4?1:0;};

  // ── Time control. Slow motion scales dt; hit-stop skips simulation entirely.
  let scale=1,slowUntil=0,freezeUntil=0,slowCore=null,lastChainStop=0,tickKills=0;
  const vignette=document.createElement('div');vignette.className='slowmo-vignette';vignette.setAttribute('aria-hidden','true');arena.append(vignette);
  const hitstop=ms=>{if(!still())freezeUntil=Math.max(freezeUntil,performance.now()+ms);};
  function toClient(x,y){const r=canvas.getBoundingClientRect(),v=G.view||{scale:r.width/G.W,offsetX:0,offsetY:0};return{x:v.offsetX+x*v.scale,y:v.offsetY+y*v.scale};}
  let zoom=null;
  function startSlow(){
    scale=.22;slowUntil=performance.now()+620;arena.classList.add('is-slowmo');
    const p=toClient(G.core.x,G.core.y);canvas.style.transformOrigin=`${p.x}px ${p.y}px`;
    zoom?.cancel();zoom=canvas.animate([{scale:'1'},{scale:'1.05'}],{duration:260,easing:'cubic-bezier(.22,1,.36,1)',fill:'forwards'});
    G.sound('draw',5,G.core.x);
  }
  function endSlow(){
    if(scale===1)return;
    scale=1;slowUntil=0;arena.classList.remove('is-slowmo');
    zoom?.cancel();zoom=canvas.animate([{scale:'1.05'},{scale:'1'}],{duration:300,easing:'cubic-bezier(.22,1,.36,1)'});
  }
  // An arrow about to reach the core stretches the moment before impact.
  function watchCore(){
    const c=G.core;
    if(!c||slowCore===c||G.phase!=='flying'||still()||G.time-c.born<1.1)return;
    for(const a of G.arrows){
      const p=a.body.position,v=a.body.velocity,rx=c.x-p.x,ry=c.y-p.y,vv=v.x*v.x+v.y*v.y;if(vv<1)continue;
      const t=(rx*v.x+ry*v.y)/vv;if(t<0||t>9)continue;
      if(Math.hypot(rx-v.x*t,ry-v.y*t)<34){slowCore=c;startSlow();return;}
    }
  }

  // ── Merged income tallies: one growing number per arrow instead of a +N per brick.
  const tallies=[];let pending=null;
  const float=G.float;
  G.float=(x,y,text,...rest)=>{
    if(pending!==null&&!rest.length&&text==='+'+G.fmt(pending)){
      const money=pending;pending=null;
      const a=G.activeArrow,kills=G.arrowKills(a);
      let t=tallies.find(t=>t.arrow===a&&t.life>.35);
      if(!t&&tallies.length>=8)t=tallies.at(-1);
      if(!t){t={arrow:a,x,y:y-26,tx:x,ty:y-26,total:0,count:0,life:0,pop:0,callout:null};tallies.push(t);}
      t.total+=money;t.count++;t.kills=Math.max(kills,t.count);t.tx=x;t.ty=y-26;t.life=1.25;t.pop=1;
      return;
    }
    pending=null;return float(x,y,text,...rest);
  };
  function updateTallies(dt){
    let alive=0;
    for(const t of tallies){
      const k=Math.min(1,dt*12);t.x+=(t.tx-t.x)*k;t.y+=(t.ty-t.y)*k;
      t.life-=dt;t.pop=Math.max(0,t.pop-dt*5);if(t.life<.5)t.ty-=dt*40;
      if(t.callout){t.callout.life-=dt;if(t.callout.life<=0)t.callout=null;}
      if(t.life>0)tallies[alive++]=t;
    }
    tallies.length=alive;
  }
  function drawTallies(ctx){
    ctx.save();ctx.textAlign='center';ctx.lineJoin='round';
    for(const t of tallies){
      const tier=tierOf(t.kills),size=17+Math.min(20,Math.log2(t.count+1)*4.2)+(still()?0:t.pop*7);
      ctx.globalAlpha=Math.min(1,t.life*2.4);
      ctx.font=`700 ${size}px "DM Sans","Noto Sans SC",sans-serif`;ctx.lineWidth=5;ctx.strokeStyle='#fafbf7';
      const text='+'+G.fmt(t.total);ctx.strokeText(text,t.x,t.y);ctx.fillStyle=tierColors[tier];ctx.fillText(text,t.x,t.y);
      if(t.count>1){ctx.font='600 12px "DM Sans","Noto Sans SC",sans-serif';ctx.lineWidth=4;const sub=`${t.count} 块`;ctx.strokeText(sub,t.x,t.y+16);ctx.fillStyle='#7d8b6c';ctx.fillText(sub,t.x,t.y+16);}
      if(t.callout){
        const c=t.callout,p=1-c.life/.9;ctx.globalAlpha=Math.min(1,c.life*3);
        ctx.font=`800 ${16+(1-Math.min(1,p*4))*10}px "Noto Sans SC","DM Sans",sans-serif`;ctx.lineWidth=5;
        ctx.strokeText(c.text,t.x,t.y-size-4-p*14);ctx.fillStyle=tierColors[c.tier];ctx.fillText(c.text,t.x,t.y-size-4-p*14);
      }
    }
    ctx.restore();
  }
  // Overdrive arrows (at the combo cap) burn a hot trail.
  function drawOverdrive(ctx){
    for(const a of G.arrows){
      if(!a.overdrive||a.trail.length<2)continue;
      ctx.save();ctx.lineCap='round';ctx.lineJoin='round';ctx.strokeStyle='#f0a13a';ctx.lineWidth=5;
      if(!G.reduced){ctx.shadowColor='#ffb347';ctx.shadowBlur=14;}
      ctx.globalAlpha=.75;ctx.beginPath();a.trail.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.lineTo(a.body.position.x,a.body.position.y);ctx.stroke();
      ctx.shadowBlur=0;ctx.strokeStyle='#fff3cf';ctx.lineWidth=1.6;ctx.stroke();ctx.restore();
    }
  }
  const drawEffects=G.drawSkillEffects;
  G.drawSkillEffects=(ctx,layer,...rest)=>{
    const result=drawEffects?.(ctx,layer,...rest);
    if(layer==='field')drawOverdrive(ctx);
    if(layer==='front')drawTallies(ctx);
    return result;
  };

  // ── Record moment: beating the single-arrow best lights up once per round.
  let baseline=Infinity,recordArrow=null,banner=null;
  function showRecord(kills,previous,b){
    hitstop(90);G.ring(b.x,b.y,'#e0ad2c',260);G.ring(b.x,b.y,'#fff0b8',140);G.burst(b.x,b.y,'#e8c34a',30,2.2);G.sound('core',1,b.x);
    stats.record=true;
    banner=document.createElement('div');banner.className='record-banner';banner.setAttribute('role','status');
    banner.innerHTML=`<span>新纪录 · 单箭连击</span><strong>${kills}</strong><small>此前最佳 ${previous}</small>`;
    arena.append(banner);
    if(!still())banner.animate([{opacity:0,scale:'1.6',filter:'blur(6px)'},{opacity:1,scale:'.94',filter:'blur(0)',offset:.6},{opacity:1,scale:'1',filter:'blur(0)'}],{duration:420,easing:'ease-out'});
  }
  function hideRecord(){
    const el=banner;banner=null;recordArrow=null;if(!el)return;
    if(still()){el.remove();return;}
    el.animate([{opacity:1,translate:'-50% 0'},{opacity:0,translate:'-50% -14px'}],{duration:260,easing:'ease-in',fill:'forwards'}).finished.then(()=>el.remove(),()=>el.remove());
  }

  // ── Per-level stats for the clear report (read by transitions.js).
  let stats;
  const resetStats=()=>{stats={brick:0,mult:0,carried:G.levelMoney||0,bestKills:0,bestMoney:0,skills:{},record:false};};
  resetStats();
  const award=G.awardBrick;
  G.awardBrick=(b,depth)=>{
    const a=G.activeArrow,before=a?.achievement?.base||0,value=award(b,depth);
    const base=a?.achievement?Math.min(value,Math.max(0,a.achievement.base-before)):value;
    stats.brick+=base;stats.mult+=value-base;pending=value;
    if(a){a.juiceMoney=(a.juiceMoney||0)+value;stats.bestMoney=Math.max(stats.bestMoney,a.juiceMoney);}
    return value;
  };
  const skillFX=G.skillFX;
  if(skillFX)G.skillFX=(id,...rest)=>{if(G.skillRank(id))stats.skills[id]=(stats.skills[id]||0)+1;return skillFX(id,...rest);};
  G.levelReport=(level,bonus)=>{
    const total=G.levelMoney,other=Math.max(0,total-stats.brick-stats.mult-bonus-stats.carried);
    const parts=[['基础砖块',stats.brick,'#9bcc5d'],['倍率加成',stats.mult,'#e0ad2c'],['核心奖金',bonus,'#5f8a2f'],['技能与其他',other,'#8d78b9'],['此前进度',stats.carried,'#b9c2ad']]
      .filter(p=>p[1]>0).map(([label,value,color])=>({label,value,color}));
    const skills=Object.entries(stats.skills).sort((a,b)=>b[1]-a[1]).slice(0,3).map(([id,count])=>{const s=G.skillCatalog.find(s=>s.id===id);return s&&{name:s.name,icon:s.icon,count};}).filter(Boolean);
    return{level,total,parts,bestKills:stats.bestKills,bestMoney:stats.bestMoney,shots:G.shots,bricks:G.killed,skills,record:stats.record};
  };

  // ── Combo escalation: every brick of a hot arrow hits harder than the last.
  const destroyed=G.onBrickDestroyed;
  G.onBrickDestroyed=(b,depth,...rest)=>{
    const result=destroyed?.(b,depth,...rest);
    tickKills++;
    const a=G.activeArrow;if(!a)return result;
    const kills=G.arrowKills(a),tier=tierOf(kills);
    stats.bestKills=Math.max(stats.bestKills,kills);
    if(!still()&&tier){G.shake=Math.min(8+tier*3,G.shake+tier*.8);G.burst(b.x,b.y,tierColors[tier],tier*4,1+tier*.3);}
    if(tier>(a.heat||0)){
      a.heat=tier;
      const t=tallies.find(t=>t.arrow===a);if(t)t.callout={text:tierNames[tier],tier,life:.9};
      if(tier>=2){G.ring(b.x,b.y,tierColors[tier],150+tier*40);G.sound('gold',1,b.x);}
      if(tier===3){a.overdrive=true;hitstop(45);if(!still())arena.animate([{boxShadow:'inset 0 0 0 3px #f0a13a'},{boxShadow:'inset 0 0 0 0 #f0a13a00'}],{duration:500,easing:'ease-out'});}
    }
    combo.dataset.heat=tier;arena.dataset.heat=tier;
    if(!still()&&tier)combo.animate([{scale:String(1+tier*.06)},{scale:'1'}],{duration:180,easing:'ease-out'});
    if(recordArrow===a&&banner)banner.querySelector('strong').textContent=kills;
    else if(!recordArrow&&kills>baseline&&baseline>=4){const previous=baseline;recordArrow=a;baseline=Infinity;showRecord(kills,previous,b);}
    return result;
  };
  const shoot=G.shoot;
  G.shoot=(...args)=>{
    const fresh=G.phase==='ready',best=G.state.best,result=shoot(...args);
    if(result&&fresh){baseline=best;tallies.length=0;}
    return result;
  };

  // ── Tick wrapper: time scale, hit-stop, per-tick chain detection, cleanup.
  const tick=G.tick;
  G.tick=dt=>{
    if(G.paused)return tick(dt);
    const now=performance.now();
    if(now<freezeUntil)return;
    if(slowUntil&&(now>=slowUntil||!G.core))endSlow();
    watchCore();
    tickKills=0;
    const scaled=dt*scale;tick(scaled);updateTallies(scaled);
    if(tickKills>=6&&now-lastChainStop>600){lastChainStop=now;hitstop(55);}
    if(G.phase!=='flying'&&arena.dataset.heat!=='0'){arena.dataset.heat='0';combo.dataset.heat='0';}
    if(banner&&G.phase!=='flying')hideRecord();
  };
  const clear=G.clear;
  G.clear=(...args)=>{endSlow();hideRecord();return clear(...args);};
  const generate=G.generate;
  G.generate=(...args)=>{const result=generate(...args);resetStats();tallies.length=0;slowCore=null;endSlow();hideRecord();return result;};
})();
