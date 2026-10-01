(() => {
  'use strict';
  // 深渊之眼: a giant eye tears open above the board. It is sealed in a ward
  // (结界, 0–100): arrows glance off and it takes no damage. The ward mends
  // itself, much faster while its chain anchors hold. Drain it to zero and
  // the eye is dazed (失神): the ward shatters, the eye sags and takes ×3 for
  // a few seconds, then the ward reforms and chains lash onto new bricks.
  // The ward drains from chain anchors (phase 1+), from watcher eyes on the
  // board shot while they are open (phase 2+), and all at once from a correct
  // answer to a move. A missed answer regrows bricks and restores the ward.
  // One move at a time; the last phase always adds 终焉. Void and hydra
  // bricks are the board's own texture.
  (window.SlingBosses||=[]).push(api=>{
    const {G,Body,has,rage}=api,fight=api.fight;
    const SHIELD=54,EYE={x:390,y:92,r:40},HOME=390;
    G.riftEye=EYE;
    const fallback={crack:'#140a24',crackEdge:'#9b6bff',sclera:'#f6f0ff',scleraShade:'#c9b6f2',iris:'#8a5cf0',irisDeep:'#34186e',irisRage:'#e0453a',pupil:'#0b0612',shield:'#8f68f5',chain:'#7d62b8',beam:'#b48cff',heal:'#2fb57e',well:'#0d0716',wellRim:'#8a5cf0',weak:'#e2493a',text:'#5b3aa6'};
    const R=()=>window.SlingTheme?.canvas.rift||fallback;
    const abilities={
      orbit:{name:'晶环',desc:'晶石环绕巨眼，击碎发光的晶心则失神；否则晶石落成砖块'},
      summon:{name:'召唤',desc:'棋盘上展开召唤阵，阵成前击中则失神；否则涌出新砖'},
      tear:{name:'泪滴',desc:'巨眼落下一滴晶泪，落地前击碎则失神；否则碎成砖块'},
      gaze:{name:'凝视',desc:'光束扫过棋盘，逆着光束射入巨眼则失神；否则光束处长出砖块'},
      mirage:{name:'幻瞳',desc:'巨眼分成三只，射中追着准星的真眼则失神；否则幻眼放出光束'},
      doom:{name:'终焉',desc:'巨眼睁开蓄力，蓄满前三击瞳孔则长时间失神；否则锁链重生、结界全满'}
    };
    // Phase one opens with a move whose answer is a visible target.
    const OPENERS=['orbit','summon','tear'];
    const DAZE=4,DAZE_MULT=3,MEND=1.2,REGEN=1.5,PER_ANCHOR=1.5,DRAIN={anchor:8,anchorBreak:22,watch:25};
    // Watcher eyes: fixed low cells from phase two, blinking on their own cycle.
    // Each takes the first of its cells clear of barriers, so decorate and a reload agree.
    const WATCH=[[[198,650],[102,650],[198,710],[294,650]],[[390,710],[390,650],[294,710],[486,710]],[[582,650],[678,650],[582,710],[486,650]]],WATCH_R=22,BLINK=2.6;
    let wells=[],beams=[],snaps=[],lashes=[],shards=[],watchers=[],look={x:0,y:0};
    let move=null,nextAt=0,last=null,dazeUntil=0,dazeLen=DAZE,mend=null,hurt=0,hinted=false,pingAt=0,drainFlash=0,whirl=0,blink=0,nextBlink=3;
    const ward=()=>fight()?.data.ward??100;
    const dazed=()=>G.time<dazeUntil;
    // The ward only drains while it stands and the fight is live.
    const warding=()=>!dazed()&&!mend&&!api.dying()&&!!fight()?.intro;
    const is=id=>move?.id===id;
    const anchors=()=>G.bricks.filter(b=>b.type==='anchor');
    const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
    const blocked=p=>G.obstacles.some(o=>Math.abs(o.x-p.x)<76&&Math.abs(o.y-p.y)<46);
    const nearWatch=(x,y)=>watchers.some(w=>Math.abs(w.x-x)<70&&Math.abs(w.y-y)<50);
    // Empty slots a move may fill: clear of bricks, barriers and watcher cells.
    const free=()=>api.openSlots((x,y)=>!nearWatch(x,y));
    const awake=w=>!w.blind&&warding()&&((G.time-w.t0)%BLINK+BLINK)%BLINK<BLINK*.45;
    const anchorCount=()=>fight()?.phase===1?2:3;
    const anchorHp=()=>{const base=G.baseHp(),phase=fight().phase;return Math.min(Math.round(base*3.2*(1+.25*(phase-1))),Math.ceil(G.damage()*(3+phase)));};

    // ── Board: chain anchors, watcher cells, void and hydra bricks.
    function lash(n,animate=false){
      const pool=api.shuffle(G.bricks.filter(b=>b.type==='normal'&&Math.abs(b.x-390)>=150)),picked=anchors(),hp=anchorHp();
      for(const b of pool){if(picked.length>=n)break;if(picked.every(a=>Math.hypot(a.x-b.x,a.y-b.y)>=260)){b.type='anchor';b.hp=b.max=hp;picked.push(b);if(animate)lashes.push({x:b.x,y:b.y,born:G.time});}}
      if(animate)G.predictionVersion++;
    }
    const watchCells=()=>WATCH.map(list=>list.map(([x,y])=>({x,y})).find(p=>!blocked(p))).filter(Boolean);
    const buildWatchers=()=>{watchers=fight()?.phase>=2?watchCells().map((p,i)=>({...p,i,blind:false,flash:0,t0:G.time-i*BLINK/3})):[];};
    function decorate(){
      const m=fight(),base=G.baseHp();
      m.data.ward=100;
      if(m.phase>=2)for(const p of watchCells())for(const b of G.bricks.filter(b=>Math.abs(b.x-p.x)<70&&Math.abs(b.y-p.y)<40))api.removeBrick(b);
      lash(anchorCount());
      const rest=api.shuffle(G.bricks.filter(b=>b.type==='normal')),voids=1+m.phase*2,hydras=2+m.phase*2;
      rest.slice(0,voids).forEach(b=>{b.type='void';b.hp=b.max=base;});
      rest.slice(voids,voids+hydras).forEach(b=>{b.type='hydra';b.hp=b.max=Math.round(base*1.5);});
      buildWatchers();
    }
    // A beam from `from` (the eye by default), then a brick materialises at the end of it.
    function spawnAt(s,delay,from=EYE){
      const base=G.baseHp(),o={x:from.x,y:from.y};
      beams.push({ox:o.x,oy:o.y,x:s.x,y:s.y,born:G.time+delay,end:G.time+delay+.55});
      api.later(delay+.42,()=>{
        const P=R();
        if(G.bricks.length>=230||!fight()||api.dying()||api.occupied(s.x,s.y))return;
        const type=['normal','normal','normal','void','hydra'][Math.floor(Math.random()*5)],hp=type==='hydra'?Math.round(base*1.5):base;
        const b=G.makeBrick({x:s.x,y:s.y,w:84,h:44,hp,max:hp,type,frozen:false});api.pop(b,P.beam);
        G.initial++;G.predictionVersion++;G.ring(s.x,s.y,P.beam,60);G.burst(s.x,s.y,P.beam,8,.9);
      });
    }
    // ── Daze: the ward shatters, the eye sags and takes ×3.
    function daze(x,y,label,a,len=DAZE){
      const P=R(),m=fight();endMove();m.data.ward=0;dazeLen=len;dazeUntil=G.time+len;mend=null;nextAt=dazeUntil+MEND+(rage()?1.4:2.2);
      if(a)api.pay(a,x,y-10,2);
      G.float(x,y-34,label,P.text,20);G.ring(x,y,P.weak,140);G.ring(EYE.x,EYE.y,P.shield,280);G.ring(EYE.x,EYE.y,P.weak,120);
      G.burst(EYE.x,EYE.y,P.shield,50,2.6);G.burst(x,y,P.beam,18,1.6);shatter(36,420);
      G.shake=Math.max(G.shake,11);G.coreFlash=.7;api.freeze(140);G.sound('shatter',1,EYE.x);G.sound('core');
      api.banner('DAZED','失神',`巨眼暴露 · 伤害 ×${DAZE_MULT}`,'weak');G.predictionVersion++;
    }
    function drain(n,x,y,label){
      const m=fight();if(!m||!warding())return;
      m.data.ward=Math.max(0,ward()-n);drainFlash=1;G.ring(EYE.x,EYE.y,R().shield,SHIELD+30);
      if(m.data.ward<=0)daze(x,y,label||'失神',G.activeArrow);
    }
    // A missed answer mends the ward.
    function restore(n){const m=fight();if(m){m.data.ward=Math.min(100,ward()+n);drainFlash=-1;}}
    // A move ends early when the eye is dazed: the crystal ring bursts, the eyes merge.
    function endMove(){
      if(is('orbit')){const P=R(),left=G.bricks.filter(b=>b.orbit);for(const b of left)G.burst(b.x,b.y,P.shield,8,1.2);api.later(0,()=>left.forEach(b=>{if(G.bricks.includes(b))api.removeBrick(b);}));}
      move=null;
    }
    // Chain anchors drain the ward on every arrow hit.
    const baseHit=G.hit;
    G.hit=(b,damage,depth=0)=>{
      if(fight()?.boss==='eye'&&b.type==='anchor'&&G.bricks.includes(b)&&depth===0&&G.activeArrow&&warding()){G.ring(b.x,b.y,R().chain,60);drain(DRAIN.anchor,b.x,b.y,'断链');}
      return baseHit(b,damage,depth);
    };
    function destroyed(b,depth){
      const P=R();
      if(b.type==='anchor'){
        snaps.push({x:b.x,y:b.y,born:G.time});api.hurt(G.damage()*.5,b.x,b.y);
        G.ring(b.x,b.y,P.chain,120);G.burst(b.x,b.y,P.chain,24,1.8);G.shake=Math.max(G.shake,7);G.sound('anchor',1,b.x);api.freeze(70);
        const left=anchors().filter(t=>t!==b).length;G.float(b.x,b.y-40,left?`锁链 ${left}`:'锁链尽断',P.text,17);
        drain(DRAIN.anchorBreak,b.x,b.y,'断链');
        return;
      }
      if(b.heart){G.ring(b.x,b.y,P.weak,120);if(is('orbit'))daze(b.x,b.y,'碎心',G.activeArrow);return;}
      if(depth<3&&b.type!=='shard')api.hurt(G.damage()*.03,b.x,b.y,{quiet:true});
      if(b.type==='void')openWell(b.x,b.y,G.activeArrow);
      if(b.type==='hydra'&&b.w>=60)splitLater(b);
      if(b.type==='shard')G.ring(b.x,b.y,P.shield,40);
    }
    // Void wells pull live arrows and grind nearby bricks while they last.
    function openWell(x,y,source){wells.push({x,y,born:G.time,end:G.time+2.6,next:G.time+.3,source});if(wells.length>4)wells.shift();G.sound('void',1,x);G.ring(x,y,R().wellRim,150);}
    function physics(dt){
      if(!wells.length)return;
      for(const a of G.arrows){
        const p=a.body.position,v=a.body.velocity;let vx=v.x,vy=v.y;
        for(const w of wells){
          const dx=w.x-p.x,dy=w.y-p.y,d=Math.hypot(dx,dy);if(d>230||d<4)continue;
          const f=(1-d/230)*1.1*dt*60;vx+=dx/d*f+(-dy/d)*f*.35;vy+=dy/d*f+(dx/d)*f*.35;
        }
        const speed=Math.hypot(vx,vy),cap=Math.max(18,G.speed());
        if(vx!==v.x||vy!==v.y)Body.setVelocity(a.body,speed>cap?{x:vx/speed*cap,y:vy/speed*cap}:{x:vx,y:vy});
      }
      for(const w of [...wells])if(G.time>=w.next&&G.time<w.end){
        w.next=G.time+.3;
        G.withArrow(w.source,()=>G.bricks.filter(b=>Math.hypot(b.x-w.x,b.y-w.y)<125).forEach(b=>G.hit(b,G.damage()*.7,1)));
      }
    }
    // Hydra children appear a beat later, so the breaking arrow clears the slot first.
    function splitLater(b){api.later(.24,()=>{
      if(G.bricks.length>=230)return;
      const hp=Math.max(1,Math.round(b.max*.5)),P=R();
      for(const side of [-1,1]){const c=G.makeBrick({x:b.x+side*22,y:b.y,w:40,h:44,hp,max:hp,type:'normal',frozen:false});api.pop(c,P.beam);}
      G.initial+=2;G.predictionVersion++;G.burst(b.x,b.y,P.heal,14,1.2);G.sound('hydra',1,b.x);
    });}
    // ── Colliders: the ward (the bare eye when dazed or during 终焉), mirage
    // eyes, watchers, and the current move's target.
    const bare=()=>dazed()||is('doom')&&G.time>=move.live;
    // During 凝视 the ward opens a notch where the beam leaves the eye.
    const inNotch=p=>is('gaze')&&G.time>=move.live&&Math.abs(wrap(Math.atan2(p.y-EYE.y,p.x-EYE.x)-beamAngle()))<.3;
    function contact(a,live){
      if(is('mirage')&&G.time>=move.live){
        for(const e of move.eyes){const p=api.bounceCircle(a,e.x,e.y,EYE.r*.8+3);if(p){if(live&&G.time>=(a.wardAt||0)){a.wardAt=G.time+.15;a.trail=[];hitMirage(a,e,p);}return;}}
      }else{
        const notch=inNotch(a.body.position),hit=api.bounceCircle(a,EYE.x,EYE.y,(bare()||notch?EYE.r:SHIELD)+3);
        if(hit){if(live){a.trail=[];strikeEye(a,hit.x,hit.y,notch);}return;}
      }
      for(const w of watchers){const p=api.bounceCircle(a,w.x,w.y,WATCH_R+3);if(p){if(live&&G.time>=(a.watchAt||0)){a.watchAt=G.time+.15;a.trail=[];hitWatcher(a,w,p);}return;}}
      if(is('summon')){const p=api.bounceCircle(a,move.x,move.y,26);if(p&&live){a.trail=[];G.sound('shatter',1,move.x);daze(move.x,move.y,'破阵',a);}return;}
      if(is('tear')&&G.time>=move.live){const t=tearPos(),p=api.bounceCircle(a,t.x,t.y,18);if(p&&live){a.trail=[];G.burst(t.x,t.y,R().shield,20,1.8);daze(t.x,t.y,'碎泪',a);}}
    }
    // Sealed: arrows glance off. Answers still register on the eye (凝视, 终焉).
    function strikeEye(a,x,y,notch){
      const P=R();
      if(dazed()){
        if(!api.canStrike(a))return;
        api.strike(a,x,y,DAZE_MULT);hurt=1;
        G.burst(x,y,P.weak,20,2);G.ring(x,y,P.iris,110);G.shake=Math.min(14,G.shake+5);G.sound('eyehit',1,x);api.freeze(60);
        return;
      }
      if(G.time<(a.wardAt||0))return;a.wardAt=G.time+.15;
      if(notch){daze(x,y,'迎瞳',a);return;}
      if(is('doom')&&G.time>=move.live){move.hits++;move.flash=1;G.ring(EYE.x,EYE.y,P.weak,60+move.hits*30);G.burst(x,y,P.weak,12,1.3);G.sound('eyehit',1,x);if(move.hits>=move.need)daze(x,y,'破灭',a,DAZE+1.5);return;}
      G.burst(x,y,P.shield,5,.6);G.sound('ricochet',1,x);pingAt=G.time;
      if(!hinted){hinted=true;G.toast?.('巨眼被结界封住：削弱结界让它失神');}
    }
    // A watcher only takes the hit while its eye is open.
    function hitWatcher(a,w,p){
      const P=R();w.flash=1;
      if(!awake(w)){G.burst(p.x,p.y,P.chain,4,.6);G.sound('ricochet',1,p.x);return;}
      w.blind=true;G.burst(w.x,w.y,P.weak,16,1.6);G.ring(w.x,w.y,P.weak,90);G.sound('eyehit',1,w.x);G.float(w.x,w.y-WATCH_R-16,'刺瞎',P.text,16);api.freeze(60);
      drain(watchers.every(t=>t.blind)?100:DRAIN.watch,w.x,w.y,'刺瞎');
    }
    function hitMirage(a,e,p){
      const P=R();
      if(e.real){daze(p.x,p.y,'识破',a);return;}
      move.eyes=move.eyes.filter(t=>t!==e);
      G.burst(e.x,e.y,P.beam,24,1.8);G.ring(e.x,e.y,P.beam,120);G.sound('shatter',1,e.x);G.float(e.x,e.y+50,'幻影',P.text,16);restore(10);
    }
    // ── Moves. begin() sets up the telegraph; each fail*() is the cost of a missed answer.
    const CALL={
      orbit:['CRYSTAL RING','晶环','击碎发光的晶心'],summon:['SUMMON','召唤','阵成前击中法阵'],tear:['TEAR','泪滴','落地前击碎晶泪'],
      gaze:['GAZE','凝视','逆着光束射入巨眼'],mirage:['MIRAGE','幻瞳','射中追着准星的真眼'],doom:['DOOM','终焉','蓄满前三击瞳孔']
    };
    const MIRAGE=[170,390,610];
    const orbitAt=slot=>{const a=(G.time-move.start)*(rage()?1.2:.8)+slot/move.count*Math.PI*2;return {x:EYE.x+Math.cos(a)*132,y:EYE.y+14+Math.sin(a)*38};};
    // The tear leaves the eye, drifts toward its lane and falls, swaying.
    const tearPos=()=>{const u=Math.max(0,G.time-move.live),k=Math.min(1,u/.8),y=EYE.y+SHIELD+u*(rage()?300:260)+u*u*20;return {x:EYE.x+(move.x-EYE.x)*k+Math.sin(u*2.4)*26*k,y};};
    const beamAngle=()=>{const u=Math.min(1,Math.max(0,(G.time-move.live)/(move.end-move.live)));return Math.PI/2+move.dir*(1.05-2.1*u);};
    // The sigil opens on a low empty cell the sling can reach.
    function sigilSpot(){const open=api.shuffle(free());return open.find(s=>s.y>=500&&s.y<=760)||open[0]||null;}
    function begin(id){
      if(move||dazed()||mend)return false;
      const t=G.time,r=rage();
      if(id==='orbit'){
        const count=r?8:6,heart=Math.floor(Math.random()*count),base=Math.max(2,Math.round(G.baseHp()*1.2)),core=Math.max(2,Math.ceil(G.damage()*1.5));
        move={id,start:t,end:t+(r?7:8),count};
        for(let slot=0;slot<count;slot++){const p=orbitAt(slot),hp=slot===heart?core:base,b=G.makeBrick({x:p.x,y:p.y,w:40,h:26,hp,max:hp,type:'shard',frozen:false});b.orbit=true;b.slot=slot;b.heart=slot===heart;api.pop(b,R().shield);}
      }else if(id==='summon'){
        const s=sigilSpot();if(!s)return false;
        move={id,start:t,end:t+(r?3:3.5),x:s.x,y:s.y};
        for(const b of G.bricks.filter(b=>Math.abs(b.x-s.x)<60&&Math.abs(b.y-s.y)<36))api.removeBrick(b);
      }else if(id==='tear')move={id,start:t,live:t+.6,x:250+Math.random()*280,land:860};
      else if(id==='gaze')move={id,start:t,live:t+1,end:t+(r?4.4:5),dir:Math.random()<.5?1:-1,slots:free(),seen:new Set(),made:0};
      else if(id==='mirage'){
        const slots=api.shuffle([...MIRAGE]);
        move={id,start:t,live:t+.8,end:t+(r?5.5:6.5),eyes:slots.map((x,i)=>({x:HOME,y:EYE.y,to:x,real:i===0,ph:i*2.1}))};
      }else if(id==='doom')move={id,start:t,live:t+.8,end:t+5.8,hits:0,need:3,pulse:0,flash:0};
      else return false;
      last=id;G.sound(id==='doom'?'abyss':'void',1,EYE.x);
      api.banner(...CALL[id],id==='doom'?'weak':'minor');G.predictionVersion++;return true;
    }
    const after=()=>{nextAt=G.time+(rage()?1.8:2.6);};
    function failOrbit(){
      const left=G.bricks.filter(b=>b.orbit),open=api.shuffle(free());move=null;after();restore(35);
      left.forEach((b,i)=>{const s=open[i];api.removeBrick(b);if(s)spawnAt(s,.05+i*.08,b);});
      G.sound('hydra',1,EYE.x);
    }
    function failSummon(){
      const P=R(),s={x:move.x,y:move.y},open=api.shuffle(free()).slice(0,rage()?7:5);move=null;after();restore(35);
      G.ring(s.x,s.y,P.beam,200);G.burst(s.x,s.y,P.beam,24,1.8);G.sound('void',1,s.x);
      open.forEach((o,i)=>spawnAt(o,.05+i*.08,s));
    }
    function failTear(){
      const P=R(),t=tearPos();move=null;after();restore(35);
      G.burst(t.x,t.y,P.shield,26,2);G.ring(t.x,t.y,P.shield,160);G.sound('shatter',1,t.x);G.shake=Math.max(G.shake,6);
      const near=free().sort((a,b)=>Math.hypot(a.x-t.x,a.y-t.y)-Math.hypot(b.x-t.x,b.y-t.y)).slice(0,rage()?6:4);
      near.forEach((o,i)=>spawnAt(o,.05+i*.06,t));
    }
    // The sweeping beam sprouts bricks in empty slots it crosses.
    function sweep(){
      const angle=beamAngle(),cap=rage()?6:4,chance=rage()?.55:.4;
      for(const s of move.slots){
        if(move.seen.has(s))continue;
        if(Math.abs(wrap(Math.atan2(s.y-EYE.y,s.x-EYE.x)-angle))>=.07)continue;
        move.seen.add(s);
        if(move.made<cap&&Math.random()<chance){move.made++;spawnAt(s,0);}
      }
    }
    function failGaze(){move=null;after();restore(30);}
    function failMirage(){
      const P=R(),fakes=move.eyes.filter(e=>!e.real),open=api.shuffle(free());move=null;after();restore(40);
      fakes.forEach((e,k)=>{G.burst(e.x,e.y,P.beam,14,1.4);for(let i=0;i<(rage()?3:2);i++){const s=open[k*3+i];if(s)spawnAt(s,.05+i*.1,e);}});
      G.sound('void',1,EYE.x);
    }
    function failDoom(){
      const P=R();move=null;nextAt=G.time+3;restore(100);
      G.shake=Math.max(G.shake,12);G.sound('boom',1,EYE.x);G.sound('abyss');
      G.ring(EYE.x,EYE.y,P.weak,900);G.ring(EYE.x,EYE.y,P.beam,500);api.flash('weak');
      lash(anchorCount(),true);
      api.shuffle(free()).slice(0,rage()?8:6).forEach((s,i)=>spawnAt(s,.1+i*.06));
    }
    // Phase three alternates 终焉 with its other move, opening with the other one.
    function pickMove(list){
      if(list.includes('doom')&&last&&last!=='doom')return 'doom';
      const pool=list.filter(id=>id!=='doom'),other=pool.filter(id=>id!==last),from=other.length?other:pool;
      return from[Math.floor(Math.random()*from.length)];
    }
    function step(){
      const t=G.time;
      if(is('orbit')&&t>=move.end)failOrbit();
      else if(is('summon')&&t>=move.end)failSummon();
      else if(is('tear')&&t>=move.live&&tearPos().y>=move.land)failTear();
      else if(is('gaze')&&t>=move.live){sweep();if(t>=move.end)failGaze();}
      else if(is('mirage')&&t>=move.end)failMirage();
      else if(is('doom')){
        if(t>=move.pulse){const k=(t-move.start)/(move.end-move.start);move.pulse=t+.5-.3*k;G.sound('void',1,EYE.x);}
        if(t>=move.end)failDoom();
      }
    }
    // ── The eye moves before physics; moves resolve after it.
    function pre(dt){
      const target=is('mirage')?move.eyes.find(e=>e.real).to:HOME;
      if(!api.dying())EYE.x+=G.reduced?target-EYE.x:(target-EYE.x)*Math.min(1,dt*6);
      if(is('mirage'))for(const e of move.eyes){e.x=e.real?EYE.x:e.x+(e.to-e.x)*(G.reduced?1:Math.min(1,dt*6));e.y=EYE.y;}
      if(is('orbit'))for(const b of G.bricks)if(b.orbit){const {x,y}=orbitAt(b.slot);if(x!==b.x||y!==b.y){b.x=x;b.y=y;Body.setPosition(b.body,{x,y});}}
    }
    function post(dt){
      hurt=Math.max(0,hurt-dt*3);if(move?.flash)move.flash=Math.max(0,move.flash-dt*4);
      drainFlash=drainFlash>0?Math.max(0,drainFlash-dt*3):Math.min(0,drainFlash+dt*3);
      wells=wells.filter(w=>G.time<w.end);beams=beams.filter(b=>G.time<b.end);snaps=snaps.filter(s=>G.time-s.born<.6);lashes=lashes.filter(l=>G.time-l.born<.6);
      shards=shards.filter(s=>{s.vy+=dt*900;s.x+=s.vx*dt;s.y+=s.vy*dt;s.a+=s.va*dt;return G.time-s.born<1.4;});
      for(const w of watchers)w.flash=Math.max(0,w.flash-dt*4);
      blink=Math.max(0,blink-dt*5);nextBlink-=dt;if(nextBlink<=0){blink=1;nextBlink=2.5+Math.random()*4;}
      if(whirl>0)whirl=Math.max(0,whirl-dt);
      if(api.dying()||api.busy())return;
      const m=fight(),P=R();
      // After a daze the ward reforms and the chains lash onto fresh bricks.
      if(dazeUntil&&!dazed()&&!mend){dazeUntil=0;mend={start:G.time,end:G.time+MEND};lash(anchorCount(),true);G.sound('anchor',1,EYE.x);}
      if(mend){
        m.data.ward=Math.min(100,100*(G.time-mend.start)/MEND);
        if(G.time>=mend.end){m.data.ward=100;mend=null;for(const w of watchers){w.blind=false;w.t0=G.time-w.i*BLINK/3;}G.sound('chime',1,EYE.x);G.ring(EYE.x,EYE.y,P.shield,SHIELD*3);G.predictionVersion++;}
      }else if(warding())m.data.ward=Math.min(100,ward()+dt*(REGEN+PER_ANCHOR*anchors().length)*(rage()?1.3:1));
      if(move)step();
      else if(!dazed()&&!mend&&G.time>=nextAt&&api.ready()){
        const list=m.abilities[m.phase-1],id=pickMove(list);
        if(!begin(id)&&!list.filter(i=>i!==id).some(i=>begin(i)))nextAt=G.time+1;
      }
    }
    const arm=(t=G.time)=>{move=null;last=null;nextAt=t+2.5;};
    const clearFx=()=>{wells=[];beams=[];snaps=[];lashes=[];move=null;mend=null;dazeUntil=0;};
    // ── Canvas. 0 → 1 as the eye opens during the intro; a restored fight starts open.
    const opened=()=>Math.max(0,Math.min(1,(api.introAge()-1.1)/.7));
    const torn=()=>Math.max(0,Math.min(1,(api.introAge()-.25)/.8));
    const jitter=i=>Math.sin(i*127.1)*.5+Math.sin(i*311.7)*.5;
    const doomK=()=>is('doom')?Math.max(0,Math.min(1,(G.time-move.live)/(move.end-move.live))):0;
    // Lid openness: blinks, sags when dazed, shuts and reopens over a phase shift, wide for 终焉.
    const eyeLid=o=>{
      if(api.dying())return o*1.15;
      let k=o*(1-blink*.9);if(dazed())k=o*.55;if(is('doom'))k=o*1.2;
      if(whirl>0)k*=Math.abs(Math.cos((1-whirl/1.1)*Math.PI));
      return k;
    };
    // Ward crystal bursting outward: on a daze, a phase shift and the collapse.
    function shatter(n,speed){
      if(G.reduced)return;
      for(let i=0;i<n;i++){const a=Math.random()*Math.PI*2,r=SHIELD*(.6+Math.random()*.6),v=speed*(.4+Math.random()*.8);
        shards.push({x:EYE.x+Math.cos(a)*r,y:EYE.y+Math.sin(a)*r,vx:Math.cos(a)*v,vy:Math.sin(a)*v-120,a:Math.random()*6,va:(Math.random()-.5)*12,s:6+Math.random()*12,born:G.time});}
    }
    function countdown(ctx,color,x,y,r,left){ctx.strokeStyle=color;ctx.lineWidth=3;ctx.beginPath();ctx.arc(x,y,r,-Math.PI/2,-Math.PI/2+Math.PI*2*Math.max(0,left));ctx.stroke();}
    // Behind the board: a dark halo, tentacles reaching out of the rift and
    // thorn wings on its ends. More of both each phase; red-tipped in the last.
    function drawBack(ctx){
      const P=R(),m=fight(),d=api.dying();if(!m?.intro||d?.exploded)return;
      const phase=m.phase,rise=Math.min(1,Math.max(0,(api.introAge()-.6)/1.2)),dim=dazed()?.5:1,red=phase>=3;
      ctx.save();ctx.lineCap='round';
      ctx.globalAlpha=(red?.22:.3)*rise*dim;
      if(!G.fx?.radial(ctx,EYE.x,EYE.y,300,[[0,red?P.irisRage:P.crack],[1,'transparent']],.1)){
        const halo=ctx.createRadialGradient(EYE.x,EYE.y,30,EYE.x,EYE.y,300);halo.addColorStop(0,red?P.irisRage:P.crack);halo.addColorStop(1,'transparent');ctx.fillStyle=halo;ctx.fillRect(EYE.x-300,0,600,EYE.y+300);
      }
      for(let i=0;i<2+phase*2;i++){
        const side=i%2?1:-1,k=Math.floor(i/2),x0=HOME+side*(150+k*30),y0=EYE.y+6,sway=G.reduced?0:Math.sin(G.time*(.8+k*.2)+i)*30;
        const len=(170+k*60)*rise,x1=x0+side*len*.5,y1=y0+len*.45+sway,x2=x0+side*len*.3+sway,y2=y0+len;
        ctx.strokeStyle=k%2?P.crackEdge:P.crack;ctx.globalAlpha=(k%2?.22:.35)*dim;
        let px=x0,py=y0;
        for(let s=1;s<=12;s++){const u=s/12,x=(1-u)**2*x0+2*(1-u)*u*x1+u*u*x2,y=(1-u)**2*y0+2*(1-u)*u*y1+u*u*y2;ctx.lineWidth=(12-k*2)*(1-u)+1.5;ctx.beginPath();ctx.moveTo(px,py);ctx.lineTo(x,y);ctx.stroke();px=x;py=y;}
        if(red){ctx.fillStyle=P.weak;ctx.globalAlpha=.6*dim*(.6+.4*Math.sin(G.time*3+i));ctx.beginPath();ctx.arc(px,py,3,0,Math.PI*2);ctx.fill();}
      }
      for(const side of [-1,1])for(let j=0;j<3+phase;j++){
        const a=side>0?-.15-j*.32:Math.PI+.15+j*.32,bx=HOME+side*(236-j*16),by=EYE.y-4+j*2,len=(64-j*6)*rise*(1+(G.reduced?0:.06*Math.sin(G.time*2+j))),w=7;
        const tx=bx+Math.cos(a)*len,ty=by+Math.sin(a)*len,nx=-Math.sin(a)*w,ny=Math.cos(a)*w;
        ctx.globalAlpha=.8*dim;ctx.fillStyle=P.crack;ctx.beginPath();ctx.moveTo(bx+nx,by+ny);ctx.lineTo(tx,ty);ctx.lineTo(bx-nx,by-ny);ctx.closePath();ctx.fill();
        ctx.strokeStyle=red?P.weak:P.crackEdge;ctx.lineWidth=1.4;ctx.globalAlpha=.7*dim;ctx.stroke();
      }
      ctx.restore();
    }
    function drawRift(ctx,P,k){
      ctx.globalAlpha=1;
      if(k<=0){if(!fight().intro){ctx.strokeStyle=P.crackEdge;ctx.globalAlpha=.35+.2*Math.sin(G.time*3);ctx.lineWidth=1.5;ctx.beginPath();ctx.moveTo(250,EYE.y);ctx.lineTo(530,EYE.y);ctx.stroke();}return;}
      const half=250*k,h=48*k,n=18,top=[],bottom=[];
      for(let i=0;i<=n;i++){const u=i/n,x=390-half+u*half*2,w=Math.sin(u*Math.PI)**.8,j=G.reduced?0:jitter(i+Math.floor(G.time*6))*3;top.push([x,EYE.y-h*w+jitter(i)*6*w+j]);bottom.push([x,EYE.y+h*w*.8+jitter(i+40)*6*w-j]);}
      ctx.beginPath();top.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));for(let i=n;i>=0;i--)ctx.lineTo(...bottom[i]);ctx.closePath();
      ctx.fillStyle=P.crack;ctx.fill();
      ctx.strokeStyle=fight().phase>=3?P.irisRage:P.crackEdge;ctx.lineWidth=2.2;ctx.globalAlpha=.7+.3*Math.sin(G.time*4);ctx.stroke();
      ctx.globalAlpha=.5;ctx.lineWidth=6;ctx.stroke();ctx.globalAlpha=1;
      if(!G.reduced)for(let i=0;i<10;i++){const u=(i*.137+G.time*.08)%1,x=390-half+u*half*2,y=EYE.y+Math.sin(G.time*1.7+i)*h*.55;ctx.fillStyle=P.crackEdge;ctx.globalAlpha=.6*Math.sin(u*Math.PI);ctx.fillRect(x-1.5,y-1.5,3,3);}
      ctx.globalAlpha=1;
    }
    // Chains: dashed curves from each anchor to the eye, slack and dim while dazed.
    function drawChains(ctx,P){
      ctx.lineWidth=2.4;ctx.strokeStyle=P.chain;ctx.setLineDash([7,5]);ctx.lineDashOffset=-G.time*30;
      for(const b of anchors()){
        const grow=Math.min(1,...lashes.filter(l=>l.x===b.x&&l.y===b.y).map(l=>(G.time-l.born)/.5)),sag=dazed()?60:36;
        const mx=(b.x+EYE.x)/2+Math.sin(G.time*1.3+b.x)*14,my=(b.y+EYE.y)/2+sag,ex=b.x+(EYE.x-b.x)*grow,ey=b.y+(EYE.y-b.y)*grow;
        ctx.globalAlpha=dazed()?.3:.75;ctx.beginPath();ctx.moveTo(b.x,b.y);ctx.quadraticCurveTo(b.x+(mx-b.x)*grow,b.y+(my-b.y)*grow,ex,ey);ctx.stroke();
        if(grow<1||dazed())continue;
        const u=(G.time*.7+b.y/300)%1,x=(1-u)**2*b.x+2*(1-u)*u*mx+u*u*EYE.x,y=(1-u)**2*b.y+2*(1-u)*u*my+u*u*EYE.y;
        ctx.globalAlpha=1;ctx.fillStyle=P.beam;ctx.beginPath();ctx.arc(x,y,3.2,0,Math.PI*2);ctx.fill();
      }
      ctx.setLineDash([]);ctx.globalAlpha=1;
      for(const s of snaps){const k=(G.time-s.born)/.6;ctx.globalAlpha=1-k;ctx.strokeStyle=P.chain;ctx.lineWidth=3*(1-k);ctx.setLineDash([6,8]);ctx.beginPath();ctx.moveTo(s.x,s.y);ctx.lineTo(s.x+(EYE.x-s.x)*(.5-k*.4),s.y+(EYE.y-s.y)*(.5-k*.4)+k*40);ctx.stroke();ctx.setLineDash([]);}
      ctx.globalAlpha=1;
    }
    function drawWell(ctx,P,w){
      const age=G.time-w.born,k=Math.min(1,age/.3)*Math.min(1,(w.end-G.time)/.4),r=34*k;
      ctx.globalAlpha=.3*k;ctx.strokeStyle=P.wellRim;ctx.lineWidth=1.2;ctx.setLineDash([3,6]);ctx.beginPath();ctx.arc(w.x,w.y,125,0,Math.PI*2);ctx.stroke();ctx.setLineDash([]);
      ctx.lineWidth=2.4;
      for(let arm=0;arm<3;arm++){ctx.globalAlpha=.8*k;ctx.beginPath();for(let i=0;i<=24;i++){const u=i/24,a=G.time*-3.2+arm*Math.PI*2/3+u*4.2,rr=r*.35+u*r*1.9;i?ctx.lineTo(w.x+Math.cos(a)*rr,w.y+Math.sin(a)*rr):ctx.moveTo(w.x+Math.cos(a)*rr,w.y+Math.sin(a)*rr);}ctx.stroke();}
      ctx.globalAlpha=k;ctx.fillStyle=P.well;ctx.beginPath();ctx.arc(w.x,w.y,r*.55,0,Math.PI*2);ctx.fill();ctx.strokeStyle=P.wellRim;ctx.lineWidth=2;ctx.stroke();
      ctx.globalAlpha=1;
    }
    function drawBeam(ctx,P,b){
      if(G.time<b.born)return;const k=(G.time-b.born)/(b.end-b.born),a=Math.sin(Math.min(1,k)*Math.PI);
      ctx.strokeStyle=P.beam;ctx.lineCap='round';
      ctx.lineWidth=7*a;ctx.globalAlpha=.25*a;ctx.beginPath();ctx.moveTo(b.ox,b.oy);ctx.lineTo(b.x,b.y);ctx.stroke();
      ctx.lineWidth=2;ctx.globalAlpha=a;ctx.stroke();
      ctx.beginPath();ctx.arc(b.x,b.y,8+22*k,0,Math.PI*2);ctx.stroke();ctx.globalAlpha=1;
    }
    // 凝视: a dashed telegraph, then a sweeping wedge.
    function drawGaze(ctx,P){
      const reach=1000,a=beamAngle();
      if(G.time<move.live){ctx.globalAlpha=.4+.4*Math.sin(G.time*30);ctx.strokeStyle=P.beam;ctx.lineWidth=1.6;ctx.setLineDash([10,8]);
        ctx.beginPath();ctx.moveTo(EYE.x,EYE.y);ctx.lineTo(EYE.x+Math.cos(a)*reach,EYE.y+Math.sin(a)*reach);ctx.stroke();ctx.setLineDash([]);ctx.globalAlpha=1;return;}
      const fade=Math.min(1,(move.end-G.time)/.15),w=.07;
      ctx.globalAlpha=.22*fade;ctx.fillStyle=P.beam;ctx.beginPath();ctx.moveTo(EYE.x,EYE.y);ctx.arc(EYE.x,EYE.y,reach,a-w,a+w);ctx.closePath();ctx.fill();
      ctx.globalAlpha=.9*fade;ctx.strokeStyle=P.beam;ctx.lineWidth=2.2;ctx.beginPath();ctx.moveTo(EYE.x,EYE.y);ctx.lineTo(EYE.x+Math.cos(a)*reach,EYE.y+Math.sin(a)*reach);ctx.stroke();ctx.globalAlpha=1;
    }
    // Watcher eyes: a dark socket; the eye opens on its cycle, shut or scarred otherwise.
    function drawWatchers(ctx,P){
      for(const w of watchers){
        const u=((G.time-w.t0)%BLINK+BLINK)%BLINK/BLINK,open=w.blind||!warding()?0:Math.max(0,Math.min(1,Math.min(u,.45-u)/.06)),s=w.flash&&!G.reduced?(Math.random()-.5)*w.flash*3:0,x=w.x+s;
        ctx.globalAlpha=.9;ctx.fillStyle=P.crack;ctx.beginPath();ctx.ellipse(x,w.y,WATCH_R+8,WATCH_R*.8+4,0,0,Math.PI*2);ctx.fill();ctx.strokeStyle=P.crackEdge;ctx.lineWidth=1.6;ctx.stroke();
        const h=WATCH_R*.72*open;
        if(w.blind){ctx.strokeStyle=P.weak;ctx.lineWidth=2.4;ctx.globalAlpha=.8;ctx.beginPath();ctx.moveTo(x-10,w.y-8);ctx.lineTo(x+10,w.y+8);ctx.moveTo(x+10,w.y-8);ctx.lineTo(x-10,w.y+8);ctx.stroke();continue;}
        if(h<1){ctx.strokeStyle=P.crackEdge;ctx.lineWidth=2;ctx.globalAlpha=.8;ctx.beginPath();ctx.moveTo(x-WATCH_R,w.y);ctx.quadraticCurveTo(x,w.y+5,x+WATCH_R,w.y);ctx.stroke();continue;}
        ctx.globalAlpha=1;ctx.beginPath();ctx.moveTo(x-WATCH_R,w.y);ctx.quadraticCurveTo(x,w.y-h*1.4,x+WATCH_R,w.y);ctx.quadraticCurveTo(x,w.y+h*1.4,x-WATCH_R,w.y);ctx.closePath();
        ctx.fillStyle=P.sclera;ctx.fill();ctx.save();ctx.clip();
        const ix=x+look.x*6,iy=w.y+look.y*3;ctx.fillStyle=rage()?P.irisRage:P.iris;ctx.beginPath();ctx.arc(ix,iy,WATCH_R*.5,0,Math.PI*2);ctx.fill();
        ctx.fillStyle=P.pupil;ctx.beginPath();ctx.ellipse(ix,iy,3,WATCH_R*.4,0,0,Math.PI*2);ctx.fill();ctx.restore();
        ctx.strokeStyle=P.weak;ctx.lineWidth=2.2;ctx.globalAlpha=.5+.4*Math.sin(G.time*10);ctx.beginPath();ctx.arc(x,w.y,WATCH_R+10,0,Math.PI*2);ctx.stroke();
      }
      ctx.globalAlpha=1;
    }
    // 召唤: a rotating hexagram that grows as it opens, with its countdown.
    function drawSigil(ctx,P){
      const {x,y}=move,left=(move.end-G.time)/(move.end-move.start),k=Math.min(1,(G.time-move.start)/.3),r=22+10*(1-left),a=G.time*1.6;
      ctx.globalAlpha=k*(.18+.12*Math.sin(G.time*10));ctx.fillStyle=P.beam;ctx.beginPath();ctx.arc(x,y,r+14,0,Math.PI*2);ctx.fill();
      ctx.globalAlpha=k;ctx.strokeStyle=P.beam;ctx.lineWidth=2;
      for(const off of [0,Math.PI]){ctx.beginPath();for(let i=0;i<3;i++){const u=a+off+i*Math.PI*2/3;i?ctx.lineTo(x+Math.cos(u)*r,y+Math.sin(u)*r):ctx.moveTo(x+Math.cos(u)*r,y+Math.sin(u)*r);}ctx.closePath();ctx.stroke();}
      ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.stroke();ctx.fillStyle=P.crack;ctx.beginPath();ctx.arc(x,y,7,0,Math.PI*2);ctx.fill();
      countdown(ctx,P.weak,x,y,r+8,left);ctx.globalAlpha=1;
    }
    // 泪滴: a crystal drop falling toward the sling, with a dashed line to where it lands.
    function drawTear(ctx,P){
      const t=tearPos(),k=Math.min(1,(G.time-move.start)/(move.live-move.start)),s=14*k;
      ctx.globalAlpha=.35;ctx.strokeStyle=P.shield;ctx.lineWidth=1.4;ctx.setLineDash([4,8]);ctx.beginPath();ctx.moveTo(t.x,t.y+s);ctx.lineTo(t.x,move.land);ctx.stroke();ctx.setLineDash([]);
      ctx.beginPath();ctx.ellipse(t.x,move.land,30,8,0,0,Math.PI*2);ctx.stroke();
      ctx.globalAlpha=1;const g=ctx.createLinearGradient(t.x,t.y-s*1.6,t.x,t.y+s);g.addColorStop(0,P.sclera);g.addColorStop(1,P.shield);ctx.fillStyle=g;
      ctx.beginPath();ctx.moveTo(t.x,t.y-s*1.8);ctx.quadraticCurveTo(t.x+s,t.y-s*.2,t.x+s,t.y+s*.2);ctx.arc(t.x,t.y+s*.2,s,0,Math.PI);ctx.quadraticCurveTo(t.x-s,t.y-s*.2,t.x,t.y-s*1.8);ctx.fill();
      ctx.strokeStyle=P.crackEdge;ctx.lineWidth=1.5;ctx.stroke();
      ctx.globalAlpha=.5+.4*Math.sin(G.time*12);ctx.strokeStyle=P.weak;ctx.lineWidth=2;ctx.beginPath();ctx.arc(t.x,t.y,s+10,0,Math.PI*2);ctx.stroke();ctx.globalAlpha=1;
    }
    // 晶环: the heart shard glows through the ring, and its countdown circles the eye.
    function drawOrbit(ctx,P){
      for(const b of G.bricks)if(b.heart){ctx.globalAlpha=.55+.4*Math.sin(G.time*9);ctx.strokeStyle=P.weak;ctx.lineWidth=3;ctx.beginPath();ctx.ellipse(b.x,b.y,b.w/2+8,b.h/2+8,0,0,Math.PI*2);ctx.stroke();}
      ctx.globalAlpha=.6;countdown(ctx,P.shield,EYE.x,EYE.y,SHIELD+22,(move.end-G.time)/(move.end-move.start));ctx.globalAlpha=1;
    }
    // Ward bubble: a hex lattice that pings on a glancing hit; 凝视 opens a notch at the beam.
    function drawWard(ctx,P,x,y,scale=1){
      const r=SHIELD*scale+Math.sin(G.time*2.4)*1.5,ping=Math.max(0,1-(G.time-pingAt)/.25),notch=is('gaze')&&G.time>=move.live?beamAngle():null,gap=.3;
      const a0=notch===null?0:notch+gap,a1=notch===null?Math.PI*2:notch+Math.PI*2-gap;
      ctx.globalAlpha=.1+ping*.2;ctx.fillStyle=P.shield;ctx.beginPath();ctx.moveTo(x,y);ctx.arc(x,y,r,a0,a1);ctx.closePath();ctx.fill();
      ctx.globalAlpha=.55+ping*.4;ctx.strokeStyle=P.shield;ctx.lineWidth=2+ping*2;ctx.beginPath();ctx.arc(x,y,r,a0,a1);ctx.stroke();
      ctx.lineWidth=1;ctx.globalAlpha=.3;
      for(let i=0;i<6;i++){const a=G.time*.4+i*Math.PI/3;ctx.beginPath();ctx.moveTo(x+Math.cos(a)*r*.55,y+Math.sin(a)*r*.55);ctx.lineTo(x+Math.cos(a)*r,y+Math.sin(a)*r);ctx.stroke();ctx.beginPath();ctx.arc(x,y,r*.55,a,a+Math.PI/3);ctx.stroke();}
      if(notch!==null){ctx.globalAlpha=.8+.2*Math.sin(G.time*14);ctx.strokeStyle=P.weak;ctx.lineWidth=3;ctx.beginPath();ctx.arc(x,y,r+4,notch-gap,notch+gap);ctx.stroke();}
      ctx.globalAlpha=1;
    }
    // Ward gauge: 24 segments round the ward; a daze shows its countdown instead.
    function drawGauge(ctx,P){
      const r=SHIELD+12;
      if(dazed()){countdown(ctx,P.weak,EYE.x,EYE.y,r,(dazeUntil-G.time)/dazeLen);return;}
      const n=Math.ceil(ward()/100*24),low=ward()<35;
      for(let i=0;i<24;i++){const a=-Math.PI/2+i*Math.PI/12;ctx.globalAlpha=i<n?1:.25;ctx.strokeStyle=i<n?(drainFlash>0?P.sclera:drainFlash<0?P.heal:low?P.weak:P.shield):P.chain;ctx.lineWidth=4;
        ctx.beginPath();ctx.arc(EYE.x,EYE.y,r,a+.04,a+Math.PI/12-.04);ctx.stroke();}
      ctx.globalAlpha=1;
    }
    function drawShards(ctx,P){
      if(G.fx){G.fx.shards(ctx,shards,G.time,P.shield,P.sclera,1.4,G.reduced?48:96);ctx.globalAlpha=1;return;}
      for(const s of shards){const k=1-(G.time-s.born)/1.4;ctx.save();ctx.globalAlpha=Math.max(0,k)*.8;ctx.translate(s.x,s.y);ctx.rotate(s.a);ctx.fillStyle=P.shield;ctx.strokeStyle=P.sclera;ctx.lineWidth=1;
        ctx.beginPath();ctx.moveTo(0,-s.s);ctx.lineTo(s.s*.6,s.s*.4);ctx.lineTo(-s.s*.5,s.s*.5);ctx.closePath();ctx.fill();ctx.stroke();ctx.restore();}
      ctx.globalAlpha=1;
    }
    // The pupil follows the aim, else the nearest arrow, else it wanders; dazed, it rolls.
    function updateLook(){
      let tx=Math.sin(G.time*.6)*.5,ty=.4;
      if(dazed()){tx=Math.cos(G.time*2.2)*.8;ty=Math.sin(G.time*2.2)*.5;}
      else if(G.drag){tx=-G.drag.dx/105;ty=.8;}
      else if(G.arrows.length){const a=G.arrows.reduce((b,c)=>c.body.position.y<b.body.position.y?c:b),dx=a.body.position.x-EYE.x,dy=a.body.position.y-EYE.y,d=Math.hypot(dx,dy)||1;tx=dx/d;ty=dy/d;}
      look.x+=(tx-look.x)*.12;look.y+=(ty-look.y)*.12;
    }
    // One eye at (x,y). Mirage fakes pass `wander` so their pupils drift instead of tracking.
    function drawEye(ctx,P,x,y,open,{scale=1,wander=null}={}){
      const dying=api.dying(),red=rage()||is('doom'),lid=eyeLid(open),r=EYE.r*scale,w=r*1.55,h=r*.95*lid,s=hurt&&!G.reduced?(Math.random()-.5)*hurt*5:0;
      const lx=wander===null?look.x:Math.sin(G.time*.9+wander)*.7,ly=wander===null?look.y:.4+Math.cos(G.time*1.3+wander)*.3;
      ctx.save();ctx.translate(x+s,y+(dazed()?6:0));
      ctx.globalAlpha=.35+.2*Math.sin(G.time*2)+doomK()*.3;ctx.fillStyle=red?P.irisRage:P.iris;ctx.beginPath();ctx.ellipse(0,0,w+10+doomK()*14,r*.95*open+10+doomK()*10,0,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;
      if(h<1.5){ctx.strokeStyle=P.crackEdge;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(-w,0);ctx.quadraticCurveTo(0,4,w,0);ctx.stroke();ctx.restore();return;}
      ctx.beginPath();ctx.moveTo(-w,0);ctx.quadraticCurveTo(0,-h*1.45,w,0);ctx.quadraticCurveTo(0,h*1.45,-w,0);ctx.closePath();
      const sclera=ctx.createRadialGradient(0,0,4,0,0,w);sclera.addColorStop(0,P.sclera);sclera.addColorStop(1,P.scleraShade);
      ctx.fillStyle=sclera;ctx.fill();ctx.save();ctx.clip();
      // Veins from phase two, thicker and red in the last.
      const phase=fight()?.phase||1;
      if(phase>=2||red){ctx.strokeStyle=phase>=3||red?P.irisRage:P.scleraShade;ctx.globalAlpha=phase>=3?.55:.4;ctx.lineWidth=phase>=3?1.4:1;for(let i=0;i<(phase>=3?10:6);i++){const a=i*.8+.3,vx=Math.cos(a)*w,vy=Math.sin(a)*h;ctx.beginPath();ctx.moveTo(vx,vy);ctx.quadraticCurveTo(vx*.6+jitter(i)*6,vy*.6,vx*.35,vy*.35);ctx.stroke();}ctx.globalAlpha=1;}
      const ix=lx*r*.45,iy=ly*h*.3,ir=r*.62;
      const iris=ctx.createRadialGradient(ix,iy,2,ix,iy,ir);iris.addColorStop(0,red?P.irisRage:P.iris);iris.addColorStop(1,P.irisDeep);
      ctx.fillStyle=iris;ctx.beginPath();ctx.arc(ix,iy,ir,0,Math.PI*2);ctx.fill();
      ctx.strokeStyle=P.sclera;ctx.globalAlpha=.35;ctx.lineWidth=1;ctx.setLineDash([2,4]);ctx.lineDashOffset=G.time*8;ctx.beginPath();ctx.arc(ix,iy,ir*.72,0,Math.PI*2);ctx.stroke();ctx.setLineDash([]);ctx.globalAlpha=1;
      // Dilated when dazed; a burning slit that swells while 终焉 charges.
      const dilate=dazed()?2.6:1+hurt*.6+doomK()*1.2;
      ctx.fillStyle=P.pupil;ctx.beginPath();ctx.ellipse(ix,iy,Math.min(ir*.8,ir*.2*dilate),ir*.72,0,0,Math.PI*2);ctx.fill();
      if(is('doom')){ctx.globalAlpha=.4+.5*doomK();ctx.fillStyle=P.weak;ctx.beginPath();ctx.ellipse(ix,iy,ir*.12*dilate,ir*.5,0,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;}
      ctx.fillStyle=P.sclera;ctx.globalAlpha=.9;ctx.beginPath();ctx.arc(ix-ir*.35,iy-ir*.4,3.2*scale,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;
      if(hurt){ctx.globalAlpha=hurt*.5;ctx.fillStyle=P.weak;ctx.fillRect(-w,-h*1.5,w*2,h*3);ctx.globalAlpha=1;}
      if(dying){ctx.strokeStyle=P.sclera;ctx.lineWidth=1.8;const k=Math.min(1,(G.time-dying.at)/1.3);for(let i=0;i<Math.ceil(k*9);i++){const a=i*.7+jitter(i),len=w*k;ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(Math.cos(a)*len*.5+jitter(i+9)*6,Math.sin(a)*len*.5);ctx.lineTo(Math.cos(a+.2)*len,Math.sin(a+.2)*len);ctx.stroke();}}
      ctx.restore(); // Leave the iris clip, but keep the eye's local transform.
      ctx.strokeStyle=red?P.irisRage:P.crackEdge;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(-w,0);ctx.quadraticCurveTo(0,-h*1.45,w,0);ctx.quadraticCurveTo(0,h*1.45,-w,0);ctx.stroke();
      ctx.restore(); // Return to world coordinates before wards, other eyes and the sling.
    }
    function drawField(ctx){
      const P=R(),m=fight(),d=api.dying(),open=m.intro?opened():0,tear=m.intro?torn():0,closing=d?.exploded?Math.max(0,1-(G.time-d.at-1.3)/.6):1;
      if(d?.exploded){drawRift(ctx,P,tear*closing);drawShards(ctx,P);return;}
      // Dazed: the arena dims around the exposed eye. 终焉 reddens it as the charge builds.
      if(dazed()){const k=Math.min(1,(G.time-(dazeUntil-dazeLen))/.3,(dazeUntil-G.time)/.3);ctx.globalAlpha=.45*k;
        if(!G.fx?.shade(ctx,780,G.H,EYE.x,EYE.y,60,760,P.crack)){const g=ctx.createRadialGradient(EYE.x,EYE.y,60,EYE.x,EYE.y,760);g.addColorStop(0,'transparent');g.addColorStop(1,P.crack);ctx.fillStyle=g;ctx.fillRect(0,0,780,G.H);}}
      if(is('doom')){ctx.globalAlpha=.06+.14*doomK();ctx.fillStyle=P.weak;ctx.fillRect(0,0,780,G.H);}
      ctx.globalAlpha=1;
      drawRift(ctx,P,tear*closing);
      if(m.intro)drawChains(ctx,P);
      for(const w of wells)drawWell(ctx,P,w);
      for(const b of beams)drawBeam(ctx,P,b);
      drawWatchers(ctx,P);
      if(is('gaze'))drawGaze(ctx,P);
      if(is('summon'))drawSigil(ctx,P);
      if(is('orbit'))drawOrbit(ctx,P);
      updateLook();
      if(is('mirage')&&G.time>=move.live){
        // Three identical eyes; only the real pupil follows the aim.
        for(const e of move.eyes){drawEye(ctx,P,e.x,e.y,open,{scale:.8,wander:e.real?null:e.ph});drawWard(ctx,P,e.x,e.y,.8);}
        ctx.globalAlpha=.6;countdown(ctx,P.beam,HOME,EYE.y+SHIELD+30,10,(move.end-G.time)/(move.end-move.live));ctx.globalAlpha=1;
      }else{
        drawEye(ctx,P,EYE.x,EYE.y,open);
        if(m.intro&&open>.5){
          if(dazed()){const r=EYE.r+14+Math.sin(G.time*5)*3;ctx.strokeStyle=P.weak;ctx.lineWidth=2.2;ctx.globalAlpha=.85;for(let i=0;i<4;i++){const a=G.time*1.2+i*Math.PI/2;ctx.beginPath();ctx.arc(EYE.x,EYE.y,r,a,a+.55);ctx.stroke();}ctx.globalAlpha=1;}
          else if(bare()){
            ctx.globalAlpha=.5+.4*Math.sin(G.time*9);ctx.strokeStyle=P.weak;ctx.lineWidth=3;ctx.beginPath();ctx.arc(EYE.x,EYE.y,EYE.r+12,0,Math.PI*2);ctx.stroke();
            for(let i=0;i<move.need;i++){ctx.globalAlpha=1;ctx.fillStyle=i<move.hits?P.weak:P.crack;ctx.strokeStyle=P.weak;ctx.lineWidth=1.5;ctx.beginPath();ctx.arc(EYE.x-12+i*12,EYE.y+SHIELD+14,4,0,Math.PI*2);ctx.fill();ctx.stroke();}
            ctx.globalAlpha=.8;countdown(ctx,P.weak,EYE.x,EYE.y,SHIELD+12,1-doomK());ctx.globalAlpha=1;
          }else{
            // While mending, the ward re-forms from the gauge outward.
            drawWard(ctx,P,EYE.x,EYE.y,mend ? .6+.4*Math.min(1,(G.time-mend.start)/MEND) : 1);
          }
          if(!bare()||dazed())drawGauge(ctx,P);
        }
      }
      if(is('tear'))drawTear(ctx,P);
      drawShards(ctx,P);
    }
    // Collapse charge: light rays burst out of the eye before it explodes.
    function drawFront(ctx){
      const d=api.dying();if(!d||d.exploded)return;
      const P=R(),k=Math.min(1,(G.time-d.at)/1.3);ctx.translate(EYE.x,EYE.y);ctx.fillStyle=P.beam;
      for(let i=0;i<12;i++){const a=i/12*Math.PI*2+G.time*.9,len=180+k*900,spread=.035+k*.05;ctx.globalAlpha=.18+.3*k;ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(Math.cos(a-spread)*len,Math.sin(a-spread)*len);ctx.lineTo(Math.cos(a+spread)*len,Math.sin(a+spread)*len);ctx.closePath();ctx.fill();}
      ctx.globalAlpha=1;
    }
    // ── Score: E phrygian, 8 bars (Em F Em/G Dm | C Bdim Em F), the flat
    // second always pulling back to E. A heartbeat kick and a tolling bell
    // run through it. Phase 1 is pad, drone bass, heartbeat and bell; phase 2
    // adds snare, hats and a creeping arp; phase 3 brings in the lead. A
    // telegraph (glare) wakes the arp under a riser; a daze drops the drums
    // for bells over a bright E major; the mend climbs back up; 终焉 strips
    // to a racing heartbeat and low bells.
    const BASS=[40,41,43,38,36,35,40,41],CHORD=[[52,55,59],[53,57,60],[55,59,64],[50,53,57],[48,52,55],[47,50,53],[52,55,59],[53,57,60]];
    const MELODY=[
      [[0,4,71],[4,2,72],[6,2,71],[8,8,67]],
      [[0,4,69],[4,4,72],[8,6,77],[14,2,76]],
      [[0,6,76],[6,2,74],[8,4,72],[12,4,71]],
      [[0,4,69],[4,4,65],[8,4,74],[12,4,72]],
      [[0,4,72],[4,2,71],[6,2,69],[8,8,67]],
      [[0,4,71],[4,4,74],[8,4,77],[12,4,74]],
      [[0,6,76],[6,2,77],[8,4,79],[12,4,76]],
      [[0,4,77],[4,4,76],[8,4,72],[12,4,71]]
    ];
    function events(step,phase,mood){
      const bar=step>>4,s=step&15,out=[],ch=CHORD[bar],root=BASS[bar],bright=mood==='stun'||mood==='mend';
      if(s===0)out.push({i:'pad',notes:bright?[52,56,59]:ch,vel:mood==='doom'?1.2:1,bright:bright?1:phase>=3?.4:0});
      if(mood==='intro'){if(s===0||s===3)out.push({i:'kick',vel:s?.6:1});return out;}
      // Dazed: no drums, bells over E major.
      if(mood==='stun'){
        if(s%4===0)out.push({i:'bell',note:[76,80,83,88][(s>>2)%4],vel:1});
        if(s===0)out.push({i:'bass',note:40,vel:.6,len:3});
        return out;
      }
      // 终焉: a racing heartbeat and a low bell on every half bar.
      if(mood==='doom'){
        if(s%4===0||s%4===3)out.push({i:'kick',vel:s%4?.6:1});
        if(s===0||s===8)out.push({i:'bell',note:root+12,vel:1.3});
        if(s===0)out.push({i:'bass',note:root,vel:.9,len:3.5});
        return out;
      }
      // Mending: a rising E major arpeggio and the heartbeat coming back.
      if(mood==='mend'){
        if(s%2===0)out.push({i:'arp',note:[64,68,71,76][(s>>1)%4],vel:.8,pan:s%4?.3:-.3});
        if(s===0||s===3)out.push({i:'kick',vel:s?.6:1});
        return out;
      }
      // The heartbeat never stops: lub-dub, thicker each phase.
      const kick=phase===1?[0,3]:phase===2?[0,3,8,11]:[0,3,6,8,11,14];if(kick.includes(s))out.push({i:'kick',vel:s%8===0?1:.65});
      if(phase>=2){
        if(s===4||s===12)out.push({i:'snare',vel:phase>=3?1:.8});
        if(s%(phase>=3?2:4)===2)out.push({i:'hat',vel:.6,open:phase>=3&&s===14});
      }
      // Drone bass on the root, jumping the octave in phase three.
      const bass=phase===1?[0]:phase===2?[0,8]:[0,6,8,14];
      if(bass.includes(s))out.push({i:'bass',note:phase>=3&&s===14?root+12:root,vel:s===0?1:.75,len:phase===1?3.5:1.2});
      // A tolling bell every other bar.
      if(s===0&&bar%2===0)out.push({i:'bell',note:root+24,vel:.8});
      // Creeping arp from phase two, or under a telegraph.
      if(phase>=2||mood==='glare'){const tones=[...ch,ch[0]+12],pat=[0,2,1,3,2,1],every=mood==='glare'||phase>=3?1:2;
        if(s%every===0)out.push({i:'arp',note:tones[pat[Math.floor(s/every)%6]]+12,vel:s%4===0?1:.6,pan:s%4<2?-.3:.3});}
      if(phase>=3)for(const [at,len,note] of MELODY[bar])if(at===s)out.push({i:'lead',note,len,vel:1});
      return out;
    }
    const score={
      bars:8,events,
      bpm:(phase,mood)=>(phase>=3?120:phase>=2?112:104)*(mood==='doom'?1.15:1),
      mix:[
        {pad:.95,bass:.8,drums:.7,arp:.6,lead:0,bell:.7},
        {pad:.85,bass:.9,drums:.85,arp:.65,lead:0,bell:.65},
        {pad:.75,bass:.95,drums:.95,arp:.6,lead:.8,bell:.7}
      ],
      moods:{intro:{pad:1,drums:.7,bass:0,arp:0,lead:0,bell:0},stun:{pad:1,bell:1,bass:.5,drums:0,arp:0,lead:0},
        mend:{pad:.9,arp:.8,drums:.6,bass:0,lead:0},doom:{pad:.8,bell:1,drums:1,bass:.9,arp:0,lead:0},glare:{arp:.8}},
      filter:{intro:1500,doom:1100},riser:['glare','mend','doom'],
      stab:[64,68,71,76],stinger:[40,47,52,56,59,64]
    };
    // What the score reads each tick.
    function music(){
      if(whirl>0)return {mood:'intro'};
      if(dazed())return {mood:'stun'};
      if(mend)return {mood:'mend'};
      if(is('doom'))return {mood:'doom'};
      if(move)return {mood:'glare'};
      return {mood:'fight'};
    }
    return {
      id:'eye',name:'深渊之眼',score,music,title:'ABYSS WARDEN',tagline:'',
      kicker:'WARNING · ABYSS',note:'',rageNote:'巨眼狂怒',hitLabel:'巨眼命中',roar:'abyss',
      seal:['ABYSS SEALED','深渊之眼 · 击溃',''],
      phaseNames:['苏醒','裂变','狂怒'],abilities,
      // Phase one opens with a target move; the last phase always adds 终焉.
      roll(pool){
        const list=pool.filter(id=>id!=='doom'),open=list.find(id=>OPENERS.includes(id)),rest=list.filter(id=>id!==open);
        return [[open],rest.slice(0,2),['doom',rest[2]]];
      },
      // About two or three dazes per phase.
      hp:phase=>Math.ceil(G.damage()*(18+5*phase)),
      mods:m=>({hp:1+.2*(m.phase-1),barriers:m.phase===api.phases()?8:0,decorate}),
      palette:()=>{const P=R();return {main:P.beam,hot:P.weak,light:P.sclera,text:P.text};},
      focus:()=>EYE,
      moving:()=>['orbit','mirage','gaze','tear'].some(is),
      status:()=>dazed()?{text:'失神',state:'exposed'}:mend?{text:'结界重组',state:'shielded'}:
        is('doom')&&G.time>=move.live?{text:`终焉 ${move.hits}/${move.need}`,state:'exposed'}:move?{text:abilities[move.id].name,state:'shielded'}:{text:`结界 ${Math.ceil(ward())}% · 锁链 ${anchors().length}`,state:'shielded'},
      init:data=>{data.ward=100;},
      validate:data=>(data.ward===undefined||Number.isFinite(data.ward)&&data.ward>=0&&data.ward<=100)&&(data.ring===undefined||Number.isFinite(data.ring)),
      // Orbiting shards belong to a move and never outlive a reload.
      hydrate(m){
        for(const b of G.bricks.filter(b=>b.type==='shard'))api.removeBrick(b);
        m.data.ward??=100;arm();buildWatchers();
      },
      intro(){arm(G.time+2.6);},
      shifted(){arm();whirl=G.reduced?0:1.1;shatter(40,520);},
      charging(){hurt=Math.max(hurt,.6);const P=R();if(Math.random()<.35)G.burst(EYE.x+(Math.random()-.5)*60,EYE.y+(Math.random()-.5)*40,Math.random()<.5?P.beam:P.weak,4,1.4);},
      exploded(){shatter(70,760);watchers=[];},
      pending:()=>wells.some(w=>G.time<w.end),
      calm:clearFx,
      reset(){clearFx();EYE.x=HOME;watchers=[];shards=[];whirl=0;},
      contact,physics,destroyed,pre,post,drawBack,drawField,drawFront,
      // Tests and the admin panel can open a move directly.
      start:id=>begin(id),watchers:()=>watchers,
      debug:()=>({ward:ward(),shielded:!dazed(),dazed:dazed(),mend:!!mend,anchors:anchors().length,move:move?.id||null,wells:wells.length,
        watchers:watchers.map(w=>w.blind),hits:move?.hits??0,beam:is('gaze')?beamAngle():null,sigil:is('summon')?{x:move.x,y:move.y}:null,
        tear:is('tear')?tearPos():null,eyes:is('mirage')?move.eyes.map(e=>({x:e.x,y:e.y,real:e.real})):null})
    };
  });
})();
