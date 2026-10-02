(() => {
  'use strict';
  // Milestone bosses: every 100th level is a boss fight instead of a core hunt.
  // This host draws a boss from a shuffled deck (every boss once before any
  // repeats), owns the saved fight state, the three-phase flow, the collapse
  // finale, the boss bar, banners and intro. Each boss-*.js file (loaded just
  // before this one) pushes a factory onto window.SlingBosses; the host builds
  // them with a shared api. Wraps entry points only: normal levels are untouched.
  const G=window.Game,S=G.state,{Composite,Body}=Matter;
  const EVERY=100,PHASES=3,GRAVITY={x:G.engine.gravity.x,y:G.engine.gravity.y};
  const now=()=>typeof performance!=='undefined'?performance.now():Date.now();
  const shuffle=list=>{for(let i=list.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[list[i],list[j]]=[list[j],list[i]];}return list;};
  const defs={};
  const override=(level=S.level)=>S.bossOverride?.level===level&&Object.prototype.hasOwnProperty.call(defs,S.bossOverride.boss)?S.bossOverride:null;
  const isRift=(level=S.level)=>level>0&&(level%EVERY===0||!!override(level));
  const fight=()=>isRift()&&S.milestone?.v===3&&S.milestone.level===S.level&&defs[S.milestone.boss]?S.milestone:null;
  const def=()=>defs[fight()?.boss]||null;
  const has=id=>!!fight()?.abilities[fight().phase-1]?.includes(id);
  // Bosses default to three phases; a def may set its own `phases`.
  const phases=(d=def())=>d?.phases||PHASES;
  const rage=()=>fight()?.phase===phases();

  // Transient fight state; none of it needs to survive a reload.
  let spawns=[],pops=[],dying=null,entrance=null,finished=null,allowClear=false,settlingBossLevel=null;
  let introAt=-Infinity,introUntil=0,shiftUntil=0,freezeUntil=0,wasFlying=false,bumpAt=0,recent=[];
  const clearArrows=()=>{for(const a of G.arrows)Composite.remove(G.engine.world,a.body);G.arrows=[];};
  const restoreGravity=()=>{const g=G.engine.gravity;if(g.x!==GRAVITY.x||g.y!==GRAVITY.y){g.x=GRAVITY.x;g.y=GRAVITY.y;G.predictionVersion++;}};
  const removeBrick=b=>{Composite.remove(G.engine.world,b.body);G.bricks=G.bricks.filter(t=>t!==b);G.predictionVersion++;};
  const occupied=(x,y,w=50,h=30)=>G.bricks.some(b=>!b.orbit&&Math.abs(b.x-x)<w&&Math.abs(b.y-y)<h)||G.obstacles.some(o=>Math.abs(o.x-x)<w&&Math.abs(o.y-y)<h);
  // Empty grid slots a boss can fill, clear of bricks and barriers.
  function openSlots(keep=()=>true){
    const rows=10+Math.min(1,Math.floor((S.level-1)/8)),open=[];
    for(let r=0;r<rows-1;r++)for(let c=0;c<7;c++){const x=102+c*96,y=170+r*60;if(!occupied(x,y)&&keep(x,y))open.push({x,y,r,c});}
    return open;
  }
  // Arrow deflection shared by every boss. Both run inside G.guideArrows, so
  // predictPath bends around the same shapes as the live arrow.
  function bounceCircle(a,cx,cy,r,damp=.9){
    const p=a.body.position,v=a.body.velocity;
    let dx=p.x-cx,dy=p.y-cy,dist=Math.hypot(dx,dy),hit=null;
    if(dist<r)hit={x:dx/(dist||1),y:dy/(dist||1)};
    else{
      const qa=v.x*v.x+v.y*v.y,qb=2*(dx*v.x+dy*v.y),qc=dx*dx+dy*dy-r*r,disc=qb*qb-4*qa*qc;
      if(qa>1e-9&&disc>=0){const t=(-qb-Math.sqrt(disc))/(2*qa);if(t>=0&&t<=1){const hx=dx+v.x*t,hy=dy+v.y*t,len=Math.hypot(hx,hy)||1;hit={x:hx/len,y:hy/len};}}
    }
    if(!hit)return null;
    const dot=v.x*hit.x+v.y*hit.y;if(dot>=0)return null;
    Body.setPosition(a.body,{x:cx+hit.x*(r+.5),y:cy+hit.y*(r+.5)});
    Body.setVelocity(a.body,{x:(v.x-2*dot*hit.x)*damp,y:(v.y-2*dot*hit.y)*damp});
    return {x:cx+hit.x*r,y:cy+hit.y*r};
  }
  // A rounded bar (clock hands, stone palm). The next step is sampled so fast
  // arrows cannot slip through a thin bar.
  function bounceCapsule(a,x1,y1,x2,y2,r,damp=.9){
    const p=a.body.position,v=a.body.velocity,ex=x2-x1,ey=y2-y1,len2=ex*ex+ey*ey||1;
    for(let k=0;k<=4;k++){
      const qx=p.x+v.x*k/4,qy=p.y+v.y*k/4,u=Math.max(0,Math.min(1,((qx-x1)*ex+(qy-y1)*ey)/len2)),cx=x1+ex*u,cy=y1+ey*u;
      const dx=qx-cx,dy=qy-cy,d=Math.hypot(dx,dy);if(d>=r)continue;
      const n=d>1e-6?{x:dx/d,y:dy/d}:{x:-ey/Math.sqrt(len2),y:ex/Math.sqrt(len2)},dot=v.x*n.x+v.y*n.y;
      Body.setPosition(a.body,{x:cx+n.x*(r+.5),y:cy+n.y*(r+.5)});
      if(dot<0)Body.setVelocity(a.body,{x:(v.x-2*dot*n.x)*damp,y:(v.y-2*dot*n.y)*damp});
      return {x:cx+n.x*r,y:cy+n.y*r};
    }
    return null;
  }
  // A weak-point hit: per-arrow cooldown and a cap so one bouncing arrow cannot grind a boss.
  function canStrike(a){
    if(!fight()||dying||G.time<(a.eyeCooldown||0)||(a.eyeHits||0)>=6)return false;
    a.eyeCooldown=G.time+.12;a.eyeHits=(a.eyeHits||0)+1;G.onRicochet?.(a);return true;
  }
  // Weak-point hits pay gold like a kill and are tallied on their own report line.
  function pay(a,x,y,scale=1){
    const m=fight(),money=Math.round(G.reward('gold',Math.max(1,G.arrowKills(a)))*scale);
    S.coins+=money;G.shotMoney+=money;G.levelMoney+=money;m.paid+=money;
    G.float(x,y+10,'+'+G.fmt(money),def().palette().text,15);
    return money;
  }
  function strike(a,x,y,mult=1){
    const m=fight();m.hits++;
    const damage=a.damage*(a.overdrive?1.5:1)*mult;
    pay(a,x,y);hurt(damage,x,y);return damage;
  }
  // Dynamic damage reduction, shared by every boss so no build can delete a
  // phase in seconds. Two limits, the stricter wins:
  //  · pace: each phase has a target length; losing hp faster than the clock
  //    allows (after a grace period) scales damage down toward `floor`.
  //  · burst: damage past `burst` of the phase's max hp within `window`
  //    seconds only lands at `floor`.
  // A def may override any field with `resist:{...}`.
  const RESIST={pace:38,grace:12,window:3,burst:.3,floor:.25};
  const resistConfig=()=>({...RESIST,...def()?.resist});
  function resistance(){
    const m=fight();if(!m)return {factor:1,burst:false};
    const c=resistConfig(),lost=1-m.hp/m.max,allowed=Math.min(1,((m.clock||0)+c.grace)/c.pace);
    const pace=lost<=allowed?1:Math.max(c.floor,1-(lost-allowed)/(allowed||1));
    recent=recent.filter(r=>G.time-r.t<c.window);
    const burst=recent.reduce((n,r)=>n+r.v,0)>=c.burst*m.max;
    return {factor:Math.min(pace,burst?c.floor:1),pace,burst,c};
  }
  // Boss hp loss from any source. Phase shifts and death resolve after the step.
  function hurt(amount,x,y,{quiet=false}={}){
    const m=fight();if(!m||dying||!(amount>0))return 0;
    const r=resistance(),room=Math.max(0,r.c.burst*m.max-recent.reduce((n,e)=>n+e.v,0));
    // The part of the hit that fits under the burst cap takes the pace factor; the rest lands at the floor.
    const under=Math.min(amount,room),scaled=under*r.pace+(amount-under)*Math.min(r.pace,r.c.floor);
    const dealt=Math.min(m.hp,scaled);m.hp-=dealt;recent.push({t:G.time,v:dealt});
    const P=def().palette();
    if(!quiet&&x!=null)G.float(x,y-18,'-'+G.fmt(scaled),P.hot,scaled>=G.damage()*2?22:16);
    pulseBar();queueHud();return dealt;
  }
  const api={
    G,S,Composite,Body,PHASES,GRAVITY,shuffle,now,
    fight,has,rage,phases:()=>phases(),resist:()=>resistance().factor,
    dying:()=>dying,
    introAge:()=>G.time-introAt,
    // Timed abilities wait for the intro, phase shifts and the collapse.
    busy:()=>!fight()?.intro||!!dying||G.time<introUntil||G.time<shiftUntil,
    ready:()=>!api.busy()&&['ready','flying'].includes(G.phase),
    freeze:ms=>{if(!G.reduced)freezeUntil=Math.max(freezeUntil,now()+ms);},
    later:(delay,fn)=>spawns.push({at:G.time+delay,fn}),
    pop:(b,color)=>pops.push({b,born:G.time,color}),
    openSlots,occupied,removeBrick,restoreGravity,bounceCircle,bounceCapsule,canStrike,strike,pay,hurt,
    banner:(...args)=>banner(...args),flash:tone=>flash(tone),shakeArena:()=>shakeArena(),
    clearArrows
  };
  for(const factory of window.SlingBosses||[]){const d=factory(api);if(d?.id)defs[d.id]=d;}
  const ids=Object.keys(defs);
  // Keep the replacement through settlement/reloads, but never apply it to
  // an unrelated level or revive it after a reset.
  if(S.bossOverride&&!(Number.isSafeInteger(S.bossOverride.level)&&S.bossOverride.level>=S.level&&S.bossOverride.level<=S.level+1&&override(S.bossOverride.level)))S.bossOverride=null;

  // Boss deck: a shuffled pass over every boss; a fresh pass never opens with
  // the boss that just closed the last one.
  function pick(){
    let deck=Array.isArray(S.bossDeck)?S.bossDeck.filter(id=>id in defs):[];
    if(!deck.length){deck=shuffle([...ids]);if(deck.length>1&&deck[0]===S.lastBoss)deck.push(deck.shift());}
    const id=deck.shift();S.bossDeck=deck;S.lastBoss=id;return id;
  }
  function fresh(id=pick()){
    const d=defs[id],pool=shuffle(Object.keys(d.abilities));
    const m={v:3,boss:id,level:S.level,phase:1,abilities:d.roll?d.roll(pool):[pool.slice(0,1),pool.slice(1,3),pool.slice(3,5)],hp:0,max:0,intro:false,paid:0,hits:0,kills:0,board:'',clock:0,data:{}};
    S.milestone=m;m.max=m.hp=d.hp(1);d.init?.(m.data);return m;
  }
  // Discard malformed or older-format saves rather than guess at them; the
  // single-boss v2 save was always the eye.
  {
    const m=S.milestone;
    if(m?.v===2){m.v=3;m.boss='eye';m.data={ring:m.ring||0};delete m.ring;}
    const d=defs[m?.boss];
    if(m&&!(m.v===3&&d&&Number.isInteger(m.level)&&Number.isInteger(m.phase)&&m.phase>=1&&m.phase<=phases(d)&&Array.isArray(m.abilities)&&m.abilities.length===phases(d)&&(m.clock===undefined||Number.isFinite(m.clock)&&m.clock>=0)&&m.abilities.every(a=>Array.isArray(a)&&a.every(id=>id in d.abilities))&&m.hp>=0&&m.max>0&&m.data&&typeof m.data==='object'&&(!d.validate||d.validate(m.data))))S.milestone=null;
  }

  // ── Board. Each boss reshapes the layout with mods and a decorate pass;
  // hydrate then builds whatever lives outside the saved brick list.
  const phaseMods=()=>{
    const d=def(),m=fight(),mods=d.mods?.(m)||{};
    return {...mods,decorate(){mods.decorate?.();G.initial=G.bricks.length;G.threshold=Infinity;}};
  };
  G.levelMods=()=>{
    if(!isRift()||!ids.length){S.milestone=null;return {};}
    if(!fight())fresh(override()?.boss);
    return phaseMods();
  };
  const fingerprint=()=>`${fight()?.boss}|${fight()?.phase}|${G.obstacles.map(o=>o.x+','+o.y).join(';')}`;
  function hydrate(){
    const m=fight();if(!m)return;
    if(G.core){Composite.remove(G.engine.world,G.core.body);G.core=null;}
    G.threshold=Infinity;
    if(m.intro)introAt=-Infinity;
    def().hydrate?.(m);
  }
  function rebuild(){
    for(const b of G.bricks)Composite.remove(G.engine.world,b.body);
    for(const o of G.obstacles)Composite.remove(G.engine.world,o.body);
    G.bricks=[];G.obstacles=[];G.killed=0;G.predictionVersion++;
    G.layout(phaseMods());
    if(S.skillRuntime?.decay&&S.skillRuntime.level===S.level)G.bricks.forEach(b=>{b.hp*=.65;});
    hydrate();fight().board=fingerprint();
  }
  // ── Physics hooks, forwarded to the active boss.
  const guide=G.guideArrows;
  G.guideArrows=(dt,arrows)=>{
    guide?.(dt,arrows);
    const m=fight(),d=def();
    if(m&&m.intro&&!dying&&d.contact)for(const a of arrows)d.contact(a,arrows===G.arrows);
  };
  const before=G.beforePhysics||(dt=>G.guideArrows(dt,G.arrows));
  G.beforePhysics=dt=>{before(dt);if(fight()&&!dying)def().physics?.(dt);};
  const pending=G.hasPendingEffects;
  G.hasPendingEffects=()=>!!pending?.()||!!fight()&&(spawns.length>0||!!def().pending?.());
  const destroyed=G.onBrickDestroyed;
  G.onBrickDestroyed=(b,depth,...rest)=>{
    const result=destroyed?.(b,depth,...rest);
    if(fight()&&!dying&&depth<70)def().destroyed?.(b,depth);
    return result;
  };

  // ── Clock: the boss moves before physics; abilities resolve after it.
  function post(dt){
    const m=fight(),d=def();
    pops=pops.filter(p=>G.time-p.born<.5);
    if(spawns.length){const due=spawns.filter(s=>G.time>=s.at);spawns=spawns.filter(s=>G.time<s.at);due.forEach(s=>s.fn());}
    if(!fight())return;
    const flying=G.phase==='flying';
    if(wasFlying&&G.phase==='ready'&&!dying&&G.time>=shiftUntil)d.volleyEnd?.();
    wasFlying=flying;
    d.post?.(dt);
    if(!m.intro&&G.phase==='ready'&&!G.holdDraft)startIntro();
    if(m.intro&&!dying&&m.hp<=0){if(m.phase<phases())shift();else die();}
    // The pacing clock only runs while the fight is live, not during intros, shifts or the collapse.
    if(fight()&&m.intro&&!dying&&!api.busy()){m.clock=(m.clock||0)+dt;if(recent.length)queueHud();}
    if(dying)updateDying();
    if(entrance&&G.time>=entrance.end){if(G.boardEntrance===entrance)G.boardEntrance=null;entrance=null;}
    // Moving colliders: refresh the cached aim line a few times a second.
    if(G.drag&&d.moving?.()&&G.time>=bumpAt){bumpAt=G.time+.1;G.predictionVersion++;}
  }
  const tick=G.tick;
  G.tick=dt=>{
    if(!fight()||G.paused||G.phase==='draft')return tick(dt);
    if(now()<freezeUntil)return;
    const scaled=dying&&!dying.exploded&&!G.reduced?dt*.5:dt;
    def().pre?.(scaled);tick(scaled);if(fight())post(scaled);
  };

  // ── Phase flow.
  function shift(){
    const m=fight(),d=def(),P=d.palette(),f=d.focus();
    clearArrows();calm();
    m.kills+=G.killed;m.phase++;m.max=m.hp=d.hp(m.phase);m.clock=0;recent=[];
    shiftUntil=G.time+1.3;G.lockInput?.(1300);api.freeze(160);
    G.shake=16;G.coreFlash=1.4;
    G.ring(f.x,f.y,P.main,900);G.ring(f.x,f.y,P.hot,420);G.burst(f.x,f.y,P.main,70,3);
    G.sound('boom',1,f.x);G.sound(d.roar);
    G.bricks.forEach(b=>G.burst(b.x,b.y,G.colors[b.type],5,1.3));
    rebuild();d.shifted?.(m);
    if(!G.reduced){const o=d.focus();entrance={start:G.time+.25,end:G.time+1.3,origin:{x:o.x,y:o.y}};G.boardEntrance=entrance;}
    flash(rage()?'rage':'shift');
    const names=m.abilities[m.phase-1].map(id=>d.abilities[id].name).join(' · ');
    banner(`PHASE ${m.phase} / ${phases()}`,d.phaseNames[m.phase-1],names,rage()?'rage':'shift');
    G.save();G.ui();
  }
  function calm(){spawns=[];pops=[];for(const d of Object.values(defs))d.calm?.();restoreGravity();}
  function die(){
    const m=fight(),d=def(),f=d.focus();m.hp=0;
    clearArrows();calm();
    dying={at:G.time,exploded:false,queue:[],done:0,x:f.x,y:f.y};
    G.lockInput?.(6000);api.freeze(260);G.shake=18;G.coreFlash=1;G.sound(d.roar);G.sound('eyehit',1,f.x);
    shakeArena();G.save();G.ui();
  }
  function updateDying(){
    const t=G.time-dying.at;
    if(!dying.exploded){G.shake=Math.max(G.shake,4+t*9);def().charging?.(t);if(t>=1.3)explode();return;}
    while(dying.queue.length&&G.time>=dying.queue[0].at){const {b}=dying.queue.shift();if(G.bricks.includes(b))G.hit(b,b.hp*4+1e9,99);}
    if(!dying.queue.length&&G.time>=dying.done)finish();
  }
  function explode(){
    const d=def(),P=d.palette(),{x,y}=dying;dying.exploded=true;
    api.freeze(220);G.shake=22;G.coreFlash=2;
    G.ring(x,y,P.light,1100);G.ring(x,y,P.main,700);G.ring(x,y,P.hot,380);
    G.burst(x,y,P.light,90,4);G.burst(x,y,P.main,60,3);G.sound('shatter',1,x);G.sound('win');
    d.exploded?.();
    flash('seal');banner(...d.seal,'seal');
    const dist=b=>Math.hypot(b.x-x,b.y-y),order=[...G.bricks].sort((a,b)=>dist(a)-dist(b));
    dying.queue=order.map(b=>({b,at:G.time+.35+dist(b)/1100}));
    dying.done=(dying.queue[dying.queue.length-1]?.at||G.time)+.6;
  }
  function finish(){
    const m=fight(),d=def();dying=null;
    finished={title:d.name,label:d.hitLabel,phases:m.abilities.map((list,i)=>({name:d.phaseNames[i],abilities:list.map(id=>d.abilities[id].name)})),kills:m.kills+G.killed,paid:m.paid,hits:m.hits};
    calm();allowClear=true;
    try{G.clear();}finally{allowClear=false;}
  }
  function startIntro(){
    const m=fight(),d=def();m.intro=true;introAt=G.time;introUntil=G.time+(G.reduced?.4:2.6);
    d.intro?.();
    G.lockInput?.(G.reduced?400:2600);G.save();
    G.shake=G.reduced?0:6;cinematic();
  }
  function reset(){
    spawns=[];pops=[];dying=null;entrance=null;wasFlying=false;finished=null;recent=[];called=new Map();
    introAt=-Infinity;introUntil=shiftUntil=freezeUntil=bumpAt=0;
    for(const d of Object.values(defs))d.reset?.();
    restoreGravity();
  }
  // ── Entry-point wrappers.
  const shoot=G.shoot;
  G.shoot=(...args)=>{
    if(!fight())return shoot(...args);
    if(dying||G.time<introUntil||G.time<shiftUntil||def().blockShot?.())return false;
    const fired=shoot(...args);if(fired)def().shot?.(G.arrows[G.arrows.length-1]);return fired;
  };
  const spawnCore=G.spawnCore;
  G.spawnCore=(...args)=>fight()?undefined:spawnCore(...args);
  const clear=G.clear;
  G.clear=(...args)=>{
    if(!fight()||G.phase==='clearing')return clear(...args);
    if(!allowClear)return;
    S.milestone=null;return clear(...args);
  };
  const baseBonus=G.bonus;
  G.bonus=(level=S.level)=>baseBonus(level)*(isRift(level)||level===settlingBossLevel?3:1);
  // The clear report counts every phase and shows weak-point income on its own line.
  const report=G.levelReport;
  if(report)G.levelReport=(...args)=>{
    const r=report(...args),f=finished;
    if(!r||!f)return r;
    r.bricks=f.kills;r.rift={title:f.title,items:f.phases.map((p,i)=>`${i+1} ${p.name} · ${p.abilities.join('/')}`)};
    const other=r.parts.find(p=>p.label==='技能与其他');
    if(other)other.value=Math.max(0,other.value-f.paid);
    r.parts=r.parts.filter(p=>p.value>0);
    if(f.paid)r.parts.push({label:`${f.label} ×${f.hits}`,value:f.paid,color:'#8d78b9'});
    return r;
  };
  G.levelIntro=()=>fight()?{eyebrow:def().kicker,note:def().note||def().name}:null;
  const generate=G.generate;
  G.generate=(...args)=>{
    reset();
    if(S.bossOverride?.level<S.level)S.bossOverride=null;
    G.directBossEntry=!!override();
    let result;
    try{result=generate(...args);}finally{G.directBossEntry=false;}
    if(fight()){hydrate();fight().board=fingerprint();}
    G.save();syncHud();
    return result;
  };
  const save=G.save;
  G.save=(...args)=>{if(fight())def().persist?.(fight());return save(...args);};

  // ── DOM: boss bar in place of the core meter, banners, flashes, intro.
  const dom=typeof document.createElement==='function';
  const $=id=>document.getElementById?.(id);
  const meter=$('core-progress'),arena=$('arena');
  let bar=null,shown='';
  if(dom&&meter){
    bar=document.createElement('div');bar.className='boss-bar';bar.hidden=true;
    bar.setAttribute('role','progressbar');bar.setAttribute('aria-valuemin','0');bar.setAttribute('aria-valuemax','100');
    bar.innerHTML='<span class="boss-name"><i class="boss-gem" aria-hidden="true"></i><span class="boss-title"></span></span><span class="boss-phase"></span><div class="boss-track" aria-hidden="true">'+'</div><b class="boss-state"></b><span class="boss-resist" hidden></span>';
    meter.after(bar);
  }
  function syncHud(){
    const m=fight(),d=def(),st=m?(dying?{text:'崩解中',state:'dying'}:d.status()):null;
    const rs=m&&!dying?resistance():{factor:1,burst:false},cut=Math.round((1-rs.factor)*10)*10;
    const key=m?`${m.boss}:${m.phase}:${Math.ceil(m.hp/m.max*200)}:${st.text}:${st.state}:${cut}:${rs.burst}`:'';
    if(key===shown||!bar)return;
    shown=key;bar.hidden=!m;meter.hidden=!!m;
    arena?.classList.toggle('is-rift',!!m);arena?.classList.toggle('is-rage',!!m&&rage());
    if(arena){if(m)arena.dataset.boss=m.boss;else delete arena.dataset.boss;}
    if(!m)return;
    bar.dataset.boss=m.boss;bar.querySelector('.boss-title').textContent=d.name;bar.setAttribute('aria-label',`${d.name}生命`);
    // One segment per phase, depleting right to left: the rightmost bar is phase one.
    const n=phases(),track=bar.querySelector('.boss-track');
    if(track.children.length!==n){track.innerHTML='<span class="boss-seg"><i class="boss-ghost"></i><i class="boss-fill"></i></span>'.repeat(n);track.style.setProperty('--phases',n);}
    [...bar.querySelectorAll('.boss-seg')].forEach((seg,i)=>{
      const phase=n-i,fill=phase<m.phase?0:phase>m.phase?1:m.hp/m.max,width=(fill*100).toFixed(1)+'%';
      seg.querySelector('.boss-fill').style.width=width;seg.querySelector('.boss-ghost').style.width=width;
      seg.classList.toggle('is-current',phase===m.phase);
    });
    const total=Math.round(((n-m.phase)+m.hp/m.max)/n*100);
    bar.querySelector('.boss-phase').textContent=`${m.phase}/${n} ${d.phaseNames[m.phase-1]}`;
    // Damage reduction readout: shown once it bites, "过载" while the burst cap holds.
    const res=bar.querySelector('.boss-resist');
    if(res){res.hidden=cut<10;res.textContent=`减伤 ${cut}%`;bar.dataset.resist=rs.burst?'burst':cut>=10?'pace':'';}
    bar.querySelector('.boss-state').textContent=st.text;bar.dataset.state=st.state;
    bar.setAttribute('aria-valuenow',String(total));
    bar.setAttribute('aria-valuetext',`第 ${m.phase} 相${d.phaseNames[m.phase-1]}，总生命 ${total}%，${st.text}${cut>=10?`，减伤 ${cut}%`:''}`);
  }
  function pulseBar(){if(!bar||G.reduced)return;
    const paint=()=>{bar.classList.remove('is-hit');void bar.offsetWidth;bar.classList.add('is-hit');};
    if(G.deferVisual)G.deferVisual('boss-hit',paint);else paint();
  }
  function queueHud(){if(G.deferVisual)G.deferVisual('boss-hud',syncHud);else syncHud();}
  const ui=G.ui;
  G.ui=(...args)=>{const result=ui(...args);syncHud();return result;};
  // Full-screen banners are kept for the big beats: phase shifts, rage and the
  // finale. Ability announcements ('minor', 'weak') become a compact callout in
  // the empty strip above the sling; the explanation line only shows the first
  // time, and a repeat within a few seconds is skipped.
  const MAJOR=new Set(['shift','rage','seal']);
  let called=new Map();
  function banner(kicker,title,sub,tone){
    if(!dom||!arena)return;
    if(!MAJOR.has(tone))return callout(kicker,title,sub,tone);
    const el=document.createElement('div');el.className='rift-banner';el.dataset.tone=tone;el.setAttribute('role','status');
    el.innerHTML=`<i class="rift-banner-band" aria-hidden="true"></i><span>${kicker}</span><strong>${title}</strong>${sub?`<em>${sub}</em>`:''}`;
    arena.querySelectorAll('.rift-banner,.rift-callout').forEach(old=>old.remove());
    arena.append(el);
    const life=G.reduced?1600:2100;
    if(!G.reduced){
      el.animate([{opacity:0,transform:'translate(0,10px)'},{opacity:1,transform:'translate(0,0)',offset:.12},{opacity:1,offset:.85},{opacity:0,transform:'translate(0,-6px)'}],{duration:life,easing:'ease-out',fill:'forwards'});
      el.firstElementChild.animate([{transform:'scale(0,1)'},{transform:'scale(1,1)',offset:.18},{transform:'scale(1,1)',offset:.85},{transform:'scale(0,1)'}],{duration:life,easing:'cubic-bezier(.22,1,.36,1)',fill:'forwards'});
    }
    setTimeout(()=>el.remove(),life);
  }
  function callout(kicker,title,sub,tone){
    const last=called.get(kicker);if(last!==undefined&&G.time-last<6)return;
    const first=last===undefined;called.set(kicker,G.time);
    if(arena.querySelector('.rift-banner'))return;
    const el=document.createElement('div');el.className='rift-callout';el.dataset.tone=tone;el.setAttribute('role','status');
    el.innerHTML=`<strong>${title}</strong>${first&&sub?`<em>${sub}</em>`:''}`;
    el.style.top=`${((G.origin.y-78)/G.H*100).toFixed(1)}%`;
    arena.querySelectorAll('.rift-callout').forEach(old=>old.remove());
    arena.append(el);
    const life=first?2400:1300;
    if(!G.reduced)el.animate([{opacity:0,transform:'translate(-50%,-40%)'},{opacity:1,transform:'translate(-50%,-50%)',offset:.1},{opacity:1,offset:.85},{opacity:0,transform:'translate(-50%,-50%)'}],{duration:life,easing:'ease-out',fill:'forwards'});
    setTimeout(()=>el.remove(),life);
  }
  function flash(tone){
    if(!dom||!arena||G.reduced)return;
    const el=document.createElement('i');el.className='rift-flash';el.dataset.tone=tone;el.setAttribute('aria-hidden','true');arena.append(el);
    el.animate([{opacity:.9},{opacity:0}],{duration:tone==='seal'?1100:600,easing:'ease-out',fill:'forwards'}).finished.then(()=>el.remove(),()=>el.remove());
  }
  function shakeArena(){if(dom&&arena&&!G.reduced)arena.animate([0,1,2,3,4,5,6].map(i=>({transform:i===6?'translate(0,0)':`translate(${(Math.random()-.5)*14}px,${(Math.random()-.5)*10}px)`})),{duration:520,easing:'linear'});}
  function cinematic(){
    if(!dom||!arena)return;
    const d=def(),el=document.createElement('div');el.className='rift-intro';el.setAttribute('role','status');
    el.innerHTML=`<i class="rift-intro-bar top" aria-hidden="true"></i><i class="rift-intro-bar bottom" aria-hidden="true"></i><div class="rift-intro-title"><span>WARNING · LEVEL ${S.level}</span><strong>${d.name}</strong><em>${d.title}</em></div>`;
    arena.append(el);
    if(G.reduced){setTimeout(()=>el.remove(),1600);return;}
    const [top,bottom,title]=el.children,dur=2600;
    for(const b of [top,bottom])b.animate([{transform:'scale(1,0)'},{transform:'scale(1,1)',offset:.15},{transform:'scale(1,1)',offset:.85},{transform:'scale(1,0)'}],{duration:dur,easing:'cubic-bezier(.65,0,.35,1)',fill:'forwards'});
    title.animate([{opacity:0,transform:'translate(0,12px)'},{opacity:0,offset:.25},{opacity:1,transform:'translate(0,0)',offset:.4},{opacity:1,clipPath:'inset(0 0 0 0)',offset:.5},{clipPath:'inset(40% 0 35% 0)',transform:'translate(6px,0)',offset:.52},{clipPath:'inset(0 0 0 0)',transform:'translate(0,0)',offset:.54},{opacity:1,offset:.84},{opacity:0,transform:'translate(0,-14px)'}],{duration:dur,easing:'ease-out',fill:'forwards'});
    setTimeout(()=>el.remove(),dur+50);
  }

  // ── Canvas. Backdrop sits under the bricks; field above them; front over arrows.
  const back=G.drawBossBackdrop;
  G.drawBossBackdrop=ctx=>{back?.(ctx);if(fight()){ctx.save();try{def().drawBack?.(ctx);}finally{ctx.restore();}}};
  const draw=G.drawSkillEffects;
  G.drawSkillEffects=(ctx,layer,...rest)=>{
    if(fight()&&layer==='field'){ctx.save();def().drawField?.(ctx);drawPops(ctx);ctx.restore();}
    const result=draw?.(ctx,layer,...rest);
    if(fight()&&layer==='front'){ctx.save();def().drawFront?.(ctx);if(dying?.exploded)drawWhiteout(ctx);ctx.restore();}
    return result;
  };
  function drawPops(ctx){
    for(const p of pops){const k=(G.time-p.born)/.5;ctx.globalAlpha=1-k;ctx.strokeStyle=p.color||def().palette().main;ctx.lineWidth=2;ctx.strokeRect(p.b.x-p.b.w/2-k*10,p.b.y-p.b.h/2-k*8,p.b.w+k*20,p.b.h+k*16);}
    ctx.globalAlpha=1;
  }
  function drawWhiteout(ctx){
    const k=Math.max(0,1-(G.time-dying.at-1.3)/.5);if(k<=0)return;
    ctx.globalAlpha=k*.85;ctx.fillStyle=def().palette().light;ctx.fillRect(0,0,780,G.H);ctx.globalAlpha=1;
  }

  G.isRiftLevel=isRift;G.boss=fight;G.bossDefs=defs;G.bossApi=api;
  // Shared URL/admin entry: settle this level normally, then replace only the
  // next board with the selected boss. The saved override survives a reload
  // during the clear animation and never consumes the normal boss deck.
  G.enterBoss=id=>{
    if(!Object.prototype.hasOwnProperty.call(defs,id)||G.paused||!['ready','draft'].includes(G.phase))return false;
    settlingBossLevel=fight()?.level??null;
    S.bossOverride={level:S.level+1,boss:id};
    S.milestone=null;
    G.drag=null;G.pointer=null;
    finished=null;calm();allowClear=true;
    try{G.clear();}finally{allowClear=false;settlingBossLevel=null;}
    return true;
  };
  // Read-only snapshot of the transient fight state (tests, debugging).
  G.riftState=()=>({spawns:spawns.length,dying:!!dying,...(def()?.debug?.()||{})});

  const requestedBoss=new URLSearchParams(location.search).get('boss');
  // Refreshing an already-requested fight resumes it instead of repeatedly
  // awarding a clear and moving forward another level.
  const resume=override()?.boss===requestedBoss;
  const entered=requestedBoss!==null&&(resume||G.enterBoss(requestedBoss));
  if(entered&&window.history?.replaceState){
    try{
      const url=new URL(location.href);
      url.searchParams.delete('boss');
      const historyState={...window.history.state};
      if(!url.searchParams.has('admin'))historyState.slingbreakSaveSlot='boss';
      window.history.replaceState(historyState,'',url.href);
    }catch{} // Restricted hosts must not interrupt the saved boss request.
  }
  if(requestedBoss!==null&&!entered)G.toast?.(`未知 Boss ID，可用：${ids.join('、')}`);
  // Boot: the first board was built before this file loaded, without the boss.
  if(isRift()&&ids.length&&G.phase!=='clearing'){
    const m=fight();
    if(!m)fresh(override()?.boss);
    if(!m||m.board!==fingerprint())rebuild();else hydrate();
    if(override()){
      G.phase='ready';G.directBossEntry=true;
      try{G.prepareDraft?.();}finally{G.directBossEntry=false;}
      G.threshold=Infinity;
    }
    fight().board=fingerprint();G.save();
    if(fight().intro)G.toast?.(`${def().name} · ${fight().phase}/${phases()}`);
  }
  G.ui();
})();
