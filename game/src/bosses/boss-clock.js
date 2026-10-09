(() => {
  'use strict';
  // 时之君主: the board is a giant clock face. The core gem at its centre is
  // sealed in a crystal case: arrows glance off and it takes no damage while
  // the clock runs. The clock runs on a mainspring (发条, 0–100) that winds
  // itself back up over time. Drain it to zero and the clock stalls (停摆):
  // the case opens, the hands go slack and the core takes ×3 for a few
  // seconds, then a key winds the spring back to full and the case closes.
  // The spring drains from the numeral the stepping hour hand points at
  // (phase 1+), from escapement gears jammed on their glowing tooth (phase
  // 2+), and all at once from a correct answer to a move. A missed answer
  // costs the player: frozen arrows thrown back, wards, regrown bricks and
  // numerals, a faster clock or a rewound spring. One move at a time; the
  // last phase always adds 午夜.
  (window.SlingBosses||=[]).push(api=>{
    const {G,Composite,Body,has,rage}=api,fight=api.fight;
    const C={x:390,y:470},CORE_R=24,CASE_R=32,DIAL=250,HAND_R=7,KEY_R=18,BELL={y:800,r:26,sweep:250},BOB={len:360,r:30,arc:.55};
    // Escapement gears from phase two: left, right and above the core.
    const GEARS=[{x:240,y:470,dir:1},{x:540,y:470,dir:-1},{x:390,y:320,dir:1}],GEAR_R=34,TOOTH=.6;
    const fallback={face:'#1b2340',rim:'#b8923a',brass:'#d9ae4f',brassDeep:'#7a5a1c',hand:'#2a2f45',handEdge:'#e8c870',gem:'#4fb3e8',gemDeep:'#1b4f8a',stop:'#6fa8d8',ward:'#e0a92e',ghost:'#6f9fd8',text:'#7a5a1c',weak:'#e2493a',tick:'#b8a574'};
    const R=()=>window.SlingTheme?.canvas.clock||fallback;
    const abilities={
      stop:{name:'时停',desc:'表盘上出现发条钥匙，击碎则停摆；否则箭矢冻结后倒飞'},
      toll:{name:'鸣钟',desc:'巨钟摆荡三响，钟响前击中则震碎护罩；否则砖块披上金罩'},
      pendulum:{name:'钟摆',desc:'巨摆拦在弹弓前，连击斩断则停摆；否则发条回紧、指针加速'},
      rewind:{name:'倒流',desc:'时间回溯，射中晶壳打断；否则碎砖复原、发条上满'},
      haste:{name:'疾走',desc:'指针狂转，射中亮起的刻度卡住齿轮；否则刻度重生'},
      midnight:{name:'午夜',desc:'双针合于十二点，十二响内三击晶壳则停摆；否则刻度全部重生'}
    };
    // Phase one opens with a move whose answer is a visible target.
    const OPENERS=['stop','toll','pendulum'];
    const ROMAN=['XII','I','II','III','IV','V','VI','VII','VIII','IX','X','XI'];
    const STUN=4,STUN_MULT=3,REFILL=1.2,REGEN=3,DRAIN={lit:16,litBreak:24,gear:30};
    // turn: the minute hand's unwrapped angle; each lap past XII steps the hour hand.
    let minute=-Math.PI/2,turn=0,hourIdx=2,hour=-Math.PI/2+2*Math.PI/6,pt=0,spin=1,wound=1,hurt=0,hinted=false,whirl=0,gearTurn=0;
    let move=null,nextAt=0,last=null,stunUntil=0,stunLen=STUN,refill=null,frozen=null,wave=null,drop=null,litBrick=null,history=[],gears=[],shards=[],pingAt=0,drainFlash=0,stepFlash=0;
    const spring=()=>fight()?.data.spring??100;
    const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
    const hourAt=i=>{const a=-Math.PI/2+i*Math.PI/6;return {x:C.x+Math.cos(a)*DIAL,y:C.y+Math.sin(a)*DIAL*.95,a};};
    const numerals=()=>G.bricks.filter(b=>b.type==='hour');
    const broken=()=>12-numerals().length;
    const blocked=p=>G.obstacles.some(o=>Math.abs(o.x-p.x)<76&&Math.abs(o.y-p.y)<46);
    // Numeral slots that are empty and can take a numeral again.
    const missing=()=>[...Array(12).keys()].filter(i=>{const p=hourAt(i);return !numerals().some(b=>b.hourIndex===i)&&!blocked(p)&&!api.occupied(p.x,p.y,50,32);});
    const stunned=()=>G.time<stunUntil;
    // The spring only drains while the clock is running and not rewinding itself.
    const winding=()=>!stunned()&&!refill&&!api.dying()&&!!fight()?.intro;
    const is=id=>move?.id===id;
    const handTip=(a,len)=>({x:C.x+Math.cos(a)*len,y:C.y+Math.sin(a)*len});
    // The lit numeral is the one the hour hand points at.
    const lit=()=>numerals().find(b=>b.hourIndex===hourIdx)||null;
    const hands=()=>[{a:minute,len:235},{a:hour,len:155}];
    const tag=b=>{const a=Math.atan2((b.y-C.y)/.95,b.x-C.x);b.hourAngle=a;b.hourIndex=((Math.round((a+Math.PI/2)/(Math.PI/6))%12)+12)%12;};
    const numeralHp=()=>Math.max(G.baseHp()*2,Math.ceil(G.damage()*(2+fight().phase)));
    const bellPos=()=>{const u=(G.time-move.start)*(rage()?1.7:1.3),k=Math.min(1,(G.time-move.start)/.6);return {x:C.x+Math.sin(u)*BELL.sweep,y:BELL.y-(1-k)*60,tilt:Math.cos(u)*.3,k};};
    const bobPos=()=>{const k=Math.min(1,(G.time-move.start)/(move.live-move.start)),th=G.time<move.live?0:Math.sin((G.time-move.live)*(rage()?1.6:1.25))*BOB.arc;return {x:C.x+Math.sin(th)*BOB.len*k,y:C.y+Math.cos(th)*BOB.len*k,k};};

    // ── Board: core cell cleared, twelve numeral bricks on the dial.
    function decorate(){
      const hp=numeralHp();
      for(const b of G.bricks.filter(b=>Math.hypot(b.x-C.x,b.y-C.y)<60))api.removeBrick(b);
      if(fight().phase>=2)for(const g of GEARS)for(const b of G.bricks.filter(b=>Math.abs(b.x-g.x)<GEAR_R+44&&Math.abs(b.y-g.y)<GEAR_R+20))api.removeBrick(b);
      fight().data.spring=100;
      for(let i=0;i<12;i++){
        const p=hourAt(i);
        if(blocked(p))continue;
        for(const b of G.bricks.filter(b=>Math.abs(b.x-p.x)<70&&Math.abs(b.y-p.y)<40))api.removeBrick(b);
        G.makeBrick({x:p.x,y:p.y,w:56,h:36,hp,max:hp,type:'hour',frozen:false});
      }
    }
    function regrowNumeral(i){
      const p=hourAt(i);
      if(!missing().includes(i))return false;
      const hp=numeralHp(),b=G.makeBrick({x:p.x,y:p.y,w:56,h:36,hp,max:hp,type:'hour',frozen:false});
      tag(b);api.pop(b,R().brass);G.initial++;G.predictionVersion++;G.sound('chime',1,p.x);return true;
    }
    const buildGears=()=>{gears=fight()?.phase>=2?GEARS.map((g,i)=>({...g,i,a:i*2.1,jammed:false,flash:0})):[];};
    // ── Stall: the case opens, the hands go slack and the core takes ×3.
    function jam(x,y,label,a,len=STUN){
      const P=R(),m=fight();move=null;m.data.spring=0;stunLen=len;stunUntil=G.time+len;refill=null;nextAt=stunUntil+REFILL+(rage()?1.4:2.2);
      if(a)api.pay(a,x,y-10,2);
      G.float(x,y-34,label,P.text,20);G.ring(x,y,P.ward,140);G.ring(C.x,C.y,P.gem,DIAL+40);G.ring(C.x,C.y,P.ward,CASE_R*3);
      G.burst(x,y,P.brass,24,2);G.burst(C.x,C.y,P.gem,20,1.6);
      G.shake=Math.max(G.shake,10);G.coreFlash=.6;api.freeze(140);G.sound('jam',1,x);
      api.banner('STALLED','停摆',`时核暴露 · 伤害 ×${STUN_MULT}`,'weak');G.predictionVersion++;
    }
    function drain(n,x,y,label){
      const m=fight();if(!m||!winding())return;
      m.data.spring=Math.max(0,spring()-n);drainFlash=1;
      G.ring(C.x,C.y,R().brass,CASE_R+30);
      if(m.data.spring<=0)jam(x,y,label||'停摆',G.activeArrow);
    }
    // Wards absorb one hit; the lit numeral drains the spring on every hit, and
    // during 疾走 any arrow striking it stalls the clock outright.
    const baseHit=G.hit;
    G.hit=(b,damage,depth=0)=>{
      if(fight()?.boss==='clock'&&G.bricks.includes(b)&&depth<70){
        if(is('haste')&&G.time>=move.live&&depth===0&&G.activeArrow&&b===litBrick)jam(b.x,b.y,'卡齿',G.activeArrow);
        if(b.ward){const P=R();b.ward=false;b.flash=.2;G.ring(b.x,b.y,P.ward,50);G.burst(b.x,b.y,P.ward,6,.8);G.sound('chime',1,b.x);G.predictionVersion++;return;}
        if(b===litBrick&&depth===0&&G.activeArrow){const P=R();G.ring(b.x,b.y,P.ward,70);G.sound('chime',1,b.x);drain(DRAIN.lit,b.x,b.y,'正点');}
      }
      return baseHit(b,damage,depth);
    };
    function destroyed(b,depth){
      const P=R();
      if(depth<3)history.push({x:b.x,y:b.y,w:b.w,h:b.h,max:b.max,type:b.type==='hour'?'hour':'normal'}),history=history.slice(-12);
      if(b.type==='hour'){
        const bright=b===litBrick;
        api.hurt(G.damage()*.5,b.x,b.y);
        G.ring(b.x,b.y,bright?P.ward:P.brass,bright?130:70);G.sound('bell',1,b.x);
        if(bright){const a=G.activeArrow;if(a)api.pay(a,b.x,b.y-10,2);G.float(b.x,b.y-40,'正点',P.text,18);api.freeze(70);if(depth===0)drain(DRAIN.litBreak,b.x,b.y,'正点');}
      }else api.hurt(G.damage()*.04,b.x,b.y,{quiet:true});
    }
    // Sealed: arrows glance off. Answers still register on the case (倒流, 午夜).
    function strikeCore(a,x,y){
      const P=R();
      if(stunned()){
        if(!api.canStrike(a))return;
        api.strike(a,x,y,STUN_MULT);hurt=1;
        G.burst(x,y,P.gem,22,2);G.ring(x,y,P.gem,120);G.shake=Math.min(14,G.shake+6);G.sound('eyehit',1,x);G.sound('chime',1,x);api.freeze(70);
        return;
      }
      if(G.time<(a.caseAt||0))return;a.caseAt=G.time+.15;
      if(is('rewind')){jam(x,y,'打断',a);return;}
      if(is('midnight')&&G.time>=move.lock){move.hits++;move.flash=1;G.ring(C.x,C.y,P.weak,60+move.hits*30);G.burst(x,y,P.weak,10,1.2);G.sound('clang',1,x);if(move.hits>=move.need)jam(x,y,'停摆',a,STUN+1.5);return;}
      G.burst(x,y,P.ghost,5,.6);G.sound('ricochet',1,x);pingAt=G.time;
      if(!hinted){hinted=true;G.toast?.('时核被封住：耗尽发条让时钟停摆');}
    }
    // An escapement gear jams only when the arrow lands on its glowing tooth.
    function hitGear(a,g,p){
      const P=R(),at=Math.atan2(p.y-g.y,p.x-g.x);g.flash=1;
      if(g.jammed||!winding()||Math.abs(wrap(at-g.a))>TOOTH){G.burst(p.x,p.y,P.handEdge,4,.6);G.sound('ricochet',1,p.x);return;}
      g.jammed=true;G.burst(p.x,p.y,P.ward,16,1.6);G.ring(g.x,g.y,P.ward,GEAR_R*3);G.sound('clang',1,p.x);G.float(g.x,g.y-GEAR_R-16,'卡死',P.text,16);api.freeze(60);
      drain(gears.every(t=>t.jammed)?100:DRAIN.gear,g.x,g.y,'卡死');
    }

    // ── Colliders: case, hands (slack while stalled), gears and the current move's target.
    function contact(a,live){
      const hit=api.bounceCircle(a,C.x,C.y,(stunned()?CORE_R:CASE_R)+3);
      if(hit){if(live){a.trail=[];strikeCore(a,hit.x,hit.y);}return;}
      if(!stunned())for(const h of hands()){
        const s=handTip(h.a,CASE_R+4),e=handTip(h.a,h.len),p=api.bounceCapsule(a,s.x,s.y,e.x,e.y,HAND_R,.92);
        if(p){if(live){a.trail=[];G.burst(p.x,p.y,R().handEdge,5,.7);G.sound('ricochet',1,p.x);}return;}
      }
      for(const g of gears){const p=api.bounceCircle(a,g.x,g.y,GEAR_R+3);if(p){if(live&&G.time>=(a.gearAt||0)){a.gearAt=G.time+.15;a.trail=[];hitGear(a,g,p);}return;}}
      if(is('stop')){const p=api.bounceCircle(a,move.x,move.y,KEY_R+3);if(p&&live){a.trail=[];jam(move.x,move.y,'停摆',a);}return;}
      if(is('toll')&&G.time>=move.start+.6){const b=bellPos(),p=api.bounceCircle(a,b.x,b.y,BELL.r+3);if(p&&live){a.trail=[];shatterBell(a,b);}return;}
      if(is('pendulum')&&G.time>=move.live){const b=bobPos(),p=api.bounceCircle(a,b.x,b.y,BOB.r+3);if(p&&live&&G.time>=(a.bobAt||0)){a.bobAt=G.time+.2;a.trail=[];hitBob(a,b);}}
    }
    // ── Moves. begin() sets up the telegraph; each fail*() is the cost of a missed answer.
    const CALL={
      stop:['TIME STOP','时停','击碎发条'],toll:['TOLL','鸣钟','钟响前击中巨钟'],pendulum:['PENDULUM','钟摆','连击斩断巨摆'],
      rewind:['REWIND','倒流','射中晶壳打断'],haste:['HASTE','疾走','射中亮起的刻度'],midnight:['MIDNIGHT','午夜','十二响内三击晶壳']
    };
    // The winding key sits between two lower numerals, on a lane the sling can reach.
    function keySpot(){
      const spots=api.shuffle([3.5,4.5,5.5,6.5,7.5,8.5].map(i=>{const a=-Math.PI/2+i*Math.PI/6;return {x:C.x+Math.cos(a)*(DIAL-30),y:C.y+Math.sin(a)*(DIAL-30)*.95};}));
      return spots.find(p=>!api.occupied(p.x,p.y,50,30))||spots[0];
    }
    function begin(id){
      if(move||frozen||stunned()||refill)return false;
      const t=G.time,r=rage();
      if(id==='rewind'){
        const ghosts=history.filter(h=>!api.occupied(h.x,h.y,h.w*.6,h.h*.6)).slice(-(r?10:8));
        if(!ghosts.length)return false;
        move={id,start:t,end:t+(r?2.6:3),ghosts};history=[];
      }else if(id==='haste'){
        if(!numerals().length)return false;
        move={id,start:t,live:t+.9,end:t+(r?6:5)};
      }else if(id==='stop')move={id,start:t,end:t+(r?2.2:2.6),...keySpot()};
      else if(id==='toll')move={id,start:t,rung:0,next:t+1.4,gap:r?.95:1.2};
      else if(id==='pendulum')move={id,start:t,live:t+1,end:t+(r?9:8),hits:0,need:r?4:3};
      else if(id==='midnight')move={id,start:t,lock:t+1.2,rung:0,next:t+1.6,gap:.4,hits:0,need:3};
      else return false;
      last=id;G.sound(id==='toll'||id==='midnight'?'bell':'tick',1,C.x);
      api.banner(...CALL[id],id==='midnight'?'weak':'minor');G.predictionVersion++;return true;
    }
    function failStop(){
      const P=R();move=null;frozen={until:G.time+(rage()?2.4:2),list:[]};rewindSpring(30);
      for(const a of [...G.arrows])freezeArrow(a);
      G.sound('timestop');G.coreFlash=.5;G.ring(C.x,C.y,P.stop,900);api.freeze(90);
    }
    function freezeArrow(a){Composite.remove(G.engine.world,a.body);frozen.list.push({a,vx:a.body.velocity.x,vy:a.body.velocity.y});G.arrows=G.arrows.filter(t=>t!==a);}
    // Thawed arrows fly back the way they came.
    function thaw(){
      const P=R();
      for(const {a,vx,vy} of frozen.list){Composite.add(G.engine.world,a.body);Body.setVelocity(a.body,{x:-vx*.8,y:-vy*.8});a.color=P.ghost;G.arrows.push(a);G.burst(a.body.position.x,a.body.position.y,P.stop,4,.8);}
      if(frozen.list.length){G.phase='flying';G.sound('chime',1,C.x);G.ring(C.x,C.y,P.stop,500);}
      frozen=null;nextAt=G.time+(rage()?1.6:2.4);
    }
    function shatterBell(a,b){
      const P=R();move=null;
      for(const t of G.bricks)t.ward=false;
      G.burst(b.x,b.y,P.ward,30,2.2);G.ring(b.x,b.y,P.ward,200);G.sound('shatter',1,b.x);
      jam(b.x,b.y,'碎音',a);
      G.withArrow(a,()=>{for(const n of numerals())G.hit(n,G.damage(),1);});
    }
    function failToll(){
      const P=R();move=null;wave={r:CORE_R,cap:rage()?14:10,warded:0};nextAt=G.time+(rage()?1.8:2.6);
      // Numerals are warded first, then the bricks closest to the dial.
      for(const n of numerals())if(wave.warded<wave.cap){n.ward=true;wave.warded++;}
      G.sound('bell',1,C.x);G.ring(C.x,C.y,P.ward,300);G.shake=Math.max(G.shake,5);G.predictionVersion++;
    }
    function updateWave(dt){
      if(!wave)return;
      const prev=wave.r;wave.r+=dt*650;
      for(const b of G.bricks){if(wave.warded>=wave.cap)break;const d=Math.hypot(b.x-C.x,b.y-C.y);if(!b.ward&&!b.orbit&&d>=prev&&d<wave.r){b.ward=true;wave.warded++;G.predictionVersion++;}}
      if(wave.r>760)wave=null;
    }
    function hitBob(a,b){
      const P=R();move.hits++;move.flash=1;
      G.burst(b.x,b.y,P.brass,8,1);G.sound('clang',1,b.x);G.shake=Math.max(G.shake,3);
      if(move.hits<move.need)return;
      drop={x:b.x,y:b.y,at:G.time};G.burst(b.x,b.y,P.brassDeep,26,2.2);G.sound('shatter',1,b.x);
      jam(b.x,b.y,'断摆',a);
    }
    function failPendulum(){
      const P=R();move=null;wound=Math.min(1.9,wound+.3);nextAt=G.time+(rage()?1.6:2.4);rewindSpring(40);
      G.float(C.x,C.y-60,'上紧',P.text,18);G.ring(C.x,C.y,P.brass,DIAL);G.sound('tick',1,C.x);
    }
    function failRewind(){
      const P=R(),ghosts=move.ghosts;move=null;nextAt=G.time+(rage()?1.8:2.6);rewindSpring(100);
      G.sound('timestop');G.ring(C.x,C.y,P.ghost,700);
      ghosts.forEach((g,i)=>api.later(.1+i*.12,()=>{
        if(!fight()||api.dying()||G.bricks.length>=230||api.occupied(g.x,g.y,g.w*.6,g.h*.6))return;
        const b=G.makeBrick({x:g.x,y:g.y,w:g.w,h:g.h,hp:g.max,max:g.max,type:g.type,frozen:false});
        if(g.type==='hour')tag(b);api.pop(b,P.ghost);G.initial++;G.predictionVersion++;G.sound('chime',1,g.x);
      }));
    }
    // A missed answer winds the spring back up.
    function rewindSpring(n){const m=fight();if(m){m.data.spring=Math.min(100,spring()+n);drainFlash=-1;}}
    function regrowMany(list,step){
      list.forEach((i,k)=>api.later(.1+k*step,()=>{if(fight()&&!api.dying())regrowNumeral(i);}));
      return list.length;
    }
    function failHaste(){
      move=null;nextAt=G.time+(rage()?1.6:2.4);
      if(!regrowMany(api.shuffle(missing()).slice(0,rage()?3:2),.25))wound=Math.min(1.9,wound+.2);
    }
    function failMidnight(){
      const P=R();move=null;wound=Math.min(1.9,wound+.3);nextAt=G.time+3;rewindSpring(100);
      G.shake=Math.max(G.shake,12);G.sound('bell',1,C.x);G.sound('boom',1,C.x);
      G.ring(C.x,C.y,P.weak,900);G.ring(C.x,C.y,P.brass,DIAL+50);api.flash('weak');
      regrowMany(missing(),.15);
    }
    // ── Clock. Hands turn before physics; moves resolve after it.
    // The minute hand sweeps; every lap past XII steps the hour hand onto the next numeral.
    function stepHour(d){
      hourIdx=((hourIdx+d)%12+12)%12;stepFlash=1;G.predictionVersion++;
      const b=lit();G.sound('tick',1,b?.x??C.x);if(b){b.flash=.25;api.pop(b,R().ward);}
    }
    const lap=()=>((minute+Math.PI/2)%(Math.PI*2)+Math.PI*2)%(Math.PI*2);
    function pre(dt){
      if(frozen){litBrick=lit();return;}
      pt+=dt;stepFlash=Math.max(0,stepFlash-dt*3);drainFlash=drainFlash>0?Math.max(0,drainFlash-dt*3):Math.min(0,drainFlash+dt*3);
      const slow=1-Math.min(6,broken())*.05,base=(rage()?1.4:1)*wound*spin,up=-Math.PI/2,running=!stunned()&&!refill;
      if(whirl>0){whirl-=dt;minute-=dt*9;hour-=dt*3;turn=lap();}
      else{
        if(stunned()){minute+=wrap(Math.PI/2+.15-minute)*Math.min(1,dt*3);turn=lap();}
        else if(is('midnight')){minute+=wrap(up+.06-minute)*(G.time<move.lock?Math.min(1,dt*4):1);turn=lap();if(hourIdx){hourIdx=0;stepFlash=1;}}
        else if(running){
          const f=is('rewind')?-2.5:is('haste')&&G.time>=move.live?3:1,d=dt*.9*slow*base*f;minute+=d;turn+=d;
          while(turn>=Math.PI*2){turn-=Math.PI*2;stepHour(1);}
          while(turn<0){turn+=Math.PI*2;stepHour(-1);}
        }
        // The hour hand snaps onto its numeral; it sags with the minute hand when stalled.
        const target=stunned()?Math.PI/2-.15:up+hourIdx*Math.PI/6+(is('midnight')?-.06:0);
        hour+=wrap(target-hour)*(G.reduced?1:Math.min(1,dt*(stunned()?3:14)));
      }
      for(const g of gears){g.flash=Math.max(0,g.flash-dt*4);if(!g.jammed&&running)g.a+=dt*1.2*base*g.dir;}
      if(running)gearTurn+=dt*base;
      litBrick=lit();
    }
    function step(){
      const t=G.time,P=R();
      if(['stop','rewind','haste'].includes(move.id)&&t>=(move.tickAt||0)){move.tickAt=t+(is('haste')?.25:.5);G.sound('tick',1,is('stop')?move.x:C.x);}
      if(is('stop')&&t>=move.end)failStop();
      else if(is('toll')&&t>=move.next){const b=bellPos();move.rung++;move.next=t+move.gap;G.sound('bell',1,b.x);G.ring(b.x,b.y,P.ward,60+move.rung*30);if(move.rung>=3)failToll();}
      else if(is('pendulum')&&t>=move.end)failPendulum();
      else if(is('rewind')&&t>=move.end)failRewind();
      else if(is('haste')&&t>=move.end)failHaste();
      else if(is('midnight')&&t>=move.next){move.rung++;move.next=t+move.gap;G.sound(move.rung%3?'tick':'bell',1,C.x);if(move.rung>=12)failMidnight();}
    }
    // Phase three alternates 午夜 with its other move, opening with the other one.
    function pickMove(list){
      if(list.includes('midnight')&&last&&last!=='midnight')return 'midnight';
      const pool=list.filter(id=>id!=='midnight'),other=pool.filter(id=>id!==last),from=other.length?other:pool;
      return from[Math.floor(Math.random()*from.length)];
    }
    function post(dt){
      hurt=Math.max(0,hurt-dt*3);if(move?.flash)move.flash=Math.max(0,move.flash-dt*4);
      shards=shards.filter(s=>{s.vy+=dt*900;s.x+=s.vx*dt;s.y+=s.vy*dt;s.a+=s.va*dt;return G.time-s.born<1.4;});
      if(frozen){
        for(const a of [...G.arrows]){a.stopSeen??=G.time;if(G.time-a.stopSeen>=.25)freezeArrow(a);}
        if(G.time>=frozen.until)thaw();
      }
      updateWave(dt);
      if(drop&&G.time-drop.at>.8)drop=null;
      if(api.dying()||api.busy())return;
      const m=fight(),P=R();
      // After a stall a key winds the spring back to full, then the case closes.
      if(stunUntil&&!stunned()&&!refill){stunUntil=0;refill={start:G.time,end:G.time+REFILL,tickAt:0};G.sound('timestop');}
      if(refill){
        m.data.spring=Math.min(100,100*(G.time-refill.start)/REFILL);
        if(G.time>=refill.tickAt){refill.tickAt=G.time+.15;G.sound('tick',1,C.x);}
        if(G.time>=refill.end){m.data.spring=100;refill=null;for(const g of gears)g.jammed=false;G.sound('chime',1,C.x);G.ring(C.x,C.y,P.brass,CASE_R*3);G.predictionVersion++;}
      }else if(winding())m.data.spring=Math.min(100,spring()+dt*REGEN*(rage()?1.3:1));
      if(move)step();
      else if(!frozen&&!stunned()&&!refill&&G.time>=nextAt&&api.ready()){
        const list=m.abilities[m.phase-1],id=pickMove(list);
        if(!begin(id)&&!list.filter(i=>i!==id).some(i=>begin(i)))nextAt=G.time+1;
      }
    }
    const arm=(t=G.time)=>{move=null;last=null;nextAt=t+2.5;};
    const clearFx=()=>{move=null;frozen=null;wave=null;drop=null;refill=null;stunUntil=0;shards=[];for(const b of G.bricks)b.ward=false;};
    // ── Canvas. Backdrop: dial face, minute ticks and turning gears.
    function cog(ctx,x,y,r,teeth,a){
      ctx.beginPath();for(let i=0;i<teeth*2;i++){const u=a+i*Math.PI/teeth,rr=i%2?r*.82:r;i?ctx.lineTo(x+Math.cos(u)*rr,y+Math.sin(u)*rr):ctx.moveTo(x+Math.cos(u)*rr,y+Math.sin(u)*rr);}ctx.closePath();
    }
    function gear(ctx,x,y,r,teeth,a){cog(ctx,x,y,r,teeth,a);ctx.stroke();ctx.beginPath();ctx.arc(x,y,r*.3,0,Math.PI*2);ctx.stroke();}
    // Dial glass bursting outward: on a phase shift and when the clock breaks.
    function shatter(n,speed){
      if(G.reduced)return;
      for(let i=0;i<n;i++){const a=Math.random()*Math.PI*2,r=DIAL*(.2+Math.random()*.9),v=speed*(.4+Math.random()*.8);
        shards.push({x:C.x+Math.cos(a)*r,y:C.y+Math.sin(a)*r*.95,vx:Math.cos(a)*v,vy:Math.sin(a)*v-120,a:Math.random()*6,va:(Math.random()-.5)*12,s:8+Math.random()*16,born:G.time});}
    }
    // The sovereign's crown above the dial: tilts and glows red in the last phase, dims when stalled.
    function drawCrown(ctx,P,rise){
      const phase=fight()?.phase||1,drop=(1-rise)*-120,y=C.y-DIAL-78+drop,s=64,tilt=phase>=3?-.08+Math.sin(G.time*1.3)*.02:0;
      ctx.save();ctx.translate(C.x,y);ctx.rotate(tilt);ctx.globalAlpha=rise*(stunned()?.55:.95);
      const g=ctx.createLinearGradient(0,-s,0,s*.4);g.addColorStop(0,P.handEdge);g.addColorStop(1,P.brassDeep);ctx.fillStyle=g;ctx.strokeStyle=P.rim;ctx.lineWidth=2.5;
      ctx.beginPath();ctx.moveTo(-s,s*.35);ctx.lineTo(-s,-s*.2);
      for(let i=0;i<5;i++){const x0=-s+i*s*.5,x1=x0+s*.25,x2=x0+s*.5,tip=i===2?-s*.95:i%2?-s*.55:-s*.75;ctx.lineTo(x1,tip);ctx.lineTo(x2,-s*.2);}
      ctx.lineTo(s,s*.35);ctx.closePath();ctx.fill();ctx.stroke();
      ctx.fillStyle=P.face;ctx.fillRect(-s,s*.05,s*2,s*.3);ctx.strokeRect(-s,s*.05,s*2,s*.3);
      const hot=phase>=3?P.weak:P.gem;
      for(let i=0;i<5;i++){const x=-s+s*.25+i*s*.5,tip=i===2?-s*.95:i%2?-s*.55:-s*.75;ctx.fillStyle=hot;ctx.beginPath();ctx.arc(x,tip,i===2?7:5,0,Math.PI*2);ctx.fill();}
      ctx.fillStyle=hot;for(let i=-2;i<=2;i++){ctx.beginPath();ctx.moveTo(i*s*.36,s*.2-6);ctx.lineTo(i*s*.36+6,s*.2);ctx.lineTo(i*s*.36,s*.2+6);ctx.lineTo(i*s*.36-6,s*.2);ctx.closePath();ctx.fill();}
      if(phase>=3){ctx.strokeStyle=P.face;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(s*.3,-s*.2);ctx.lineTo(s*.42,s*.05);ctx.lineTo(s*.36,s*.35);ctx.stroke();}
      ctx.restore();
    }
    function drawBack(ctx){
      const P=R(),d=api.dying(),rise=Math.min(1,Math.max(0,api.introAge()/1.4));if(d?.exploded)return;
      const phase=fight()?.phase||1,dim=stunned()?.55:1;
      ctx.save();
      // Clockwork wings: brass spokes fanning out behind the dial, turning with the clock.
      ctx.strokeStyle=P.brassDeep;ctx.lineCap='round';
      for(let i=0;i<24;i++){const a=gearTurn*.05+i*Math.PI/12,r0=DIAL+56,r1=DIAL+(i%2?96:140);ctx.globalAlpha=.3*rise*dim;ctx.lineWidth=i%2?2:4;
        ctx.beginPath();ctx.moveTo(C.x+Math.cos(a)*r0,C.y+Math.sin(a)*r0*.95);ctx.lineTo(C.x+Math.cos(a)*r1,C.y+Math.sin(a)*r1*.95);ctx.stroke();}
      ctx.globalAlpha=.35*rise*dim;ctx.lineWidth=1.5;ctx.beginPath();ctx.ellipse(C.x,C.y,DIAL+100,(DIAL+100)*.95,0,0,Math.PI*2);ctx.stroke();
      // Face: enamel in phase one; a skeleton ring over the works from phase two; red-hot and cracked in the last.
      ctx.fillStyle=P.face;
      if(phase===1){ctx.globalAlpha=.55*rise;ctx.beginPath();ctx.ellipse(C.x,C.y,DIAL+50,(DIAL+50)*.95,0,0,Math.PI*2);ctx.fill();}
      else{ctx.globalAlpha=.6*rise;ctx.beginPath();ctx.ellipse(C.x,C.y,DIAL+50,(DIAL+50)*.95,0,0,Math.PI*2);ctx.ellipse(C.x,C.y,DIAL-40,(DIAL-40)*.95,0,0,Math.PI*2);ctx.fill('evenodd');
        ctx.globalAlpha=.22*rise;ctx.beginPath();ctx.ellipse(C.x,C.y,DIAL-40,(DIAL-40)*.95,0,0,Math.PI*2);ctx.fill();}
      if(phase>=3){ctx.globalAlpha=(.18+.08*Math.sin(G.time*2))*rise*dim;
        if(!G.fx?.radial(ctx,C.x,C.y,DIAL,[[0,P.weak],[1,'transparent']],20/DIAL)){const g=ctx.createRadialGradient(C.x,C.y,20,C.x,C.y,DIAL);g.addColorStop(0,P.weak);g.addColorStop(1,'transparent');ctx.fillStyle=g;ctx.fillRect(C.x-DIAL,C.y-DIAL,DIAL*2,DIAL*2);}
        ctx.strokeStyle=P.weak;ctx.lineWidth=1.5;ctx.globalAlpha=.45*rise;for(const [a,l] of [[.4,90],[2.3,70],[4.1,110],[5.4,60]]){const r0=DIAL+50,x=C.x+Math.cos(a)*r0,y=C.y+Math.sin(a)*r0*.95;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x-Math.cos(a)*l*.5+8,y-Math.sin(a)*l*.5);ctx.lineTo(x-Math.cos(a)*l,y-Math.sin(a)*l+6);ctx.stroke();}}
      ctx.globalAlpha=.8*rise;ctx.strokeStyle=stunned()?P.ward:P.rim;ctx.lineWidth=4;ctx.beginPath();ctx.ellipse(C.x,C.y,DIAL+50,(DIAL+50)*.95,0,0,Math.PI*2);ctx.stroke();
      ctx.lineWidth=1.2;ctx.beginPath();ctx.ellipse(C.x,C.y,DIAL+38,(DIAL+38)*.95,0,0,Math.PI*2);ctx.stroke();
      ctx.strokeStyle=P.tick;
      for(let i=0;i<60;i++){const a=-Math.PI/2+i*Math.PI/30,r0=DIAL+(i%5?30:22),r1=DIAL+38;ctx.globalAlpha=(i%5?.4:.8)*rise;ctx.lineWidth=i%5?1:2.4;ctx.beginPath();ctx.moveTo(C.x+Math.cos(a)*r0,C.y+Math.sin(a)*r0*.95);ctx.lineTo(C.x+Math.cos(a)*r1,C.y+Math.sin(a)*r1*.95);ctx.stroke();}
      // Works: background gears, more of them once the face is cut away. They stop dead when stalled.
      ctx.strokeStyle=P.brassDeep;ctx.lineWidth=2;const t=gearTurn*spin;ctx.globalAlpha=(phase>=2?.7:.5)*rise;
      gear(ctx,C.x-150,C.y-40,70,14,t*.4);gear(ctx,C.x+120,C.y+90,54,11,-t*.52);gear(ctx,C.x+40,C.y-150,40,9,t*.7);
      if(phase>=2){gear(ctx,C.x-60,C.y+140,48,10,-t*.6);gear(ctx,C.x+160,C.y-110,36,8,-t*.8);gear(ctx,C.x-190,C.y+90,30,7,t*.9);}
      drawCrown(ctx,P,rise);
      ctx.restore();
    }
    function drawHand(ctx,P,a,len,w,alpha){
      ctx.save();ctx.globalAlpha=alpha;ctx.translate(C.x,C.y);ctx.rotate(a);
      ctx.fillStyle=P.hand;ctx.strokeStyle=P.handEdge;ctx.lineWidth=2;
      ctx.beginPath();ctx.moveTo(-30,-w*.6);ctx.lineTo(len-18,-w);ctx.lineTo(len,0);ctx.lineTo(len-18,w);ctx.lineTo(-30,w*.6);ctx.closePath();ctx.fill();ctx.stroke();
      ctx.beginPath();ctx.arc(-34,0,w*1.3,0,Math.PI*2);ctx.fill();ctx.stroke();
      ctx.restore();
    }
    // Countdown arc around a target: full at the telegraph, empty at the deadline.
    function countdown(ctx,color,x,y,r,left){ctx.strokeStyle=color;ctx.lineWidth=3;ctx.beginPath();ctx.arc(x,y,r,-Math.PI/2,-Math.PI/2+Math.PI*2*Math.max(0,left));ctx.stroke();}
    function drawKey(ctx,P){
      const {x,y}=move,left=(move.end-G.time)/(move.end-move.start),k=Math.min(1,(G.time-move.start)/.3);
      ctx.globalAlpha=k*(.3+.2*Math.sin(G.time*10));ctx.fillStyle=P.stop;ctx.beginPath();ctx.arc(x,y,KEY_R+12,0,Math.PI*2);ctx.fill();
      ctx.globalAlpha=k;cog(ctx,x,y,KEY_R,8,G.time*(2+4*(1-left)));ctx.fillStyle=P.brass;ctx.fill();ctx.strokeStyle=P.brassDeep;ctx.lineWidth=2;ctx.stroke();
      ctx.fillStyle=P.face;ctx.fillRect(x-4,y-4,8,8);
      countdown(ctx,P.stop,x,y,KEY_R+8,left);
    }
    function drawBell(ctx,P){
      const b=bellPos(),s=BELL.r;
      ctx.save();ctx.globalAlpha=b.k;ctx.translate(b.x,b.y);ctx.rotate(b.tilt);
      const g=ctx.createLinearGradient(-s,-s,s,s);g.addColorStop(0,P.handEdge);g.addColorStop(1,P.brassDeep);
      ctx.fillStyle=g;ctx.strokeStyle=P.rim;ctx.lineWidth=2;
      ctx.beginPath();ctx.moveTo(-s*.95,s*.7);ctx.quadraticCurveTo(-s*.7,s*.4,-s*.6,-s*.2);ctx.quadraticCurveTo(-s*.55,-s,0,-s);ctx.quadraticCurveTo(s*.55,-s,s*.6,-s*.2);ctx.quadraticCurveTo(s*.7,s*.4,s*.95,s*.7);ctx.closePath();ctx.fill();ctx.stroke();
      ctx.fillRect(-s,s*.62,s*2,s*.2);ctx.strokeRect(-s,s*.62,s*2,s*.2);
      ctx.fillStyle=P.brassDeep;ctx.beginPath();ctx.arc(0,s*.95,s*.18,0,Math.PI*2);ctx.fill();
      ctx.strokeStyle=P.rim;ctx.beginPath();ctx.arc(0,-s*1.12,s*.18,0,Math.PI*2);ctx.stroke();
      ctx.restore();
      // Three pips: one fills per toll; the third fills the board with wards.
      for(let i=0;i<3;i++){ctx.globalAlpha=b.k;ctx.fillStyle=i<move.rung?P.ward:P.face;ctx.strokeStyle=P.ward;ctx.lineWidth=1.5;ctx.beginPath();ctx.arc(b.x-14+i*14,b.y-s-22,4,0,Math.PI*2);ctx.fill();ctx.stroke();}
    }
    function drawBob(ctx,P){
      const b=bobPos();
      if(G.time<move.live){ctx.globalAlpha=.35;ctx.strokeStyle=P.brass;ctx.lineWidth=1.5;ctx.setLineDash([6,8]);ctx.beginPath();ctx.arc(C.x,C.y,BOB.len,Math.PI/2-BOB.arc,Math.PI/2+BOB.arc);ctx.stroke();ctx.setLineDash([]);}
      ctx.globalAlpha=1;ctx.strokeStyle=P.brassDeep;ctx.lineWidth=4;ctx.beginPath();ctx.moveTo(C.x,C.y);ctx.lineTo(b.x,b.y);ctx.stroke();
      const r=BOB.r*b.k,g=ctx.createRadialGradient(b.x-8,b.y-8,3,b.x,b.y,r);g.addColorStop(0,P.handEdge);g.addColorStop(1,P.brassDeep);
      ctx.fillStyle=g;ctx.beginPath();ctx.arc(b.x,b.y,r,0,Math.PI*2);ctx.fill();ctx.strokeStyle=move.flash?P.ward:P.rim;ctx.lineWidth=2+move.flash*2;ctx.stroke();
      // One crack per hit, and pips for the hits still needed.
      ctx.strokeStyle=P.face;ctx.lineWidth=2;for(let i=0;i<move.hits;i++){const a=i*2.1+.4;ctx.beginPath();ctx.moveTo(b.x,b.y);ctx.lineTo(b.x+Math.cos(a)*r*.9,b.y+Math.sin(a)*r*.9);ctx.stroke();}
      for(let i=0;i<move.need;i++){ctx.fillStyle=i<move.hits?P.ward:P.face;ctx.beginPath();ctx.arc(b.x-(move.need-1)*6+i*12,b.y+r+12,3.5,0,Math.PI*2);ctx.fill();ctx.strokeStyle=P.ward;ctx.lineWidth=1;ctx.stroke();}
      countdown(ctx,P.brass,b.x,b.y,r+7,(move.end-G.time)/(move.end-move.live));
    }
    // Escapement gears: the glowing tooth is the only spot that jams them.
    function drawGears(ctx,P){
      for(const g of gears){
        const shake=g.flash&&!G.reduced?(Math.random()-.5)*g.flash*3:0,x=g.x+shake;
        ctx.globalAlpha=1;cog(ctx,x,g.y,GEAR_R,10,g.a+.31);
        const f=ctx.createRadialGradient(x-8,g.y-8,4,x,g.y,GEAR_R);f.addColorStop(0,g.jammed?P.tick:P.handEdge);f.addColorStop(1,g.jammed?P.face:P.brassDeep);
        ctx.fillStyle=f;ctx.fill();ctx.strokeStyle=g.flash?P.ward:P.rim;ctx.lineWidth=2;ctx.stroke();
        ctx.strokeStyle=P.face;ctx.lineWidth=3;for(let i=0;i<3;i++){const a=g.a+i*Math.PI*2/3;ctx.beginPath();ctx.moveTo(x,g.y);ctx.lineTo(x+Math.cos(a)*GEAR_R*.62,g.y+Math.sin(a)*GEAR_R*.62);ctx.stroke();}
        ctx.fillStyle=P.face;ctx.beginPath();ctx.arc(x,g.y,7,0,Math.PI*2);ctx.fill();ctx.strokeStyle=P.rim;ctx.lineWidth=1.5;ctx.stroke();
        if(g.jammed){ctx.fillStyle=P.ward;ctx.beginPath();const a=g.a;ctx.moveTo(x+Math.cos(a)*(GEAR_R+10),g.y+Math.sin(a)*(GEAR_R+10));ctx.lineTo(x+Math.cos(a+.22)*(GEAR_R-4),g.y+Math.sin(a+.22)*(GEAR_R-4));ctx.lineTo(x+Math.cos(a-.22)*(GEAR_R-4),g.y+Math.sin(a-.22)*(GEAR_R-4));ctx.closePath();ctx.fill();continue;}
        if(stunned()||refill)continue;
        // The live window: an arc on the rim and a bright tooth.
        ctx.globalAlpha=.35+.25*Math.sin(G.time*8+g.i);ctx.strokeStyle=P.ward;ctx.lineWidth=6;ctx.beginPath();ctx.arc(x,g.y,GEAR_R+6,g.a-TOOTH,g.a+TOOTH);ctx.stroke();
        ctx.globalAlpha=1;ctx.fillStyle=P.ward;ctx.beginPath();ctx.arc(x+Math.cos(g.a)*(GEAR_R+2),g.y+Math.sin(g.a)*(GEAR_R+2),6,0,Math.PI*2);ctx.fill();
      }
      ctx.globalAlpha=1;
    }
    // Crystal case: six petals that slide apart when the clock stalls and close as it rewinds.
    function drawCase(ctx,P){
      const open=stunned()?Math.min(1,(G.time-(stunUntil-stunLen))/.35):refill?1-Math.min(1,(G.time-refill.start)/REFILL):0;
      const ping=Math.max(0,1-(G.time-pingAt)/.25),glow=is('midnight')?.4+.3*Math.sin(G.time*9):is('rewind')?.3+.2*Math.sin(G.time*14):0;
      for(let i=0;i<6;i++){
        const a=i*Math.PI/3,push=open*26,cx=C.x+Math.cos(a+Math.PI/6)*push,cy=C.y+Math.sin(a+Math.PI/6)*push;
        ctx.globalAlpha=(1-open*.75)*.55+ping*.3;ctx.fillStyle=P.stop;ctx.strokeStyle=P.handEdge;ctx.lineWidth=1.5;
        ctx.beginPath();ctx.moveTo(cx,cy);ctx.lineTo(cx+Math.cos(a)*CASE_R,cy+Math.sin(a)*CASE_R);ctx.lineTo(cx+Math.cos(a+Math.PI/3)*CASE_R,cy+Math.sin(a+Math.PI/3)*CASE_R);ctx.closePath();
        ctx.fill();ctx.globalAlpha=(1-open*.6);ctx.stroke();
      }
      if(glow){ctx.globalAlpha=glow;ctx.strokeStyle=is('midnight')?P.weak:P.ghost;ctx.lineWidth=3;ctx.beginPath();ctx.arc(C.x,C.y,CASE_R+6,0,Math.PI*2);ctx.stroke();}
      ctx.globalAlpha=1;
    }
    // Mainspring gauge: 24 segments round the case; a stall shows its countdown instead.
    function drawGauge(ctx,P){
      const r=CASE_R+14;
      if(stunned()){countdown(ctx,P.ward,C.x,C.y,r,(stunUntil-G.time)/stunLen);return;}
      const n=Math.ceil(spring()/100*24),low=spring()<35;
      for(let i=0;i<24;i++){const a=-Math.PI/2+i*Math.PI/12;ctx.globalAlpha=i<n?1:.25;ctx.strokeStyle=i<n?(drainFlash>0?P.handEdge:drainFlash<0?P.ghost:low?P.weak:P.brass):P.tick;ctx.lineWidth=4;
        ctx.beginPath();ctx.arc(C.x,C.y,r,a+.04,a+Math.PI/12-.04);ctx.stroke();}
      ctx.globalAlpha=1;
    }
    // Winding key over the core while the spring refills.
    function drawWinder(ctx,P){
      const k=Math.min(1,(G.time-refill.start)/.2),a=(G.time-refill.start)*9,y=C.y-CASE_R-30;
      ctx.save();ctx.globalAlpha=k;ctx.translate(C.x,y);ctx.fillStyle=P.brass;ctx.strokeStyle=P.brassDeep;ctx.lineWidth=2;
      ctx.fillRect(-3,4,6,20);ctx.strokeRect(-3,4,6,20);ctx.scale(Math.cos(a),1);
      for(const s of [-1,1]){ctx.beginPath();ctx.arc(s*12,0,10,0,Math.PI*2);ctx.fill();ctx.stroke();}
      ctx.restore();
    }
    function drawShards(ctx,P){
      if(G.fx){G.fx.shards(ctx,shards,G.time,P.stop,P.handEdge,1.4,G.reduced?48:96);ctx.globalAlpha=1;return;}
      for(const s of shards){const k=1-(G.time-s.born)/1.4;ctx.save();ctx.globalAlpha=Math.max(0,k)*.8;ctx.translate(s.x,s.y);ctx.rotate(s.a);ctx.fillStyle=P.stop;ctx.strokeStyle=P.handEdge;ctx.lineWidth=1;
        ctx.beginPath();ctx.moveTo(0,-s.s);ctx.lineTo(s.s*.6,s.s*.4);ctx.lineTo(-s.s*.5,s.s*.5);ctx.closePath();ctx.fill();ctx.stroke();ctx.restore();}
      ctx.globalAlpha=1;
    }
    function drawField(ctx){
      const P=R(),d=api.dying();if(d?.exploded){drawShards(ctx,P);return;}
      // Stalled: the arena dims around the open core.
      if(stunned()){const k=Math.min(1,(G.time-(stunUntil-stunLen))/.3,(stunUntil-G.time)/.3);ctx.globalAlpha=.45*k;
        if(!G.fx?.shade(ctx,780,G.H,C.x,C.y,60,700,P.face)){const g=ctx.createRadialGradient(C.x,C.y,60,C.x,C.y,700);g.addColorStop(0,'transparent');g.addColorStop(1,P.face);ctx.fillStyle=g;ctx.fillRect(0,0,780,G.H);}}
      if(frozen){const k=Math.min(1,(frozen.until-G.time)/.3);ctx.globalAlpha=.14*k;ctx.fillStyle=P.stop;ctx.fillRect(0,0,780,G.H);}
      if(wave){ctx.globalAlpha=Math.max(0,1-wave.r/760)*.8;ctx.strokeStyle=P.ward;ctx.lineWidth=4;ctx.beginPath();ctx.arc(C.x,C.y,wave.r,0,Math.PI*2);ctx.stroke();ctx.lineWidth=1;ctx.beginPath();ctx.arc(C.x,C.y,wave.r*.9,0,Math.PI*2);ctx.stroke();}
      // Wards: gold corner brackets.
      ctx.strokeStyle=P.ward;ctx.lineWidth=2.2;
      for(const b of G.bricks)if(b.ward){ctx.globalAlpha=.6+.3*Math.sin(G.time*5+b.x);const l=b.x-b.w/2-4,t=b.y-b.h/2-4,r=b.x+b.w/2+4,bt=b.y+b.h/2+4;
        ctx.beginPath();ctx.moveTo(l,t+9);ctx.lineTo(l,t);ctx.lineTo(l+9,t);ctx.moveTo(r-9,t);ctx.lineTo(r,t);ctx.lineTo(r,t+9);ctx.moveTo(r,bt-9);ctx.lineTo(r,bt);ctx.lineTo(r-9,bt);ctx.moveTo(l+9,bt);ctx.lineTo(l,bt);ctx.lineTo(l,bt-9);ctx.stroke();}
      // 倒流: dashed outlines where broken bricks will return, and a backward arc.
      if(is('rewind')){
        const left=(move.end-G.time)/(move.end-move.start);ctx.strokeStyle=P.ghost;ctx.lineWidth=1.6;ctx.setLineDash([5,5]);
        for(const g of move.ghosts){ctx.globalAlpha=.35+.25*Math.sin(G.time*6+g.x);ctx.strokeRect(g.x-g.w/2,g.y-g.h/2,g.w,g.h);}
        ctx.setLineDash([]);ctx.globalAlpha=.8;ctx.strokeStyle=P.ghost;ctx.lineWidth=3;ctx.beginPath();ctx.arc(C.x,C.y,CORE_R+16,-Math.PI/2,-Math.PI/2-Math.PI*2*left,true);ctx.stroke();
      }
      // Numerals: roman labels; the lit one glows, much brighter during 疾走.
      const rush=is('haste')&&G.time>=move.live;
      ctx.font='700 12px "DM Sans", "Noto Sans SC", sans-serif';ctx.textAlign='center';
      for(const b of numerals()){const on=b===litBrick,ox=Math.cos(b.hourAngle)*38,oy=Math.sin(b.hourAngle)*30;
        if(on){ctx.globalAlpha=rush?.9:.5+.4*Math.sin(G.time*8);ctx.strokeStyle=rush?P.weak:P.ward;ctx.lineWidth=rush?4:3;ctx.strokeRect(b.x-b.w/2-3,b.y-b.h/2-3,b.w+6,b.h+6);}
        ctx.globalAlpha=on?1:.75;ctx.fillStyle=on?(rush?P.weak:P.ward):P.tick;ctx.fillText(ROMAN[b.hourIndex],b.x+ox,b.y+oy+4);}
      ctx.globalAlpha=1;
      // The hour hand's numeral: a gold frame that pops each step.
      if(litBrick&&!stunned()){const b=litBrick,p=6+stepFlash*8;ctx.globalAlpha=.7+.3*stepFlash;ctx.strokeStyle=P.ward;ctx.lineWidth=2.5;ctx.strokeRect(b.x-b.w/2-p,b.y-b.h/2-p,b.w+p*2,b.h+p*2);ctx.globalAlpha=1;}
      drawGears(ctx,P);
      if(is('pendulum'))drawBob(ctx,P);
      if(drop){const u=(G.time-drop.at)/.8;ctx.globalAlpha=1-u;ctx.fillStyle=P.brassDeep;ctx.beginPath();ctx.arc(drop.x,drop.y+u*u*260,BOB.r*(1-u*.4),0,Math.PI*2);ctx.fill();}
      // Hands: slack and faded while jammed, arrows pass straight through.
      const slack=stunned()?.35:1;
      drawHand(ctx,P,hour,155,9,slack);drawHand(ctx,P,minute,235,6,slack);
      // 午夜: twelve tolls around the dial, and the hits still needed on the core.
      if(is('midnight')){
        for(let i=0;i<12;i++){const a=-Math.PI/2+i*Math.PI/6,x=C.x+Math.cos(a)*(DIAL+62),y=C.y+Math.sin(a)*(DIAL+62)*.95;ctx.globalAlpha=1;ctx.fillStyle=i<move.rung?P.weak:P.face;ctx.strokeStyle=P.weak;ctx.lineWidth=1.5;ctx.beginPath();ctx.arc(x,y,5,0,Math.PI*2);ctx.fill();ctx.stroke();}
        ctx.globalAlpha=.5+.4*Math.sin(G.time*9);ctx.strokeStyle=P.weak;ctx.lineWidth=3;ctx.beginPath();ctx.arc(C.x,C.y,CORE_R+12,0,Math.PI*2);ctx.stroke();
        for(let i=0;i<move.need;i++){ctx.globalAlpha=1;ctx.fillStyle=i<move.hits?P.weak:P.face;ctx.beginPath();ctx.arc(C.x-12+i*12,C.y+CORE_R+22,4,0,Math.PI*2);ctx.fill();ctx.stroke();}
      }
      if(stunned()){ctx.globalAlpha=.35+.25*Math.sin(G.time*10);ctx.fillStyle=P.ward;ctx.beginPath();ctx.arc(C.x,C.y,CORE_R+10,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;}
      drawGauge(ctx,P);
      // Core gem.
      const s=hurt&&!G.reduced?(Math.random()-.5)*hurt*4:0,pulse=1+.05*Math.sin(G.time*3);
      ctx.save();ctx.globalAlpha=1;ctx.translate(C.x+s,C.y);ctx.rotate(Math.PI/4+gearTurn*.3);
      const g=ctx.createLinearGradient(-CORE_R,-CORE_R,CORE_R,CORE_R);g.addColorStop(0,P.gem);g.addColorStop(1,P.gemDeep);
      ctx.fillStyle=g;ctx.strokeStyle=stunned()?P.ward:P.rim;ctx.lineWidth=3;const r=CORE_R*.85*pulse;ctx.fillRect(-r,-r,r*2,r*2);ctx.strokeRect(-r,-r,r*2,r*2);
      ctx.strokeStyle=P.handEdge;ctx.lineWidth=1;ctx.globalAlpha=.6;ctx.beginPath();ctx.moveTo(-r,-r);ctx.lineTo(r,r);ctx.moveTo(r,-r);ctx.lineTo(-r,r);ctx.stroke();
      if(hurt){ctx.globalAlpha=hurt*.6;ctx.fillStyle=P.weak;ctx.fillRect(-r,-r,r*2,r*2);}
      ctx.restore();
      drawCase(ctx,P);
      if(refill)drawWinder(ctx,P);
      if(is('stop'))drawKey(ctx,P);
      if(is('toll')&&G.time>=move.start)drawBell(ctx,P);
      // Frozen arrows hang in place with a halo.
      for(const {a,vx,vy} of frozen?.list||[]){const p=a.body.position,ang=Math.atan2(vy,vx);
        ctx.globalAlpha=.5;ctx.strokeStyle=P.stop;ctx.lineWidth=1.5;ctx.beginPath();ctx.arc(p.x,p.y,11+Math.sin(G.time*6)*2,0,Math.PI*2);ctx.stroke();
        ctx.globalAlpha=1;ctx.strokeStyle=P.ghost;ctx.lineWidth=2.3;ctx.lineCap='round';ctx.beginPath();ctx.moveTo(p.x-Math.cos(ang)*26,p.y-Math.sin(ang)*26);ctx.lineTo(p.x+Math.cos(ang)*4,p.y+Math.sin(ang)*4);ctx.stroke();}
      ctx.globalAlpha=1;
      drawShards(ctx,P);
    }
    function drawFront(ctx){
      const d=api.dying();if(!d||d.exploded)return;
      const P=R(),k=Math.min(1,(G.time-d.at)/1.3);
      ctx.globalAlpha=.25+.5*k;
      if(!G.fx?.radial(ctx,C.x,C.y,60+k*460,[[0,P.handEdge],[.4,P.gem],[1,'transparent']])){
        const g=ctx.createRadialGradient(C.x,C.y,4,C.x,C.y,60+k*460);g.addColorStop(0,P.handEdge);g.addColorStop(.4,P.gem);g.addColorStop(1,'transparent');ctx.fillStyle=g;ctx.fillRect(0,0,780,G.H);
      }ctx.globalAlpha=1;
    }
    // ── Score: A harmonic minor, 8 bars of a descending ground bass
    // (Am E/G# C G | F Dm E E), a clockwork passacaglia. A tick-tock woodblock
    // runs through everything. Phase 1 is pad, bass, tick and a sparse music
    // box; phase 2 adds kick, snare and hats and fills the box out; phase 3
    // brings in a baroque lead. Telegraphs wind the tick up to sixteenths
    // under a riser; haste pushes the tempo; jamming stops the tick dead
    // and leaves bells over a bright C major; frozen time is a muffled pad;
    // midnight strips to a heartbeat and a low tower bell.
    const BASS=[45,44,48,43,41,38,40,40],CHORD=[[57,60,64],[56,59,64],[55,60,64],[55,59,62],[57,60,65],[57,62,65],[56,59,64],[56,59,62,64]];
    const MELODY=[
      [[0,4,76],[4,2,74],[6,2,72],[8,4,71],[12,4,72]],
      [[0,6,71],[6,2,72],[8,4,74],[12,4,76]],
      [[0,4,79],[4,4,76],[8,4,72],[12,4,76]],
      [[0,6,74],[6,2,71],[8,8,67]],
      [[0,2,69],[2,2,72],[4,4,77],[8,4,76],[12,4,74]],
      [[0,4,74],[4,4,77],[8,4,81],[12,4,77]],
      [[0,4,76],[4,2,80],[6,2,81],[8,4,83],[12,4,80]],
      [[0,8,76],[8,2,71],[10,2,74],[12,4,76]]
    ];
    const HUSH=new Set(['stun','frozen']);
    function events(step,phase,mood){
      const bar=step>>4,s=step&15,out=[],ch=CHORD[bar],root=BASS[bar],still=HUSH.has(mood);
      if(s===0)out.push({i:'pad',notes:mood==='stun'?[52,55,60]:ch,vel:mood==='frozen'?1.2:1,bright:mood==='stun'?1:phase>=3?.4:0});
      if(mood==='frozen'){if(s===0&&bar%2===0)out.push({i:'bell',note:ch[2]+12,vel:.7});return out;}
      // The escapement never stops, except when the clock is jammed.
      const wind=mood==='wind'||mood==='rewind'||mood==='haste',tick=wind?1:mood==='midnight'?4:phase>=2?2:4;
      if(!still&&s%tick===0)out.push({i:'tick',hi:(s/tick)%2===0,vel:s%4===0?1:.6});
      if(mood==='intro')return out;
      if(mood==='stun'){
        if(s%4===0)out.push({i:'bell',note:[72,76,79,84][(s>>2)%4],vel:1});
        if(s===0)out.push({i:'bass',note:48,vel:.6,len:3});
        return out;
      }
      // Midnight: a heartbeat and a tower bell on every half bar.
      if(mood==='midnight'){
        if(s===0||s===3||s===8||s===11)out.push({i:'kick',vel:s%8===0?1:.6});
        if(s===0||s===8)out.push({i:'bell',note:root,vel:1.3});
        if(s%8===0)out.push({i:'bass',note:root,vel:.9,len:1.8});
        return out;
      }
      // Drums from phase two.
      if(phase>=2){
        const kick=phase===2?[0,8,10]:[0,6,8,11];if(kick.includes(s))out.push({i:'kick',vel:s===0?1:.75});
        if(s===4||s===12)out.push({i:'snare',vel:1});
        if(phase>=3&&s===15)out.push({i:'snare',vel:.3});
        if(s%4===2)out.push({i:'hat',vel:.7,open:phase>=3&&s===14});
      }
      // Ground bass: the root walking down, in quarters, then eighths.
      const bass=phase===1?[0,8]:phase===2?[0,4,8,12]:[0,2,4,6,8,10,12,14];
      if(bass.includes(s))out.push({i:'bass',note:phase>=3&&s%4===2?root+12:root,vel:s===0?1:.75,len:phase===1?1.8:.45});
      // Music box: a broken chord, sparse in phase one, running from phase two.
      const tones=[...ch,ch[0]+12],pat=[0,1,2,3,2,1,2,3],every=phase===1||mood==='rewind'?4:phase===2||mood==='wind'?2:1;
      if(s%every===0)out.push({i:'box',note:tones[pat[Math.floor(s/every)%8]]+12,vel:s%4===0?1:.65,pan:s%4<2?-.35:.35});
      if(phase>=3)for(const [at,len,note] of MELODY[bar])if(at===s)out.push({i:'lead',note,len,vel:1});
      return out;
    }
    const score={
      bars:8,events,
      bpm:(phase,mood)=>(phase>=3?132:phase>=2?126:120)*(mood==='haste'?1.2:1),
      mix:[
        {pad:.9,bass:.75,drums:.7,arp:.7,lead:0,bell:.6},
        {pad:.8,bass:.85,drums:.85,arp:.65,lead:0,bell:.6},
        {pad:.7,bass:.95,drums:.95,arp:.55,lead:.8,bell:.7}
      ],
      moods:{intro:{pad:1,drums:.7,bass:0,arp:0,lead:0},frozen:{pad:1,bell:.7,bass:0,drums:0,arp:0,lead:0},stun:{pad:1,bell:1,bass:.5,lead:0,arp:0},
        midnight:{pad:.8,bell:1,drums:1,bass:.9,arp:0,lead:0},rewind:{arp:-.6,lead:-.5}},
      filter:{frozen:480,rewind:1400,intro:1600},riser:['wind','rewind','midnight'],
      stab:[60,64,67,72],stinger:[45,52,57,59,60,64]
    };
    // What the score reads each tick.
    function music(){
      if(whirl>0)return {mood:'intro'};
      if(stunned())return {mood:'stun'};
      if(refill)return {mood:'wind'};
      if(frozen)return {mood:'frozen'};
      if(is('midnight'))return {mood:'midnight'};
      if(is('rewind'))return {mood:'rewind'};
      if(is('haste')&&G.time>=move.live)return {mood:'haste'};
      if(move)return {mood:'wind'};
      return {mood:'fight'};
    }
    const def={
      id:'clock',name:'时之君主',score,music,title:'CHRONO SOVEREIGN',tagline:'',
      kicker:'WARNING · CHRONO',note:'',rageNote:'时序崩坏',hitLabel:'时核命中',roar:'bell',
      seal:['TIME SHATTERED','时之君主 · 停摆',''],
      phaseNames:['上弦','走时','午夜'],abilities,
      // Phase one opens with a target move; the last phase always adds 午夜.
      roll(pool){
        const list=pool.filter(id=>id!=='midnight'),open=list.find(id=>OPENERS.includes(id)),rest=list.filter(id=>id!==open);
        return [[open],rest.slice(0,2),['midnight',rest[2]]];
      },
      hp:phase=>Math.ceil(G.damage()*(22+6*phase)),
      mods:m=>({hp:1+.15*(m.phase-1),barriers:m.phase===api.phases()?6:3,decorate}),
      palette:()=>{const P=R();return {main:P.brass,hot:P.weak,light:P.handEdge,text:P.text};},
      focus:()=>C,moving:()=>true,
      status:()=>stunned()?{text:'停摆',state:'exposed'}:refill?{text:'上弦中',state:'shielded'}:frozen?{text:'时间静止',state:'shielded'}:
        is('midnight')?{text:`午夜 ${move.hits}/${move.need}`,state:'shielded'}:move?{text:abilities[move.id].name,state:'shielded'}:{text:`发条 ${Math.ceil(spring())}%`,state:'shielded'},
      init:data=>{data.spring=100;},
      validate:data=>data.spring===undefined||typeof data.spring==='number'&&data.spring>=0&&data.spring<=100,
      hydrate(m){for(const b of numerals())tag(b);m.data.spring??=100;arm();wound=1;buildGears();},
      intro(){arm(G.time+2.6);},
      shifted(){arm();wound=1;history=[];buildGears();whirl=G.reduced?0:1.1;shatter(40,520);G.sound('timestop');},
      charging(t){spin=1+t*14;const P=R();if(Math.random()<.4){const a=Math.random()*Math.PI*2;G.burst(C.x+Math.cos(a)*120,C.y+Math.sin(a)*120,Math.random()<.5?P.brass:P.gem,4,1.6);}},
      exploded(){spin=1;shatter(70,760);gears=[];},
      pending:()=>!!frozen,
      calm:clearFx,reset(){clearFx();spin=1;pt=0;gearTurn=0;wound=1;whirl=0;history=[];gears=[];minute=-Math.PI/2;turn=0;hourIdx=2;hour=-Math.PI/2+2*Math.PI/6;},
      contact,destroyed,pre,post,drawBack,drawField,drawFront,
      // Tests and the admin panel can open a move directly.
      start:id=>begin(id),gears:()=>gears,
      debug:()=>({minute,hour,hourIdx,spring:spring(),refill:!!refill,gears:gears.map(g=>g.jammed),move:move?.id||null,stunned:stunned(),frozen:frozen?.list.length??null,wound,numerals:numerals().length,lit:litBrick?.hourIndex??null,
        key:is('stop')?{x:move.x,y:move.y}:null,bell:is('toll')?bellPos():null,bob:is('pendulum')&&G.time>=move.live?bobPos():null,ghosts:is('rewind')?move.ghosts.length:0,rung:move?.rung??0,hits:move?.hits??0})
    };
    return def;
  });
})();
