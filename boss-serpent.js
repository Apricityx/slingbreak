(() => {
  'use strict';
  // 星渊巨蟒: a colossal star serpent. Every scale on its body is a brick that
  // chips the boss when broken; enough broken scales crack its guard and stun
  // it. The armoured head only takes heavy damage when the serpent commits:
  // interrupt a coil or a rend, shoot into its maw while it devours, yank it
  // out of a star gate, sever the thread between twin heads or strike both at
  // once, break its eclipse. Each answer knocks it down for a crit window.
  (window.SlingBosses||=[]).push(api=>{
    const {G,Composite,Body,has,rage}=api,fight=api.fight;
    const HEAD_R=28,SPACING=42,SEGS=[32,36,42,48],MAX_SEGS=64,CRACKS=5;
    const fallback={body:'#1f5f6b',bodyLight:'#58b3bf',belly:'#bfe9ee',head:'#16464f',eye:'#ffd166',glow:'#3ec8d6',star:'#e0a92e',spark:'#f2c14e',portal:'#0b2a30',text:'#12606b',weak:'#e2493a',twin:'#d9a53a',sky:'#8fb7c0',maw:'#3a0f1a',dark:'#06141c',horn:'#e8d9a8',nebula:'#7fc4d0',nebula2:'#c9a2e0',tether:'#e0a92e'};
    const R=()=>window.SlingTheme?.canvas.serpent||fallback;
    const abilities={
      coil:{name:'盘击',desc:'盘身蓄力后贯穿全场，蓄力时击中蛇首可打断并击晕'},
      dive:{name:'潜渊',desc:'潜入星门，从别处破空而出；射中出口星门可将其强行拽出'},
      twin:{name:'双生',desc:'第四相：撕裂为两条巨蟒，斩断星丝或同时命中双首可强制合体倒地'},
      devour:{name:'吞星',desc:'张口吞噬砖块，向口中连射可令其噎住'},
      eclipse:{name:'星蚀',desc:'吞没星光，场地陷入黑暗，瞄准线缩短'},
      comet:{name:'彗尾',desc:'蛇尾洒下星砖，击碎后星火追击蛇首'}
    };
    // Four phases. Phase one always opens with a real attack; phases one to
    // three share the other five abilities without repeats; phase four is the
    // twin split plus one of them again.
    function roll(pool){
      const first=api.shuffle(['coil','dive','devour'])[0],rest=api.shuffle(pool.filter(id=>id!==first&&id!=='twin'));
      const extra=api.shuffle(pool.filter(id=>id!=='twin'))[0];
      return [[first],rest.slice(0,2),rest.slice(2,4),['twin',extra]];
    }
    const hex=(c,a)=>{const n=parseInt(c.slice(1),16);return `rgba(${n>>16&255},${n>>8&255},${n&255},${a})`;};
    const ease=u=>u*u*(3-2*u);
    const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
    const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
    function glow(ctx,x,y,r,c,a=1){
      if(!(r>0)||a<=0)return;
      if(G.fx?.glow(ctx,x,y,r,c,a))return;
      const g=ctx.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,hex(c,a));g.addColorStop(.35,hex(c,a*.45));g.addColorStop(1,hex(c,0));
      ctx.fillStyle=g;ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill();
    }

    let snakes=[],portals=[],sparks=[],debris=[],fx=[],ghosts=[],dust=[];
    let split=null,eclipse=null,dim=false,owner=null,fresh=false,from=null,popAt=0,shown='';
    let coilAt=0,diveAt=0,twinAt=0,devourAt=0,eclipseAt=0,cometAt=0,nextMove=0;
    const hints=new Set(),hint=(id,text)=>{if(hints.has(id))return;hints.add(id);G.toast?.(text);};
    const scaleHp=()=>Math.max(G.baseHp(),Math.ceil(G.damage()*2));
    // The last few scales are armoured so the tail can't be shaved off in one volley.
    const TAIL=5,tailHp=(k,n)=>{const d=n-1-k;return Math.ceil(scaleHp()*(d<TAIL?1+1.5*(TAIL-d)/TAIL:1));};
    const armour=()=>1+.5*(fight()?.data.regrowth||0);
    const hardenedHp=(k,n)=>Math.ceil(tailHp(k,n)*armour());
    const speed=()=>(rage()?150:110)*(eclipse?1.25:1);
    const gateLife=sn=>Math.max(8,(sn.max+2)*SPACING/speed()+8);
    // The boss bar shows the serpent's stance; refresh it whenever the stance changes.
    const sync=()=>{const s=status(),k=s.text+s.state;if(k!==shown){shown=k;G.ui();}};
    // ── Screen effects: soft flares, shock rings and light streaks.
    const flare=(x,y,c,r=160,life=.5)=>{if(!G.reduced)fx.push({k:'flare',x,y,c,r,born:G.time,life});};
    const wave=(x,y,c,r=260,life=.6,w=10)=>{if(!G.reduced)fx.push({k:'wave',x,y,c,r,w,born:G.time,life});};
    const streaks=(x,y,c,n=12,len=240,life=.45)=>{if(!G.reduced)fx.push({k:'streak',x,y,c,len,life,born:G.time,rays:Array.from({length:n},()=>({a:Math.random()*Math.PI*2,s:.5+Math.random()*.7}))});};
    function impact(x,y,{c,r=160,shake=8,freeze=50,sound='boom'}={}){
      const P=R();c||=P.glow;flare(x,y,c,r);wave(x,y,c,r*1.6);G.ring(x,y,c,r*.8);G.burst(x,y,c,18,1.8);
      G.shake=Math.min(22,Math.max(G.shake,shake));api.freeze(freeze);if(sound)G.sound(sound,1,x);
    }
    // Shockwaves shove live arrows away; the serpent crushes bricks without chipping itself (depth 70).
    function push(x,y,r,force){
      for(const a of G.arrows){const p=a.body.position,dx=p.x-x,dy=p.y-y,d=Math.hypot(dx,dy);if(d>0&&d<r){const k=force*(1-d/r);Body.setVelocity(a.body,{x:a.body.velocity.x+dx/d*k,y:a.body.velocity.y+dy/d*k});}}
    }
    function crush(x,y,r){const hit=G.bricks.filter(b=>!b.orbit&&Math.hypot(b.x-x,b.y-y)<r);hit.forEach(b=>G.hit(b,1e9,70));return hit.length;}

    // ── Snakes. Each scale is a brick riding the head's trail; offsets glide
    // so gaps close smoothly when a scale breaks or twins trade segments.
    const seg=(hp,k)=>({hp,max:Math.max(hp,scaleHp()),b:null,off:(k+1)*SPACING,x:0,y:0,a:0,glide:0,gx:0,gy:0});
    function make(saved,i){
      return {twin:i>0,max:saved.max,segs:saved.segs.map(seg),head:{x:390,y:470,a:Math.PI/2},vel:0,spin:0,goal:null,trail:[],eyes:[],
        mode:'swim',t0:G.time,regen:null,regenAt:G.time+4,passage:false,retreat:!!saved.retreat,retreatLeft:saved.retreatLeft??2,flinch:0,cracks:0,crackReady:false,guard:0,jaw:0,scale:1,boost:0,fed:0,mouth:0,hitAt:-9,sunk:0,exit:null,to:null,low:false,ghostAt:0};
    }
    // A resting pose: the body lies on a loop around the board centre.
    function layOut(sn,side=0){
      const cx=side?390+side*170:390,rx=side?110:250,ry=230,dir=side>0?-1:1,len=(sn.max+3)*SPACING,pts=[];
      let t=Math.random()*Math.PI*2,acc=0,prev=null;
      while(acc<len){const p={x:cx+rx*Math.cos(t),y:470+ry*Math.sin(t)};if(prev)acc+=dist(p,prev);pts.push(p);prev=p;t+=dir*.03;}
      sn.trail=pts;const h=pts.pop(),q=pts.at(-1);
      sn.head={x:h.x,y:h.y,a:Math.atan2(h.y-q.y,h.x-q.x)};sn.mode='swim';sn.vel=speed();sn.eyes=[];sn.goal=null;
      sn.segs.forEach((s,k)=>{s.off=(k+1)*SPACING;s.glide=0;});
    }
    function show(s){const b=G.makeBrick({x:s.x,y:s.y,w:40,h:40,hp:s.hp,max:s.max,type:'scale',frozen:false});b.orbit=b.skin=true;s.b=b;G.predictionVersion++;}
    function hide(s){if(!s.b)return;s.hp=s.b.hp;Composite.remove(G.engine.world,s.b.body);G.bricks=G.bricks.filter(t=>t!==s.b);s.b=null;G.predictionVersion++;}
    const headOn=sn=>!['lurk','under','sink'].includes(sn.mode);
    const hidden=(sn,s)=>sn.mode==='lurk'||sn.mode==='under'||sn.mode==='sink'&&s.off<sn.sunk;
    // Walk the trail back from the head and set each scale at its arc-length offset.
    function place(sn,dt){
      sn.segs=sn.segs.filter(s=>!s.b||G.bricks.includes(s.b));
      sn.segs.forEach((s,k)=>{s.off+=((k+1)*SPACING-s.off)*Math.min(1,dt*5);s.glide=Math.max(0,s.glide-dt*2);});
      const T=sn.trail;let acc=0,i=T.length-1,px=sn.head.x,py=sn.head.y;
      for(const s of sn.segs){
        let found=false;
        while(i>=0){
          const q=T[i],d=Math.hypot(q.x-px,q.y-py);
          if(acc+d>=s.off&&d>0){const u=(s.off-acc)/d,x=px+(q.x-px)*u,y=py+(q.y-py)*u,k=ease(s.glide);s.x=x+(s.gx-x)*k;s.y=y+(s.gy-y)*k;s.a=Math.atan2(py-q.y,px-q.x);found=true;break;}
          acc+=d;px=q.x;py=q.y;i--;
        }
        const visible=found&&!hidden(sn,s);
        if(visible&&!s.b)show(s);else if(!visible&&s.b)hide(s);
        if(s.b&&(s.b.x!==s.x||s.b.y!==s.y)){s.b.x=s.x;s.b.y=s.y;Body.setPosition(s.b.body,{x:s.x,y:s.y});}
      }
    }
    function record(sn){
      const last=sn.trail.at(-1);
      if(!last||Math.hypot(sn.head.x-last.x,sn.head.y-last.y)>=6){sn.trail.push({x:sn.head.x,y:sn.head.y});const cap=Math.ceil((MAX_SEGS+3)*SPACING/6)+30;if(sn.trail.length>cap)sn.trail.splice(0,sn.trail.length-cap);}
    }
    // ── Motion: the head steers toward roaming goals with a capped turn rate,
    // so it swims in living curves instead of on rails.
    const BOUND={x0:70,x1:710,y0:150,y1:840};
    function steer(sn,to,dt,turn,v){
      const want=Math.atan2(to.y-sn.head.y,to.x-sn.head.x),d=wrap(want-sn.head.a);
      sn.head.a+=Math.max(-turn*dt,Math.min(turn*dt,d));
      if(!G.reduced)sn.head.a+=Math.sin(G.time*3+(sn.twin?2:0))*.5*dt;
      sn.vel+=(v-sn.vel)*Math.min(1,dt*3);
      sn.head.x+=Math.cos(sn.head.a)*sn.vel*dt;sn.head.y+=Math.sin(sn.head.a)*sn.vel*dt;
    }
    function pickGoal(sn){
      sn.low=Math.random()<(rage()?.35:.2);
      if(sn.low)G.sound('hiss',1,sn.head.x);
      return {x:110+Math.random()*560,y:sn.low?700+Math.random()*120:190+Math.random()*460};
    }
    function swim(sn,dt,turn=2.4,mult=1){
      const lead=snakes[0];
      if(sn.twin&&split?.apart&&lead.mode==='swim'&&lead.goal)sn.goal={x:780-lead.goal.x,y:lead.goal.y};
      else if(!sn.goal||dist(sn.head,sn.goal)<60)sn.goal=pickGoal(sn);
      steer(sn,sn.goal,dt,turn,speed()*mult*(1+sn.boost));
      sn.boost=Math.max(0,sn.boost-dt*1.2);
    }
    function clamp(sn){
      const h=sn.head;
      if(h.x<BOUND.x0||h.x>BOUND.x1||h.y<BOUND.y0||h.y>BOUND.y1){
        h.x=Math.max(BOUND.x0,Math.min(BOUND.x1,h.x));h.y=Math.max(BOUND.y0,Math.min(BOUND.y1,h.y));
        if(sn.mode==='swim'||sn.mode==='recover')sn.goal=pickGoal(sn);
      }
    }
    function setMode(sn,mode){sn.mode=mode;sn.t0=G.time;sync();}
    function move(sn,dt){
      const t=G.time-sn.t0;let jaw=sn.low?.25:0;
      sn.flinch=Math.max(0,sn.flinch-dt*3);sn.scale+=(1-sn.scale)*Math.min(1,dt*6);
      switch(sn.mode){
        case 'emerge':steer(sn,{x:390+Math.cos(G.time*1.4)*160,y:520},dt,1.6,260);jaw=.5;if(t>=sn.dur){setMode(sn,'swim');sn.goal=null;}break;
        case 'swim':swim(sn,dt);break;
        case 'recover':swim(sn,dt,2.4,.4+.6*Math.min(1,t/.9));if(t>=.9)setMode(sn,'swim');break;
        case 'rise':swim(sn,dt,2.4,1.3);jaw=.8*(1-t/.6);if(t>=.6)setMode(sn,'swim');break;
        case 'stun':
          sn.vel*=Math.max(0,1-dt*5);sn.head.x+=Math.cos(sn.head.a)*sn.vel*dt;sn.head.y+=Math.sin(sn.head.a)*sn.vel*dt;
          if(!G.reduced)sn.head.a+=Math.sin(G.time*7)*.4*dt;jaw=.35;
          if(t>=sn.dur){if(sn.retreat)dive(sn);else{setMode(sn,'recover');sn.guard=G.time+2.5;sn.goal=null;}}
          break;
        case 'coil':
          sn.head.a+=5.2*dt;sn.vel+=(150-sn.vel)*Math.min(1,dt*4);
          sn.head.x+=Math.cos(sn.head.a)*sn.vel*dt;sn.head.y+=Math.sin(sn.head.a)*sn.vel*dt;jaw=.3+.4*Math.min(1,t/sn.dur);
          if(t>=sn.dur)lunge(sn);
          break;
        case 'lunge':{
          const dx=sn.to.x-sn.head.x,dy=sn.to.y-sn.head.y,d=Math.hypot(dx,dy),step=Math.min(d,900*dt);
          sn.head.a=Math.atan2(dy,dx);sn.head.x+=dx/(d||1)*step;sn.head.y+=dy/(d||1)*step;sn.vel=900;jaw=1;
          if(crush(sn.head.x,sn.head.y,HEAD_R+26))G.shake=Math.max(G.shake,5);
          push(sn.head.x,sn.head.y,90,6);
          if(G.time>=sn.ghostAt){sn.ghostAt=G.time+.035;if(!G.reduced)ghosts.push({x:sn.head.x,y:sn.head.y,a:sn.head.a,born:G.time,twin:sn.twin});}
          if(d<4||t>1.2)slam(sn);
          break;
        }
        case 'sink':
        {const v=sn.retreat?900:speed()*(sn.passage?3.2:1.6);
          sn.head.x+=Math.cos(sn.head.a)*v*dt;sn.head.y+=Math.sin(sn.head.a)*v*dt;sn.sunk+=v*dt;
          if(sn.sunk>(sn.segs.length+1)*SPACING)submerge(sn);}
          break;
        case 'under':if(G.time>=sn.exit.open)rise(sn,false);break;
        case 'rear':steer(sn,sn.to,dt,4,260);jaw=.4;if(dist(sn.head,sn.to)<30||t>1.2){setMode(sn,'maw');sn.bite=G.time;}break;
        case 'maw':{
          sn.vel=0;sn.head.a+=wrap(Math.PI/2-sn.head.a)*Math.min(1,dt*5);
          if(!G.reduced)sn.head.y+=Math.sin(G.time*6)*.4;jaw=Math.min(1,t/.4);inhale(sn,t);
          break;
        }
        case 'rend':sn.head.a+=6.5*dt;sn.vel+=(120-sn.vel)*Math.min(1,dt*4);sn.head.x+=Math.cos(sn.head.a)*sn.vel*dt;sn.head.y+=Math.sin(sn.head.a)*sn.vel*dt;jaw=.6;if(t>=1.1)tear(sn);break;
        case 'merge':{const o=snakes.find(x=>x!==sn)||sn,mid={x:(sn.head.x+o.head.x)/2,y:(sn.head.y+o.head.y)/2};steer(sn,mid,dt,6,330);jaw=.7;break;}
      }
      sn.jaw+=(jaw-sn.jaw)*Math.min(1,dt*10);
      // While sinking the trail keeps growing, so the body slides forward into the gate.
      if(sn.mode!=='under'&&sn.mode!=='lurk'){if(sn.mode!=='sink'){clamp(sn);trackEyes(sn);}record(sn);}
    }
    // Eye positions in world space, kept briefly for the glowing eye trails.
    function eyePoints(sn){
      const h=sn.head,s=sn.scale,out=[];
      for(const side of [-1,1]){const a=h.a+side*sn.jaw*.45,ex=14*s,ey=side*12*s;out.push({x:h.x+Math.cos(a)*ex-Math.sin(a)*ey,y:h.y+Math.sin(a)*ex+Math.cos(a)*ey});}
      return out;
    }
    function trackEyes(sn){if(G.reduced)return;sn.eyes.push(eyePoints(sn));if(sn.eyes.length>10)sn.eyes.shift();}
    // ── 盘击: coil and telegraph a lane through the densest bricks, then lunge.
    function coil(sn){
      let best=null,score=-1;
      for(let i=0;i<14;i++){
        const x=110+Math.random()*560,y=190+Math.random()*560;if(Math.hypot(x-sn.head.x,y-sn.head.y)<300)continue;
        const n=G.bricks.filter(b=>!b.orbit&&segDist(b,sn.head,{x,y})<60).length;if(n>score){score=n;best={x,y};}
      }
      if(!best)return false;
      sn.to=best;sn.dur=rage()?.9:1.2;setMode(sn,'coil');G.sound('hiss',1,sn.head.x);
      hint('coil','蓄力时击中蛇首可打断');return true;
    }
    function segDist(p,a,b){const ex=b.x-a.x,ey=b.y-a.y,u=Math.max(0,Math.min(1,((p.x-a.x)*ex+(p.y-a.y)*ey)/(ex*ex+ey*ey||1)));return Math.hypot(p.x-a.x-ex*u,p.y-a.y-ey*u);}
    function lunge(sn){setMode(sn,'lunge');G.sound('meteor',1,sn.head.x);G.shake=Math.max(G.shake,6);streaks(sn.head.x,sn.head.y,R().weak,8,140,.3);}
    function slam(sn){
      const {x,y}=sn.head;setMode(sn,'recover');sn.vel=0;
      const n=crush(x,y,120);push(x,y,260,14);
      impact(x,y,{c:R().weak,r:170,shake:14,freeze:90});streaks(x,y,R().star,14,260);
    }
    // ── 潜渊: sink into a gate, telegraph the exit, then erupt; shooting the exit yanks it out stunned.
    function dive(sn){
      sn.sunk=0;setMode(sn,'sink');
      portals.push({x:sn.head.x,y:sn.head.y,born:G.time,end:G.time+gateLife(sn),exit:false,sn});
      G.sound('serpent');wave(sn.head.x,sn.head.y,R().glow,200);flare(sn.head.x,sn.head.y,R().portal,120);
    }
    function submerge(sn){
      const low=!sn.passage&&Math.random()<(rage()?.5:.3),x=sn.passage?390+(Math.random()-.5)*300:120+Math.random()*540,y=sn.passage?300+Math.random()*200:low?640+Math.random()*140:220+Math.random()*360;
      const open=G.time+(sn.retreat?.6:sn.passage?.9:rage()?1.1:1.4);
      sn.exit={x,y,open};portals.push({x,y,born:G.time,open,end:open+gateLife(sn),exit:true,sn});setMode(sn,'under');
      G.sound('hiss',1,x);if(!sn.passage)hint('dive','射中出口星门可将其拽出');
    }
    function rise(sn,yanked){
      const P=R(),{x,y}=sn.exit;
      // Every return replaces the whole tail, including damaged surviving scales.
      // The new scales become visible one by one as the head's trail leaves the gate.
      fight().data.regrowth=(fight().data.regrowth||0)+1;
      sn.segs.forEach(hide);sn.segs=Array.from({length:sn.max},(_,k)=>seg(hardenedHp(k,sn.max),k));
      sn.regen=null;sn.regenAt=G.time+4;sn.retreat=false;sn.cracks=0;sn.crackReady=false;
      sn.head={x,y,a:yanked?Math.atan2(470-y,390-x):Math.atan2(470-y,390-x)+(Math.random()-.5)*1.4};
      sn.trail=[{x,y}];sn.eyes=[];sn.scale=yanked?1.4:2;sn.vel=speed()*1.5;sn.goal=null;
      if(yanked){
        stun(sn,3,'拽出');impact(x,y,{c:P.star,r:150,shake:12,freeze:110,sound:'shatter'});
      }else if(sn.passage){
        sn.passage=false;setMode(sn,'rise');push(x,y,300,16);
        impact(x,y,{c:P.glow,r:240,shake:14,freeze:60});flare(x,y,P.star,160);streaks(x,y,P.belly,18,320);G.sound('serpent');
      }else{
        setMode(sn,'rise');const n=crush(x,y,120);push(x,y,300,16);
        impact(x,y,{c:P.glow,r:220,shake:16,freeze:90});flare(x,y,P.star,140);streaks(x,y,P.belly,16,300);G.sound('serpent');
      }
    }
    // ── Stun: the crit window every answer leads to.
    // A gate stays open only while its snake is still passing through it.
    function inGate(p){
      const sn=p.sn;if(!sn||!snakes.includes(sn))return false;
      if(!p.exit)return sn.mode==='sink';
      if(['under','lurk'].includes(sn.mode))return true;
      const tail=tipOf(sn),far=tail?Math.hypot(tail.x-p.x,tail.y-p.y):Math.hypot(sn.head.x-p.x,sn.head.y-p.y);
      return sn.segs.some(s=>!s.b)&&far<(sn.segs.length+2)*SPACING||far<70;
    }
    function stun(sn,dur,label){
      const P=R();if(sn.mode==='rend')twinAt=G.time+5;sn.dur=dur;sn.vel=Math.min(sn.vel,120);setMode(sn,'stun');sn.cracks=0;sn.crackReady=false;sn.mouth=0;
      if(label)G.float(sn.head.x,sn.head.y-58,label,P.weak,22);G.sound('eyehit',1,sn.head.x);G.sound('shatter',1,sn.head.x);
      flare(sn.head.x,sn.head.y,P.weak,150);hint('stun','倒地时蛇首五倍伤害');
    }
    function exposure(sn){
      switch(sn.mode){
        case 'stun':return {mult:5,tag:'破绽'};
        case 'coil':case 'rend':return {mult:4,tag:'打断',stun:[2.6,'打断']};
        case 'lunge':return {mult:4,tag:'迎击',stun:[2.2,'迎击']};
        case 'maw':return {mult:3,tag:'噬口'};
        case 'rise':case 'emerge':return {mult:2.5,tag:'破甲'};
        default:return {mult:eclipse?2:1.5,tag:''};
      }
    }
    function strikeHead(a,x,y,sn){
      if(!api.canStrike(a))return;
      const P=R(),ex=exposure(sn),big=ex.mult>=3;
      api.strike(a,x,y,ex.mult);sn.flinch=1;
      if(big){
        G.burst(x,y,P.weak,20,2);flare(x,y,P.weak,120,.35);G.ring(x,y,P.star,110);streaks(x,y,P.star,8,150,.3);
        G.shake=Math.min(16,G.shake+7);api.freeze(ex.mult>=5?90:70);G.sound('eyehit',1,x);
      }else{G.burst(x,y,P.horn,8,1);G.ring(x,y,P.horn,50);G.shake=Math.min(10,G.shake+2);G.sound('clang',1,x);}
      if(ex.stun)stun(sn,...ex.stun);
      if(sn.mode==='maw'){sn.mouth++;if(sn.mouth>=(rage()?4:3))choke(sn);}
      if(eclipse&&++eclipse.hits>=2)breakEclipse(x,y);
      if(split?.apart&&!split.merging){sn.hitAt=G.time;const o=snakes.find(s=>s!==sn);if(o&&G.time-o.hitAt<1)resonate();}
    }
    // Runs inside G.guideArrows for live and preview arrows alike, so the aim
    // line bends into the maw and off the head exactly like the real arrow.
    function contact(a,live){
      const p=a.body.position;
      if(live&&a.previousPosition&&split?.apart&&!split.cut&&snakes.length===2&&snakes.every(headOn)&&(crosses(a.previousPosition,p,snakes[0].head,snakes[1].head)||segDist(p,snakes[0].head,snakes[1].head)<8&&dist(p,snakes[0].head)>HEAD_R&&dist(p,snakes[1].head)>HEAD_R))cutThread(p);
      for(const sn of snakes){
        if(live&&sn.mode==='under'&&!sn.passage&&Math.hypot(p.x-sn.exit.x,p.y-sn.exit.y)<52)rise(sn,true);
        if(!headOn(sn))continue;
        if(sn.mode==='maw')suck(a,sn);
        const hit=api.bounceCircle(a,sn.head.x,sn.head.y,(HEAD_R+3)*Math.min(1.5,sn.scale));
        if(hit&&live){a.trail=[];strikeHead(a,hit.x,hit.y,sn);}
        if(hit)break;
      }
    }
    function crosses(a,b,c,d){
      const o=(p,q,r)=>(q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x);
      return o(a,b,c)*o(a,b,d)<0&&o(c,d,a)*o(c,d,b)<0;
    }
    const mouthOf=sn=>({x:sn.head.x+Math.cos(sn.head.a)*34,y:sn.head.y+Math.sin(sn.head.a)*34});
    // ── 吞星: rear up, open the maw and inhale; arrows curve in and rattle inside.
    function suck(a,sn){
      const m=mouthOf(sn),p=a.body.position,dx=m.x-p.x,dy=m.y-p.y,d=Math.hypot(dx,dy);
      if(d>360||d<1)return;const k=.55*(1-d/360)*Math.min(1,(G.time-sn.t0)/.4);
      Body.setVelocity(a.body,{x:a.body.velocity.x+dx/d*k,y:a.body.velocity.y+dy/d*k});
    }
    function devour(sn){
      sn.to={x:250+Math.random()*280,y:240+Math.random()*80};sn.fed=0;sn.mouth=0;sn.biteAt=0;setMode(sn,'rear');
      G.sound('devour');api.banner('DEVOUR','吞星','向口中连射','minor');return true;
    }
    function inhale(sn,t){
      if(t>=(rage()?4:3.4)){gulp(sn);return;}
      if(t<.5||G.time<sn.biteAt)return;sn.biteAt=G.time+.3;
      const m=mouthOf(sn),b=G.bricks.filter(b=>!b.orbit&&Math.hypot(b.x-m.x,b.y-m.y)<300).sort((p,q)=>Math.hypot(p.x-m.x,p.y-m.y)-Math.hypot(q.x-m.x,q.y-m.y))[0];
      if(!b)return;
      api.removeBrick(b);debris.push({x:b.x,y:b.y,w:b.w,h:b.h,type:b.type,sn,born:G.time,spin:(Math.random()-.5)*12});
      G.burst(b.x,b.y,G.colors[b.type],6,.8);
    }
    function updateDebris(){
      for(const d of debris){
        if(G.time-d.born<.45)continue;d.done=true;
        if(d.sn.mode==='maw'){d.sn.fed++;if(d.sn.fed%2===0)grow(d.sn,1);const m=mouthOf(d.sn);G.burst(m.x,m.y,G.colors[d.type],5,.6);}
      }
      debris=debris.filter(d=>!d.done);
    }
    function grow(sn,n,hp=null,fx=true){
      const add=Math.min(n,MAX_SEGS-sn.segs.length);if(add<=0)return 0;
      for(let i=0;i<add;i++){const k=sn.segs.length;sn.segs.push(seg(hp??hardenedHp(k,Math.max(sn.max,k+1)),k));}
      sn.max=Math.max(sn.max,sn.segs.length);if(fx)G.burst(sn.head.x,sn.head.y,R().bodyLight,8,1);return add;
    }
    function gulp(sn){
      const P=R(),{x,y}=sn.head;setMode(sn,'recover');sn.vel=0;
      push(x,y,300,12);impact(x,y,{c:P.glow,r:140,shake:10,freeze:60,sound:'gulp'});
    }
    function choke(sn){
      const P=R(),{x,y}=sn.head,fed=sn.fed;sn.fed=0;
      stun(sn,3.2,'噎住');api.hurt(G.damage()*(3+Math.min(8,fed)*.5),x,y);
      impact(x,y,{c:P.star,r:200,shake:16,freeze:120,sound:'shatter'});streaks(x,y,P.star,16,260);
      // Spit what it swallowed back out as star bricks that rain sparks on the head.
      api.openSlots().sort((a,b)=>Math.hypot(a.x-x,a.y-y)-Math.hypot(b.x-x,b.y-y)).slice(0,Math.min(4,Math.ceil(fed/2))).forEach(s=>{
        const hp=G.baseHp(),b=G.makeBrick({x:s.x,y:s.y,w:84,h:44,hp,max:hp,type:'star',frozen:false});api.pop(b,P.star);G.initial++;
      });
      G.predictionVersion++;
    }
    // ── 双生: coil, glow along the spine, then tear in two. Scales alternate
    // between the heads and zip apart; a star thread links the twins.
    function rend(sn){
      setMode(sn,'rend');twinAt=Infinity;G.sound('hiss',1,sn.head.x);
      hint('coil','蓄力时击中蛇首可打断');return true;
    }
    function tear(sn){
      const P=R(),keep=[],give=[];
      sn.segs.forEach((s,i)=>(i%2?give:keep).push(s));
      for(const s of [...keep,...give]){s.gx=s.x;s.gy=s.y;s.glide=1;}
      const o=make({max:1,segs:[]},1);
      o.head={...sn.head};o.trail=sn.trail.map(p=>({...p}));o.segs=give;o.max=Math.max(1,Math.ceil(sn.max/2));
      sn.segs=keep;sn.max=Math.max(1,Math.ceil(sn.max/2));
      sn.regen=null;sn.regenAt=o.regenAt=G.time+3;
      sn.head.a-=.9;o.head.a+=.9;sn.boost=o.boost=1.2;o.mode='swim';setMode(sn,'swim');sn.goal=o.goal=null;sn.eyes=[];
      snakes=[sn,o];split={apart:true,cut:false,merging:0,forced:false,until:G.time+(rage()?11:14)};
      impact(sn.head.x,sn.head.y,{c:P.twin,r:220,shake:16,freeze:130,sound:'shatter'});streaks(sn.head.x,sn.head.y,P.twin,18,320);
      for(const s of [...keep,...give])G.burst(s.x,s.y,P.twin,4,1.2);
      api.flash('shift');G.sound('serpent');G.predictionVersion++;
      api.banner('TWIN','双生','斩断星丝','minor');sync();
    }
    function cutThread(p){
      const P=R();split.cut=true;split.forced=true;split.until=G.time+2.6;
      snakes.forEach((sn,i)=>stun(sn,2.6,i?'':'断丝'));
      api.hurt(G.damage()*4,p.x,p.y);impact(p.x,p.y,{c:P.tether,r:180,shake:14,freeze:120,sound:'shatter'});streaks(p.x,p.y,P.tether,14,280);
    }
    function resonate(){
      const P=R();
      for(const sn of snakes){flare(sn.head.x,sn.head.y,P.star,200);streaks(sn.head.x,sn.head.y,P.star,12,240);}
      const mid={x:(snakes[0].head.x+snakes[1].head.x)/2,y:(snakes[0].head.y+snakes[1].head.y)/2};
      api.hurt(G.damage()*6,mid.x,mid.y);G.float(mid.x,mid.y-30,'共鸣',P.weak,24);G.sound('bell',1,mid.x);G.sound('shatter',1,mid.x);
      G.shake=Math.max(G.shake,16);api.freeze(140);split.forced=true;beginMerge();
    }
    function beginMerge(){
      if(!split||split.merging||snakes.some(sn=>sn.retreat))return;split.merging=G.time;
      for(const sn of snakes)setMode(sn,'merge');
      G.sound('hiss');api.banner(split.forced?'REUNION':'STRANGLE',split.forced?'合体':'绞杀','','minor');
    }
    function finishMerge(){
      const P=R(),[a,b]=snakes,segs=[];
      for(const s of b.segs){s.gx=s.x;s.gy=s.y;s.glide=1;}
      for(let i=0;i<Math.max(a.segs.length,b.segs.length);i++){if(a.segs[i])segs.push(a.segs[i]);if(b.segs[i])segs.push(b.segs[i]);}
      const max=Math.min(MAX_SEGS,a.max+b.max),forced=split.forced;
      a.segs=segs;a.max=max;a.twin=false;a.eyes=[];snakes=[a];split=null;twinAt=G.time+(forced?4.5:3.5);setMode(a,'swim');a.goal=null;
      const {x,y}=a.head;impact(x,y,{c:P.twin,r:240,shake:18,freeze:140,sound:'shatter'});streaks(x,y,P.belly,20,340);api.flash('shift');G.sound('serpent');
      if(forced)stun(a,2.8,'失衡');
      else{push(x,y,320,14);grow(a,a.max-a.segs.length);}
      G.predictionVersion++;sync();
    }
    // ── 星蚀: darkness falls; only arrows, the sling, star bricks and its eyes stay lit.
    function startEclipse(){
      eclipse={start:G.time,end:G.time+(rage()?7:6),hits:0};G.sound('devour');G.sound('hiss');
      api.banner('ECLIPSE','星蚀','击中蛇首两次','minor');
      for(const sn of snakes)flare(sn.head.x,sn.head.y,R().dark,260,.8);sync();
    }
    function breakEclipse(x,y){
      const P=R();eclipse.end=Math.min(eclipse.end,G.time+.35);eclipse.hits=-99;
      G.coreFlash=1.2;streaks(x,y,P.star,24,520,.6);flare(x,y,P.star,320,.7);G.sound('chime',1,x);G.sound('shatter',1,x);
      for(const sn of snakes)if(headOn(sn)&&sn.mode!=='stun')stun(sn,2.2,'驱散');
    }
    const eclipseK=()=>eclipse?Math.min(1,(G.time-eclipse.start)/.8,Math.max(0,(eclipse.end-G.time)/.5)):0;
    const predict=G.predictPath;
    G.predictPath=(x,y,vx,vy,max)=>predict(x,y,vx,vy,dim&&G.boss()?.boss==='serpent'?Math.min(max??720,150):max);
    // ── 彗尾: star bricks near the tail; breaking one launches homing sparks at the head.
    function dropStar(){
      const tails=snakes.map(sn=>[...sn.segs].reverse().find(s=>s.b)).filter(Boolean);
      if(!tails.length||G.bricks.filter(b=>b.type==='star').length>=10)return;
      const t=tails[Math.floor(Math.random()*tails.length)],slot=api.openSlots().sort((a,b)=>Math.hypot(a.x-t.x,a.y-t.y)-Math.hypot(b.x-t.x,b.y-t.y))[0];
      if(!slot||Math.hypot(slot.x-t.x,slot.y-t.y)>150)return;
      const P=R(),hp=G.baseHp(),b=G.makeBrick({x:slot.x,y:slot.y,w:84,h:44,hp,max:hp,type:'star',frozen:false});
      api.pop(b,P.star);G.initial++;G.predictionVersion++;G.burst(slot.x,slot.y,P.spark,8,.9);flare(slot.x,slot.y,P.star,60,.3);
    }
    function updateSparks(dt){
      for(const s of sparks){
        const target=snakes.filter(headOn).map(sn=>sn.head).sort((p,q)=>Math.hypot(p.x-s.x,p.y-s.y)-Math.hypot(q.x-s.x,q.y-s.y))[0];
        if(target){
          const dx=target.x-s.x,dy=target.y-s.y,d=Math.hypot(dx,dy)||1;s.vx+=(dx/d*14-s.vx)*Math.min(1,dt*4);s.vy+=(dy/d*14-s.vy)*Math.min(1,dt*4);
          if(d<HEAD_R+8){s.done=true;const P=R();api.hurt(G.damage()*.9,target.x,target.y);G.burst(target.x,target.y,P.spark,10,1.3);flare(target.x,target.y,P.star,70,.3);G.sound('chime',1,target.x);}
        }
        s.x+=s.vx*dt*60;s.y+=s.vy*dt*60;s.trail.push({x:s.x,y:s.y});if(s.trail.length>12)s.trail.shift();
        if(G.time-s.born>3.5)s.done=true;
      }
      sparks=sparks.filter(s=>!s.done);
    }
    function destroyed(b){
      const P=R();
      if(b.type==='scale'){
        api.hurt(G.damage()*.6,b.x,b.y,{quiet:true});G.burst(b.x,b.y,P.bodyLight,12,1.4);G.burst(b.x,b.y,P.belly,5,.8);flare(b.x,b.y,P.glow,55,.25);G.sound('shard',1,b.x);
        const sn=snakes.find(sn=>sn.segs.some(s=>s.b===b));
        if(sn){
          sn.flinch=Math.max(sn.flinch,.6);if(G.time>=sn.guard&&sn.mode!=='stun'&&++sn.cracks>=CRACKS)sn.crackReady=true;
          sn.segs=sn.segs.filter(s=>!s.b||G.bricks.includes(s.b));
          if(!sn.segs.length&&!sn.retreat&&!sn.passage&&!api.dying())loseTail(sn);
        }
      }
      if(b.type==='star'){
        flare(b.x,b.y,P.star,90,.35);G.ring(b.x,b.y,P.star,80);G.sound('chime',1,b.x);
        for(let i=0;i<3;i++){const a=-Math.PI/2+(i-1)*.9;sparks.push({x:b.x,y:b.y,vx:Math.cos(a)*6,vy:Math.sin(a)*6,born:G.time,trail:[]});}
      }
    }
    // ── 再生: a shortened body regrows from the tail tip, one scale at a time.
    const tipOf=sn=>[...sn.segs].reverse().find(s=>s.b);
    function loseTail(sn){
      sn.retreat=true;sn.regen=null;
      if(split?.merging){split.merging=0;for(const o of snakes)if(o!==sn&&o.mode==='merge'){setMode(o,'swim');o.goal=null;}}
      stun(sn,2,'断尾');
      hint('tail','断尾后蛇首五倍伤害；巨蟒逃入星门后会长出更硬的尾巴');
    }
    function regrow(sn){
      if(sn.retreat)return;
      const P=R(),r=rage();
      if(sn.regen){
        const g=sn.regen;if(!headOn(sn)||G.time<g.next)return;
        const tip=tipOf(sn),add=grow(sn,1,Math.ceil(Math.max(scaleHp()*2,tailHp(sn.segs.length,sn.max))*armour()),false);
        if(tip&&add){G.burst(tip.x,tip.y,P.bodyLight,6,1.1);flare(tip.x,tip.y,P.glow,40,.25);G.sound('regrow',1,tip.x);}
        if(!add||--g.left<=0||sn.segs.length>=sn.max){sn.regen=null;sn.regenAt=G.time+(r?2:3);sync();}
        else g.next=G.time+(r?.14:.2);
        return;
      }
      const missing=sn.max-sn.segs.length;
      if(def.regen===false||missing<=0||G.time<sn.regenAt||!['swim','recover','coil','stun'].includes(sn.mode)||split?.merging||!api.ready())return;
      if(!tipOf(sn)){sn.regenAt=G.time+1;return;}
      sn.regen={left:Math.min(missing,r?10:8),next:G.time+.3};sync();
    }
    // ── Frame hooks.
    function thrash(sn,dt){
      const t=G.time-(api.dying()?.at||G.time);
      sn.head.a+=Math.sin(G.time*17+(sn.twin?1:0))*6*dt;sn.head.x+=Math.cos(sn.head.a)*(60+t*90)*dt;sn.head.y+=Math.sin(sn.head.a)*(60+t*90)*dt;
      sn.jaw+=(1-sn.jaw)*Math.min(1,dt*8);sn.flinch=1;if(headOn(sn)){clamp(sn);record(sn);}
    }
    function pre(dt){
      for(const sn of snakes){if(api.dying())thrash(sn,dt);else move(sn,dt);place(sn,dt);}
      if(!G.reduced&&Math.random()<dt*28){
        const sn=snakes[Math.floor(Math.random()*snakes.length)],s=sn?.segs[Math.floor(Math.random()*sn.segs.length)];
        if(s?.b)dust.push({x:s.x+(Math.random()-.5)*20,y:s.y+(Math.random()-.5)*20,vx:(Math.random()-.5)*14,vy:-8-Math.random()*16,born:G.time,life:.9+Math.random()*.8,r:1+Math.random()*2});
        if(dust.length>90)dust.shift();
      }
      for(const d of dust){d.x+=d.vx*dt;d.y+=d.vy*dt;}
    }
    function post(dt){
      updateSparks(dt);updateDebris();
      for(const p of portals)if(p.end>G.time+.4&&!inGate(p))p.end=G.time+.4;
      portals=portals.filter(p=>G.time<p.end);fx=fx.filter(f=>G.time-f.born<f.life);ghosts=ghosts.filter(g=>G.time-g.born<.35);dust=dust.filter(d=>G.time-d.born<d.life);
      if(eclipse&&G.time>=eclipse.end){eclipse=null;sync();}
      const d=eclipseK()>.5;if(d!==dim){dim=d;G.predictionVersion++;}
      if(api.dying())return;
      // Hidden scales still belong to the tail; only an actually empty body breaks it.
      for(const sn of snakes)if(!sn.segs.length&&!sn.retreat&&headOn(sn))loseTail(sn);
      if(split?.merging&&snakes.length===2&&(dist(snakes[0].head,snakes[1].head)<40||G.time-split.merging>1.6))finishMerge();
      if(split&&!split.merging&&G.time>=split.until&&snakes.every(sn=>['swim','recover','rise'].includes(sn.mode)))beginMerge();
      for(const sn of snakes)regrow(sn);
      for(const sn of snakes)if(sn.crackReady&&['swim','recover','rise','coil'].includes(sn.mode)){sn.crackReady=false;G.burst(sn.head.x,sn.head.y,R().bodyLight,20,2);stun(sn,2.6,'碎甲');}
      if(api.ready())schedule();
      sync();
    }
    // One big move at a time, with a short breather between moves.
    function schedule(){
      const r=rage();
      if(has('comet')&&G.time>=cometAt){cometAt=G.time+(r?1.4:2.2);dropStar();}
      if(has('eclipse')&&!eclipse&&G.time>=eclipseAt&&G.time>=nextMove){eclipseAt=G.time+(r?13:17);nextMove=G.time+1.5;startEclipse();}
      if(G.time<nextMove||split?.merging)return;
      const idle=snakes.filter(sn=>sn.mode==='swim'&&G.time-sn.t0>.8),solo=snakes.length===1&&idle.length===1?idle[0]:null;
      const any=idle[Math.floor(Math.random()*idle.length)];let fired=false;
      if(!fired&&solo&&has('twin')&&G.time>=twinAt)fired=rend(solo);
      if(!fired&&solo&&has('devour')&&G.time>=devourAt){devourAt=G.time+(r?9:12);fired=devour(solo);}
      if(!fired&&solo&&has('dive')&&G.time>=diveAt&&solo.segs.every(s=>s.b)){diveAt=G.time+(r?7:9.5);dive(solo);fired=true;}
      if(!fired&&any&&has('coil')&&G.time>=coilAt){coilAt=G.time+(r?5.5:7.5);fired=coil(any);}
      if(fired)nextMove=G.time+2;
    }
    function arm(t=G.time){for(const sn of snakes){sn.regen=null;sn.regenAt=t+4;}coilAt=t+2.5;diveAt=t+4;devourAt=t+4.5;twinAt=t+.5;eclipseAt=t+6;cometAt=t+1.5;nextMove=t+1;}

    // ── Board and save. Scale hp lives in fight data; scale bricks are rebuilt from it.
    const key=()=>`${fight()?.level}|${fight()?.phase}`;
    function decorate(){
      const m=fight(),max=SEGS[m.phase-1];
      m.data.lengthVersion=2;
      m.data.snakes=[{max,segs:Array.from({length:max},(_,k)=>hardenedHp(k,max))}];
      if(has('comet'))api.shuffle(G.bricks.filter(b=>b.type==='normal')).slice(0,4).forEach(b=>{b.type='star';});
      from=owner;owner=null;fresh=true;
    }
    function hydrate(m){
      // Upgrade existing fights once without restoring destroyed scales or healing damage.
      if(m.data.lengthVersion!==2){
        m.data.snakes.forEach(s=>{s.max=Math.min(MAX_SEGS,s.max*2);s.segs=s.segs.flatMap(h=>[h,h]).slice(0,MAX_SEGS);});
        m.data.lengthVersion=2;
      }
      for(const b of G.bricks.filter(b=>b.type==='scale'))Composite.remove(G.engine.world,b.body);
      G.bricks=G.bricks.filter(b=>b.type!=='scale');
      const prev=fresh&&m.intro&&from===`${m.level}|${m.phase-1}`?snakes.find(headOn):null;
      snakes=m.data.snakes.map(make);split=null;portals=[];
      snakes.forEach((sn,i)=>layOut(sn,snakes.length>1?(i?1:-1):0));
      if(snakes.length===2)split={apart:true,cut:false,merging:0,forced:false,until:G.time+12};
      if(prev&&!G.reduced)passage(snakes[0],prev);
      else if(fresh&&!G.reduced){for(const sn of snakes)sn.mode='lurk';if(m.intro)emergeAll();}
      fresh=false;from=null;owner=key();arm();
      for(const sn of snakes){place(sn,1);if(sn.retreat){sn.dur=sn.retreatLeft;setMode(sn,'stun');}}
    }
    // Phase change: slip into a gate where the old body was, then burst out of another.
    function passage(sn,prev){
      sn.head={...prev.head};sn.trail=prev.trail.map(p=>({...p}));sn.eyes=[];sn.goal=null;sn.passage=true;sn.sunk=0;setMode(sn,'sink');
      portals.push({x:sn.head.x,y:sn.head.y,born:G.time,end:G.time+gateLife(sn),exit:false,sn});
      wave(sn.head.x,sn.head.y,R().glow,220);flare(sn.head.x,sn.head.y,R().portal,140);G.sound('hiss',1,sn.head.x);
    }
    // The serpent pours out of a star gate at the top of the board.
    function emergeAll(){
      const P=R();
      snakes.forEach((sn,i)=>{
        const x=snakes.length>1?(i?560:220):390,y=150;
        sn.head={x,y,a:Math.PI/2+(Math.random()-.5)*.6};sn.trail=[{x,y}];sn.eyes=[];sn.vel=260;sn.scale=1.8;sn.goal=null;
        sn.dur=Math.min(2.6,(sn.segs.length+1)*SPACING/260);setMode(sn,'emerge');
        portals.push({x,y,born:G.time,end:G.time+gateLife(sn),exit:true,open:G.time,sn});
        impact(x,y,{c:P.glow,r:200,shake:12,freeze:60,sound:false});streaks(x,y,P.belly,14,300);
      });
    }
    function persist(m){if(owner===key())m.data.snakes=snakes.map(sn=>({max:sn.max,segs:sn.segs.filter(s=>!s.b||G.bricks.includes(s.b)).map(s=>s.b?s.b.hp:s.hp),retreat:sn.retreat,retreatLeft:sn.retreat&&sn.mode==='stun'?Math.max(0,sn.dur-(G.time-sn.t0)):0}));}
    function focus(){const sn=snakes[0];if(!sn)return {x:390,y:470};return headOn(sn)?sn.head:sn.exit||sn.head;}
    function status(){
      const all=snakes;
      if(all.some(sn=>sn.mode==='stun'))return {text:all.some(sn=>sn.retreat)?'断尾 · 破绽':'倒地 · 破绽',state:'exposed'};
      if(all.some(sn=>sn.retreat))return {text:'遁入星门 · 再生',state:'shielded'};
      if(all.some(sn=>['coil','rend'].includes(sn.mode)))return {text:'蓄力 · 可打断',state:'exposed'};
      if(all.some(sn=>sn.mode==='lunge'))return {text:'贯穿',state:'exposed'};
      if(all.some(sn=>sn.mode==='maw')){const sn=all.find(s=>s.mode==='maw');return {text:`巨口 · ${sn.mouth}/${rage()?4:3}`,state:'exposed'};}
      if(all.length&&all.every(sn=>sn.mode==='under'||sn.mode==='sink'))return {text:'星门 · 射中出口',state:'shielded'};
      if(all.some(sn=>sn.regen))return {text:'再生中',state:'exposed'};
      if(split?.merging)return {text:'合体中',state:'shielded'};
      if(split)return {text:split.cut?'星丝已断':'双生 · 斩断星丝',state:'shielded'};
      if(eclipse)return {text:`星蚀 · ${Math.max(0,eclipse.hits)}/2`,state:'shielded'};
      const cr=Math.max(0,...all.map(sn=>sn.cracks));
      return {text:`鳞甲 ${cr}/${CRACKS}`,state:'shielded'};
    }
    // ── Canvas: backdrop. Drifting nebulae, a starfield, and far below the
    // board a vast shadow of the serpent that never stops circling.
    const jitter=i=>Math.sin(i*127.1)*.5+Math.sin(i*311.7)*.5;
    function drawBack(ctx){
      const P=R(),d=api.dying();if(d?.exploded)return;
      const age=api.introAge(),rise=Number.isFinite(age)?Math.min(1,Math.max(0,age/1.4)):1,t=G.reduced?0:G.time;
      const atmosphere=g=>{
        for(const [i,c] of [[0,P.nebula],[1,P.nebula2],[2,P.nebula]]){
          const x=390+Math.sin(t*.07+i*2.1)*220,y=470+Math.cos(t*.05+i*1.7)*260;
          g.globalAlpha=(.16+(rage()?.06:0))*rise;glow(g,x,y,300+i*40,c,1);
        }
        drawLeviathan(g,P,rise);
      };
      // Only the slow, non-interactive atmosphere is lower-resolution/30 Hz.
      // Heads, armour, targets and all attack telegraphs still paint each frame.
      if(!G.fx?.layer(ctx,`serpent-sky:${P.nebula}:${P.nebula2}:${P.body}:${P.eye}:${P.weak}:${rage()}`,780,G.H,t,atmosphere,.5,30))atmosphere(ctx);
      ctx.fillStyle=P.sky;
      for(let i=0;i<60;i++){
        const x=390+jitter(i)*380,y=480+jitter(i+50)*430,tw=G.reduced?.6:.35+.65*Math.abs(Math.sin(t*1.3+i)),s=i%9===0?3.2:2;
        ctx.globalAlpha=.5*tw*rise*(1-eclipseK()*.8);ctx.fillRect(x-s/2,y-s/2,s,s);
        if(i%9===0&&tw>.9){ctx.globalAlpha=.4*rise;ctx.fillRect(x-6,y-.5,12,1);ctx.fillRect(x-.5,y-6,1,12);}
      }
      ctx.globalAlpha=1;
    }
    function drawLeviathan(ctx,P,rise){
      const t=G.reduced?0:G.time*.18,pts=[];
      for(let i=0;i<46;i++){const u=t-i*.045;pts.push({x:390+Math.sin(u*1.3)*330+Math.sin(u*3.1)*40,y:500+Math.sin(u*2.2+1)*330});}
      ctx.lineCap='round';ctx.lineJoin='round';ctx.strokeStyle=P.body;
      for(const [n,w] of [[46,26],[30,48],[16,70]]){ctx.globalAlpha=.05*rise;ctx.lineWidth=w;ctx.beginPath();pts.slice(0,n).forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.stroke();}
      const h=pts[0],a=Math.atan2(h.y-pts[1].y,h.x-pts[1].x),eye=rage()?P.weak:P.eye;
      for(const s of [-1,1]){const x=h.x+Math.cos(a)*10-Math.sin(a)*s*18,y=h.y+Math.sin(a)*10+Math.cos(a)*s*18;ctx.globalAlpha=.35*rise;glow(ctx,x,y,14,eye,1);}
      ctx.globalAlpha=1;
    }
    // The intro opens on a pair of vast eyes in the dark before the body pours out.
    function drawIntroEyes(ctx,P,age){
      const k=Math.min(1,age/.4)*Math.max(0,1-(age-1.6)/.8),open=Math.min(1,Math.max(0,(age-.2)/.35));if(k<=0)return;
      ctx.globalAlpha=.55*k;ctx.fillStyle=P.dark;ctx.fillRect(0,0,780,G.H);
      for(const s of [-1,1]){
        const x=390+s*120,y=300;ctx.globalAlpha=k;glow(ctx,x,y,120,P.eye,.6);
        ctx.fillStyle=P.eye;ctx.beginPath();ctx.ellipse(x,y,56,26*open+1,s*.12,0,Math.PI*2);ctx.fill();
        ctx.fillStyle=P.dark;ctx.beginPath();ctx.ellipse(x,y,7,24*open+1,0,0,Math.PI*2);ctx.fill();
      }
      ctx.globalAlpha=1;
    }
    // ── Canvas: the serpent. A tapered tube in layers (outline, body, dorsal
    // light, belly line), a pulse of light running head to tail, dorsal fins,
    // diamond scale plates with hp and cracks, and a comet tail.
    const width=(k,n)=>44-18*(k/Math.max(1,n));
    function runs(sn){
      const out=[];let run=headOn(sn)?[{x:sn.head.x,y:sn.head.y,k:0}]:[];
      sn.segs.forEach((s,i)=>{if(s.b)run.push({x:s.x,y:s.y,k:i+1,s});else if(run.length){out.push(run);run=[];}});
      if(run.length)out.push(run);return out;
    }
    function drawSnake(ctx,P,sn){
      const n=sn.segs.length+1,light=sn.twin?P.twin:P.bodyLight,list=runs(sn),stunned=sn.mode==='stun';
      ctx.lineCap='round';ctx.lineJoin='round';
      for(const run of list){
        if(run.length<2)continue;
        for(const [grow,c,a] of [[8,P.dark,.55],[0,P.body,1],[-14,light,.9],[-30,P.belly,.6]]){
          ctx.strokeStyle=c;ctx.globalAlpha=a;
          for(let i=1;i<run.length;i++){const p=run[i-1],q=run[i];ctx.lineWidth=Math.max(2,width(q.k,n)+grow);ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(q.x,q.y);ctx.stroke();}
        }
        // A light pulse runs down the spine; brighter while it charges or cracks.
        const hot=['coil','rend','maw','lunge'].includes(sn.mode)?1:sn.cracks/CRACKS;
        for(let i=1;i<run.length;i++){
          const q=run[i],k=G.reduced?.5:.5+.5*Math.sin(G.time*6-q.k*.7);
          ctx.globalAlpha=(.25+.5*k)*(stunned?.4:1);ctx.strokeStyle=hot>.5?P.weak:P.glow;ctx.lineWidth=3+2*hot;
          ctx.beginPath();ctx.moveTo(run[i-1].x,run[i-1].y);ctx.lineTo(q.x,q.y);ctx.stroke();
        }
      }
      ctx.globalAlpha=1;
      const theme=window.SlingTheme?.canvas,ink=theme?.brickInk.scale||'#06262d',plate=theme?.brick.scale||'#58b3bf';
      for(const [i,s] of sn.segs.entries()){
        if(!s.b)continue;const w=width(i+1,n)*.5;
        ctx.save();ctx.translate(s.x,s.y);ctx.rotate(s.a);
        ctx.strokeStyle=P.star;ctx.lineWidth=2;ctx.globalAlpha=.55;ctx.beginPath();ctx.moveTo(-w*.55,-w*.35);ctx.lineTo(w*.15,0);ctx.lineTo(-w*.55,w*.35);ctx.stroke();ctx.globalAlpha=1;
        ctx.fillStyle=sn.twin?P.twin:plate;ctx.strokeStyle=P.dark;ctx.lineWidth=2;
        ctx.beginPath();ctx.moveTo(w+2,0);ctx.lineTo(0,-w);ctx.lineTo(-w-2,0);ctx.lineTo(0,w);ctx.closePath();ctx.fill();ctx.stroke();
        ctx.fillStyle=P.belly;ctx.globalAlpha=.5;ctx.beginPath();ctx.moveTo(w-2,0);ctx.lineTo(0,-w+5);ctx.lineTo(-4,-w*.3);ctx.closePath();ctx.fill();ctx.globalAlpha=1;
        const dmg=1-s.b.hp/s.b.max;
        if(dmg>.25){ctx.strokeStyle=P.glow;ctx.lineWidth=1.5;ctx.globalAlpha=Math.min(1,dmg*1.3);ctx.beginPath();ctx.moveTo(-w*.6,-w*.3);ctx.lineTo(0,w*.1);ctx.lineTo(w*.4,-w*.4);if(dmg>.6){ctx.moveTo(0,w*.1);ctx.lineTo(-w*.1,w*.7);}ctx.stroke();ctx.globalAlpha=1;}
        if(s.b.flash>0){ctx.globalAlpha=Math.min(1,s.b.flash*4);ctx.fillStyle=P.belly;ctx.beginPath();ctx.arc(0,0,w+4,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;}
        ctx.restore();
        if(s.b.max>1){ctx.font='700 12px "DM Sans", "Noto Sans SC", sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillStyle=ink;ctx.fillText(G.fmt(Math.ceil(s.b.hp)),s.x,s.y+1);ctx.textBaseline='alphabetic';}
      }
      const tail=list.at(-1)?.at(-1);
      if(tail&&tail.s&&tail===list.at(-1).at(-1)&&tail.k===n-1){
        const a=tail.s.a+Math.PI,len=70;ctx.save();ctx.translate(tail.x,tail.y);ctx.rotate(a+(G.reduced?0:Math.sin(G.time*4)*.25));
        const g=ctx.createLinearGradient(0,0,len,0);g.addColorStop(0,hex(P.star,.9));g.addColorStop(1,hex(P.star,0));
        ctx.fillStyle=g;ctx.beginPath();ctx.moveTo(0,-10);ctx.quadraticCurveTo(len*.6,-4,len,0);ctx.quadraticCurveTo(len*.6,4,0,10);ctx.closePath();ctx.fill();ctx.restore();
      }
      if(sn.regen){const s=tipOf(sn);if(s){ctx.globalAlpha=1;glow(ctx,s.x,s.y,G.reduced?24:24+4*Math.sin(G.time*14),P.belly,.45);}}
      if(headOn(sn))drawHead(ctx,P,sn);
    }
    // A horned dragon head whose two mandibles hinge open around a glowing maw.
    function drawHead(ctx,P,sn){
      const h=sn.head,s=sn.scale,stunned=sn.mode==='stun',hot=['coil','rend','lunge','maw'].includes(sn.mode);
      const shake=sn.flinch&&!G.reduced?(Math.random()-.5)*sn.flinch*6:0,open=sn.jaw*.45;
      if(hot){const k=.5+.5*Math.sin(G.time*20);glow(ctx,h.x,h.y,(70+20*k)*s,sn.mode==='maw'?P.star:P.weak,.55);}
      ctx.save();ctx.translate(h.x+shake,h.y);ctx.rotate(h.a+(stunned&&!G.reduced?Math.sin(G.time*5)*.25:0));ctx.scale(s,s);
      // Star mane behind the skull.
      ctx.fillStyle=P.star;ctx.globalAlpha=.85;
      for(let i=0;i<5;i++){const a=Math.PI+(i-2)*.38,l=26+(i%2?8:16)+(G.reduced?0:Math.sin(G.time*6+i)*3);ctx.beginPath();ctx.moveTo(-10+Math.cos(a)*6,Math.sin(a)*18);ctx.lineTo(-10+Math.cos(a)*l,Math.sin(a)*l*1.1);ctx.lineTo(-10+Math.cos(a+.18)*8,Math.sin(a+.18)*20);ctx.closePath();ctx.fill();}
      ctx.globalAlpha=1;
      // Horns.
      ctx.strokeStyle=P.horn;ctx.lineWidth=4.5;ctx.lineCap='round';
      for(const side of [-1,1]){ctx.beginPath();ctx.moveTo(-6,side*15);ctx.quadraticCurveTo(-26,side*38,-46,side*30);ctx.stroke();}
      // The maw between the mandibles.
      if(open>.02){ctx.fillStyle=P.maw;ctx.beginPath();ctx.moveTo(-6,0);ctx.lineTo(40,-Math.sin(open)*44);ctx.lineTo(40,Math.sin(open)*44);ctx.closePath();ctx.fill();glow(ctx,10,0,34*sn.jaw,sn.mode==='maw'?P.star:P.weak,.8);}
      for(const side of [-1,1]){
        ctx.save();ctx.translate(-6,0);ctx.rotate(side*open);
        ctx.fillStyle=P.head;ctx.strokeStyle=sn.twin?P.twin:P.glow;ctx.lineWidth=2.4;
        ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(44,side*2);ctx.quadraticCurveTo(30,side*22,6,side*24);ctx.quadraticCurveTo(-20,side*22,-22,side*6);ctx.lineTo(-22,0);ctx.closePath();ctx.fill();ctx.stroke();
        if(open>.05){ctx.fillStyle=P.belly;for(let i=0;i<4;i++){const x=12+i*8;ctx.beginPath();ctx.moveTo(x,side*2);ctx.lineTo(x+3,side*(2-6));ctx.lineTo(x+6,side*2);ctx.closePath();ctx.fill();}}
        // Brow ridge and eye.
        ctx.strokeStyle=hot||sn.low?P.weak:P.horn;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(8,side*6);ctx.lineTo(28,side*9);ctx.stroke();
        const ex=20,ey=side*13,eye=stunned?P.belly:hot||sn.low||rage()?P.weak:P.eye;
        glow(ctx,ex,ey,16,eye,.7);ctx.fillStyle=eye;ctx.beginPath();ctx.ellipse(ex,ey,6,4.5,0,0,Math.PI*2);ctx.fill();
        if(stunned){ctx.strokeStyle=P.dark;ctx.lineWidth=1.6;ctx.beginPath();ctx.moveTo(ex-4,ey-3);ctx.lineTo(ex+4,ey+3);ctx.moveTo(ex+4,ey-3);ctx.lineTo(ex-4,ey+3);ctx.stroke();}
        else{ctx.fillStyle=P.dark;ctx.fillRect(ex-1,ey-3.5,2,7);}
        ctx.restore();
      }
      if(sn.flinch){ctx.globalAlpha=sn.flinch*.5;ctx.fillStyle=P.weak;ctx.beginPath();ctx.arc(8,0,HEAD_R,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;}
      ctx.restore();
      // Dizzy stars while stunned; crack pips show how close the guard is to breaking.
      if(stunned){for(let i=0;i<3;i++){const a=G.time*4+i*2.1;star4(ctx,h.x+Math.cos(a)*36,h.y-40+Math.sin(a)*10,7,P.star);}}
      else if(sn.cracks>0){for(let i=0;i<CRACKS;i++){ctx.fillStyle=i<sn.cracks?P.weak:P.dark;ctx.globalAlpha=i<sn.cracks?1:.35;ctx.beginPath();ctx.arc(h.x-24+i*12,h.y-50*s,4,0,Math.PI*2);ctx.fill();}ctx.globalAlpha=1;}
    }
    function star4(ctx,x,y,r,c){ctx.fillStyle=c;ctx.beginPath();for(let i=0;i<8;i++){const a=i*Math.PI/4,l=i%2?r*.35:r;ctx[i?'lineTo':'moveTo'](x+Math.cos(a)*l,y+Math.sin(a)*l);}ctx.closePath();ctx.fill();}
    function drawPortal(ctx,P,p){
      const k=Math.min(1,(G.time-p.born)/.3)*Math.min(1,Math.max(0,(p.end-G.time)/.4)),r=(p.exit?54:46)*k;if(r<=0)return;
      const opening=p.exit&&p.open>G.time,u=opening?1-(p.open-G.time)/Math.max(.01,p.open-p.born):1;
      if(opening){
        ctx.globalAlpha=.5+.4*Math.sin(G.time*18);ctx.strokeStyle=P.weak;ctx.lineWidth=2.5;ctx.setLineDash([8,8]);ctx.lineDashOffset=-G.time*40;
        ctx.beginPath();ctx.arc(p.x,p.y,130-60*u,0,Math.PI*2);ctx.stroke();ctx.setLineDash([]);
        ctx.strokeStyle=P.glow;ctx.lineWidth=2;
        for(let i=0;i<7;i++){const a=i*.9+1,l=30+u*70;ctx.globalAlpha=.7;ctx.beginPath();ctx.moveTo(p.x,p.y);for(let j=1;j<=4;j++){const q=l*j/4;ctx.lineTo(p.x+Math.cos(a+jitter(i*7+j)*.25)*q,p.y+Math.sin(a+jitter(i*7+j)*.25)*q*.75);}ctx.stroke();}
      }
      ctx.globalAlpha=k;glow(ctx,p.x,p.y,r*2.2,p.exit?P.star:P.glow,.5);
      ctx.save();ctx.translate(p.x,p.y);ctx.scale(1,.72);
      if(!G.fx?.radial(ctx,0,0,r,[[0,P.dark],[.7,P.portal],[1,hex(P.glow,.6)]])){
        const g=ctx.createRadialGradient(0,0,0,0,0,r);g.addColorStop(0,P.dark);g.addColorStop(.7,P.portal);g.addColorStop(1,hex(P.glow,.6));
        ctx.fillStyle=g;ctx.beginPath();ctx.arc(0,0,r,0,Math.PI*2);ctx.fill();
      }ctx.restore();
      ctx.strokeStyle=p.exit?P.star:P.glow;ctx.lineWidth=2.4;
      const spiral=G.fx?.sprite(`portal-spiral:${p.exit?P.star:P.glow}`,160,160,g=>{
        g.strokeStyle=p.exit?P.star:P.glow;g.lineWidth=2.8;g.beginPath();
        for(let arm=0;arm<4;arm++)for(let i=0;i<=18;i++){const v=i/18,a=arm*Math.PI/2+v*3.4,rr=64*(.15+v*.85);g[i?'lineTo':'moveTo'](80+Math.cos(a)*rr,80+Math.sin(a)*rr);}g.stroke();
      });
      ctx.globalAlpha=.75*k;
      if(spiral){ctx.save();ctx.translate(p.x,p.y);ctx.scale(1,.72);ctx.rotate(G.time*(p.exit?4:-4));ctx.drawImage(spiral.el,-r*1.25,-r*1.25,r*2.5,r*2.5);ctx.restore();}
      else for(let arm=0;arm<4;arm++){ctx.beginPath();for(let i=0;i<=18;i++){const v=i/18,a=G.time*(p.exit?4:-4)+arm*Math.PI/2+v*3.4,rr=r*(.15+v*.85);ctx[i?'lineTo':'moveTo'](p.x+Math.cos(a)*rr,p.y+Math.sin(a)*rr*.72);}ctx.stroke();}
      ctx.globalAlpha=1;
    }
    function drawTether(ctx,P){
      if(!split||split.cut||snakes.length!==2||!snakes.every(headOn))return;
      const [a,b]=snakes.map(sn=>sn.head),k=split.merging?.5:1;
      ctx.lineCap='round';
      for(const [w,al] of [[9,.25],[3,.9]]){
        ctx.strokeStyle=P.tether;ctx.lineWidth=w;ctx.globalAlpha=al*k;ctx.beginPath();ctx.moveTo(a.x,a.y);
        for(let i=1;i<10;i++){const u=i/10,j=G.reduced?0:(Math.random()-.5)*8;ctx.lineTo(a.x+(b.x-a.x)*u+j,a.y+(b.y-a.y)*u+j);}ctx.lineTo(b.x,b.y);ctx.stroke();
      }
      for(let i=0;i<4;i++){const u=((G.time*.6+i/4)%1);ctx.globalAlpha=k;glow(ctx,a.x+(b.x-a.x)*u,a.y+(b.y-a.y)*u,12,P.tether,1);}
      ctx.globalAlpha=1;
    }
    function drawMaw(ctx,P,sn){
      const m=mouthOf(sn),k=Math.min(1,(G.time-sn.t0)/.4);
      ctx.strokeStyle=P.star;ctx.lineWidth=2;
      for(let i=0;i<16;i++){
        const a=i/16*Math.PI*2+jitter(i)*.3,u=G.reduced?.5:((G.time*1.4+jitter(i+9)*.5+1)%1),r0=320*(1-u)+40,r1=r0+40+60*(1-u);
        ctx.globalAlpha=k*.6*u;ctx.beginPath();ctx.moveTo(m.x+Math.cos(a)*r1,m.y+Math.sin(a)*r1);ctx.lineTo(m.x+Math.cos(a)*r0,m.y+Math.sin(a)*r0);ctx.stroke();
      }
      ctx.globalAlpha=k*.25;ctx.setLineDash([4,10]);ctx.beginPath();ctx.arc(m.x,m.y,360,0,Math.PI*2);ctx.stroke();ctx.setLineDash([]);
      ctx.globalAlpha=k;glow(ctx,m.x,m.y,70,P.star,.6);ctx.globalAlpha=1;
    }
    function drawCoil(ctx,P,sn){
      const k=Math.min(1,(G.time-sn.t0)/sn.dur),h=sn.head,to=sn.to,a=Math.atan2(to.y-h.y,to.x-h.x),len=Math.hypot(to.x-h.x,to.y-h.y);
      ctx.save();ctx.translate(h.x,h.y);ctx.rotate(a);
      ctx.globalAlpha=.1+.15*k;ctx.fillStyle=P.weak;ctx.fillRect(0,-60,len,120);
      ctx.globalAlpha=.5+.4*k;ctx.fillStyle=P.weak;
      for(let i=0;i<Math.floor(len/48);i++){const x=((i*48+G.time*240)%len);ctx.beginPath();ctx.moveTo(x,-14);ctx.lineTo(x+16,0);ctx.lineTo(x,14);ctx.lineTo(x+6,0);ctx.closePath();ctx.fill();}
      ctx.restore();
      ctx.globalAlpha=.6+.3*Math.sin(G.time*20);ctx.strokeStyle=P.weak;ctx.lineWidth=3;
      ctx.beginPath();ctx.arc(to.x,to.y,26+30*(1-k),0,Math.PI*2);ctx.moveTo(to.x-44,to.y);ctx.lineTo(to.x+44,to.y);ctx.moveTo(to.x,to.y-44);ctx.lineTo(to.x,to.y+44);ctx.stroke();
      ctx.globalAlpha=1;
    }
    function drawField(ctx){
      const P=R();if(api.dying()?.exploded)return;
      for(const p of portals)drawPortal(ctx,P,p);
      drawTether(ctx,P);
      for(const g of ghosts){const k=1-(G.time-g.born)/.35;ctx.globalAlpha=k*.45;ctx.fillStyle=g.twin?P.twin:P.weak;ctx.beginPath();ctx.ellipse(g.x,g.y,40*k+10,22*k+6,g.a,0,Math.PI*2);ctx.fill();}
      ctx.globalAlpha=1;
      for(const sn of snakes){if(sn.mode==='maw')drawMaw(ctx,P,sn);if(sn.mode==='coil')drawCoil(ctx,P,sn);}
      for(const sn of snakes)drawSnake(ctx,P,sn);
      for(const d of debris){
        const u=ease(Math.min(1,(G.time-d.born)/.45)),m=mouthOf(d.sn),x=d.x+(m.x-d.x)*u,y=d.y+(m.y-d.y)*u,s=1-u*.85;
        ctx.save();ctx.translate(x,y);ctx.rotate(d.spin*u);ctx.scale(s,s);ctx.fillStyle=G.colors[d.type];ctx.globalAlpha=1-u*.4;ctx.fillRect(-d.w/2,-d.h/2,d.w,d.h);ctx.restore();
      }
      for(let si=0;si<sparks.length;si++){const s=sparks[si],detailed=si>=sparks.length-24;
        ctx.strokeStyle=P.spark;ctx.lineCap='round';
        for(let step=0;step<(detailed?3:1);step++){ctx.globalAlpha=detailed?(step+1)/3*.8:.5;ctx.lineWidth=detailed?1+step*1.6:2;ctx.beginPath();
          for(let i=1;i<s.trail.length;i++)if(!detailed||Math.min(2,i/s.trail.length*3|0)===step){const q=s.trail[i],p=s.trail[i-1];ctx.moveTo(p.x,p.y);ctx.lineTo(q.x,q.y);}ctx.stroke();
        }
        ctx.globalAlpha=1;if(detailed)glow(ctx,s.x,s.y,16,P.spark,.9);star4(ctx,s.x,s.y,6,P.star);
      }
      for(const d of dust){const k=1-(G.time-d.born)/d.life;ctx.globalAlpha=k*.8;ctx.fillStyle=P.star;ctx.fillRect(d.x-d.r/2,d.y-d.r/2,d.r,d.r);}
      ctx.globalAlpha=1;
    }
    // ── Front layer: flares, shock rings, streaks, the eclipse, eye trails and the pressure vignette.
    let mask=null;
    function drawFront(ctx){
      const P=R(),d=api.dying();
      drawFx(ctx);
      if(d?.exploded)return;
      const age=api.introAge();if(Number.isFinite(age)&&age<2.4&&!G.reduced)drawIntroEyes(ctx,P,age);
      drawEclipse(ctx,P);drawEyeTrails(ctx,P);drawVignette(ctx,P);
      if(d){const f=focus(),k=Math.min(1,(G.time-d.at)/1.3);ctx.globalAlpha=.3+.5*k;glow(ctx,f.x,f.y,80+k*460,P.belly,1);ctx.globalAlpha=1;}
    }
    function drawFx(ctx){
      for(let fi=Math.max(0,fx.length-(G.reduced?16:32));fi<fx.length;fi++){const f=fx[fi];
        const u=Math.min(1,(G.time-f.born)/f.life),k=1-u;
        if(f.k==='flare'){ctx.globalAlpha=k;glow(ctx,f.x,f.y,f.r*(.6+.6*u),f.c,.85);}
        else if(f.k==='wave'){ctx.globalAlpha=k*.8;ctx.strokeStyle=f.c;ctx.lineWidth=f.w*k+1;ctx.beginPath();ctx.arc(f.x,f.y,f.r*ease(u),0,Math.PI*2);ctx.stroke();ctx.globalAlpha=k*.3;ctx.lineWidth=f.w*2.4*k;ctx.stroke();}
        else{ctx.strokeStyle=f.c;ctx.lineCap='round';for(const r of f.rays){const a=f.len*r.s*ease(u),b=a*.45;ctx.globalAlpha=k;ctx.lineWidth=3*k+.5;ctx.beginPath();ctx.moveTo(f.x+Math.cos(r.a)*b,f.y+Math.sin(r.a)*b);ctx.lineTo(f.x+Math.cos(r.a)*a,f.y+Math.sin(r.a)*a);ctx.stroke();}}
      }
      ctx.globalAlpha=1;
    }
    // The eclipse is a dark sheet with soft holes punched around whatever still gives light.
    function drawEclipse(ctx,P){
      const k=eclipseK();if(k<=0||typeof document==='undefined'||!document.createElement)return;
      const H=Math.ceil(G.H),S=.5;
      if(!mask){mask=document.createElement('canvas');if(!mask.getContext){mask=null;return;}}
      if(mask.width!==390||mask.height!==Math.ceil(H*S)){mask.width=390;mask.height=Math.ceil(H*S);}
      const m=mask.getContext('2d');if(!m)return;
      m.setTransform(S,0,0,S,0,0);m.globalCompositeOperation='source-over';m.clearRect(0,0,780,H);m.fillStyle=P.dark;m.fillRect(0,0,780,H);
      m.globalCompositeOperation='destination-out';
      const hole=(x,y,r)=>{if(G.fx?.hole(m,x,y,r))return;const g=m.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,'rgba(0,0,0,1)');g.addColorStop(.6,'rgba(0,0,0,.8)');g.addColorStop(1,'rgba(0,0,0,0)');m.fillStyle=g;m.beginPath();m.arc(x,y,r,0,Math.PI*2);m.fill();};
      hole(G.origin.x,G.origin.y,190);
      for(const a of G.arrows)hole(a.body.position.x,a.body.position.y,90);
      for(const b of G.bricks)if(b.type==='star')hole(b.x,b.y,70);
      for(const s of sparks)hole(s.x,s.y,50);
      for(const p of portals)hole(p.x,p.y,80);
      for(const sn of snakes)if(headOn(sn))hole(sn.head.x,sn.head.y,sn.mode==='stun'?120:44);
      ctx.globalAlpha=.92*k;ctx.drawImage(mask,0,0,780,H);ctx.globalAlpha=1;
      // Its eyes burn through the dark.
      for(const sn of snakes)if(headOn(sn))for(const e of eyePoints(sn)){ctx.globalAlpha=k;glow(ctx,e.x,e.y,26,sn.mode==='stun'?P.belly:P.weak,1);}
      ctx.globalAlpha=1;
    }
    function drawEyeTrails(ctx,P){
      if(G.reduced)return;
      for(const sn of snakes){
        if(!headOn(sn)||sn.eyes.length<2)continue;const c=eclipse||sn.low||['lunge','coil'].includes(sn.mode)?P.weak:P.eye,strong=eclipse||sn.mode==='lunge'?1:.45;
        ctx.strokeStyle=c;ctx.lineCap='round';
        for(const side of [0,1])for(let i=1;i<sn.eyes.length;i++){const p=sn.eyes[i-1][side],q=sn.eyes[i][side];ctx.globalAlpha=i/sn.eyes.length*strong;ctx.lineWidth=1+i*.35;ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(q.x,q.y);ctx.stroke();}
      }
      ctx.globalAlpha=1;
    }
    // Pressure: the edges darken as a head closes in on the sling, more so in the last phase.
    function drawVignette(ctx,P){
      const near=Math.max(0,...snakes.filter(headOn).map(sn=>1-Math.min(1,Math.abs(sn.head.y-G.origin.y)/520)));
      const k=Math.min(.55,near*.4+(rage()?.12:0)+(G.reduced?0:.04*Math.sin(G.time*2.4)));if(k<=0)return;
      if(G.fx?.vignette(ctx,780,G.H,P.dark,k))return;
      const g=ctx.createRadialGradient(390,G.H*.45,G.H*.3,390,G.H*.45,G.H*.75);g.addColorStop(0,hex(P.dark,0));g.addColorStop(1,hex(P.dark,k));
      ctx.fillStyle=g;ctx.fillRect(0,0,780,G.H);
    }
    // Collapse: scales burst off tail-first while the head thrashes.
    function charging(){
      if(G.time<popAt)return;popAt=G.time+.07;const P=R();
      for(const sn of snakes){const s=[...sn.segs].reverse().find(s=>s.b);if(s){G.burst(s.x,s.y,P.star,10,1.6);flare(s.x,s.y,P.glow,70,.3);G.hit(s.b,1e9,99);}}
    }
    function exploded(){const f=focus(),P=R();streaks(f.x,f.y,P.star,30,700,.9);flare(f.x,f.y,P.belly,500,1);wave(f.x,f.y,P.glow,900,1.1,18);}

    // ── Score: D minor, 8 bars (Dm Bb Gm A | Dm Bb C A). Phase 1 is pad, bass
    // and a heartbeat kick; phase 2 adds the arp and a backbeat; phase 3 brings
    // in the lead; phase 4 splits the lead into twin voices a third apart,
    // echoing across the stereo field while the serpent is split.
    const ROOTS=[62,58,55,57,62,58,60,57],MINOR=[1,0,1,0,1,0,0,0];
    const KEY=new Set([2,4,5,7,9,10,0]),LEAD=74;
    const MOTIF=[
      [[0,4,0],[4,2,3],[6,4,7],[12,4,5]],
      [[0,4,0],[4,2,-2],[6,4,-4],[12,4,-2]],
      [[0,6,3],[6,2,0],[8,4,-4],[12,4,-7]],
      [[0,6,2],[6,2,3],[8,8,-1]],
      [[0,2,7],[2,2,10],[4,4,12],[8,4,10],[12,4,7]],
      [[0,4,8],[4,4,7],[8,4,5],[12,4,3]],
      [[0,4,2],[4,4,0],[8,4,-2],[12,4,2]],
      [[0,4,-1],[4,4,2],[8,4,7],[12,4,11]]
    ];
    const triad=bar=>{const r=ROOTS[bar];return [r,r+(MINOR[bar]?3:4),r+7];};
    // A diatonic third below, sharpening C to C# over the A chord.
    function third(n,bar){
      const scale=bar===3||bar===7?new Set([...KEY].map(p=>p===0?1:p)):KEY;
      for(const d of [3,4])if(scale.has(((n-d)%12+12)%12))return n-d;
      return n-3;
    }
    function events(step,phase,mood,twin){
      const bar=step>>4,s=step&15,out=[],ch=triad(bar),dark=mood==='eclipse';
      if(s===0)out.push({i:'pad',notes:ch.map(n=>n-12),vel:1,bright:mood==='stun'?1:phase>=3?.5:0});
      if(mood==='intro'){if(s===0||s===3)out.push({i:'kick',vel:s?.5:.8});return out;}
      // Drums.
      const kick=phase===1||dark?[0,3]:phase===2?[0,8,10]:[0,4,8,11,12];
      if(kick.includes(s))out.push({i:'kick',vel:s===0?1:.8});
      if(phase>=2&&!dark){
        if(s===4||s===12)out.push({i:'snare',vel:1});
        if(phase>=3&&(s===7||s===15))out.push({i:'snare',vel:.3});
        if(bar===7&&s>=12&&phase>=2)out.push({i:'snare',vel:.4+.15*(s-12)});
      }
      if(!dark){const hats=phase===1?s%4===2:phase===2?s%2===0:true;if(hats)out.push({i:'hat',vel:s%4===2?1:.55,open:phase>=3&&s===14});}
      // Bass: a driving root pulse that gets busier with each phase.
      const r=ROOTS[bar]-24,bass=phase===1||dark?[0,6,10]:phase===2?[0,2,4,6,8,10,12,14]:[0,2,3,6,8,10,11,14];
      if(bass.includes(s))out.push({i:'bass',note:phase>=3&&(s===3||s===11)?r+12:r,vel:s===0?1:.8,len:phase===1?1.4:.45});
      // Arp.
      if(phase>=2&&!dark&&mood!=='devour'){const pat=[0,1,2,1,0,2,1,2],n=[...ch,ch[0]+12][pat[s%8]%4]+12;if(phase>=3||s%2===0)out.push({i:'arp',note:n,vel:s%4===0?1:.7,pan:s%2?.3:-.3});}
      // Lead, with a twin a third below from phase four.
      if(phase>=3&&mood!=='devour')for(const [at,len,off] of MOTIF[bar]){
        if(at!==s)continue;const n=LEAD+off;
        if(dark){if(s===0)out.push({i:'lead',note:n,len,vel:.6});continue;}
        if(twin&&phase>=4){out.push({i:'lead',note:n,len,vel:.9,pan:-.45});out.push({i:'lead',note:third(n,bar),len,vel:.8,pan:.45});}
        else out.push({i:'lead',note:n,len,vel:1});
      }
      // Bells glitter while the serpent is down.
      if(mood==='stun'&&s%4===0)out.push({i:'bell',note:ch[(s>>2)%3]+24,vel:1});
      if(phase>=4&&twin&&s===8)out.push({i:'bell',note:ch[2]+24,vel:.6});
      return out;
    }
    const score={
      bars:8,bpm:phase=>phase>=4?140:phase>=3?134:128,events,
      mix:[
        {pad:.9,bass:.8,drums:.7,arp:0,lead:0,bell:.6},
        {pad:.8,bass:.9,drums:.85,arp:.6,lead:0,bell:.6},
        {pad:.7,bass:.95,drums:.95,arp:.55,lead:.8,bell:.6},
        {pad:.7,bass:1,drums:1,arp:.6,lead:.9,bell:.7}
      ],
      moods:{intro:{pad:1,drums:.6,bass:0,arp:0,lead:0},stun:{drums:-.45,bass:-.6,lead:-1.2,bell:1},eclipse:{pad:1,drums:.8,bass:.7,arp:0,lead:.5},devour:{bass:-.4,arp:0,lead:0}},
      stab:[62,66,69,74],stinger:[50,57,62,64,65,69]
    };
    // What the score reads each tick.
    function music(){
      if(snakes.some(sn=>sn.mode==='lurk'||sn.mode==='emerge'))return {mood:'intro'};
      const twin=fight()?.phase>=4&&snakes.length===2;
      if(snakes.some(sn=>sn.mode==='stun'))return {mood:'stun',twin};
      if(eclipse)return {mood:'eclipse',twin};
      if(snakes.some(sn=>sn.mode==='maw'||sn.mode==='rear'))return {mood:'devour',twin};
      return {mood:'fight',twin};
    }

    const def={
      id:'serpent',name:'星渊巨蟒',score,music,title:'STAR SERPENT',tagline:'',
      kicker:'WARNING · SERPENT',note:'',rageNote:'星蚀狂舞',hitLabel:'蛇首命中',roar:'serpent',
      seal:['SERPENT FALLEN','星渊巨蟒 · 陨落',''],
      phases:4,phaseNames:['游星','噬光','星蚀','双生'],abilities,roll,
      hp:phase=>Math.ceil(G.damage()*(20+5*phase)),
      mods:m=>({hp:1+.15*(m.phase-1),barriers:m.phase>=3?6:3,decorate}),
      palette:()=>{const P=R();return {main:P.glow,hot:P.weak,light:P.belly,text:P.text};},
      focus,moving:()=>true,status,
      init:data=>{data.snakes=[];data.regrowth=0;data.lengthVersion=2;},
      validate:data=>(data.lengthVersion===undefined||data.lengthVersion===1||data.lengthVersion===2)&&(data.regrowth===undefined||Number.isSafeInteger(data.regrowth)&&data.regrowth>=0)&&Array.isArray(data.snakes)&&data.snakes.length<=2&&data.snakes.every(s=>s&&Number.isInteger(s.max)&&s.max>0&&s.max<=MAX_SEGS&&Array.isArray(s.segs)&&s.segs.length<=MAX_SEGS&&s.segs.every(h=>Number.isFinite(h)&&h>0)&&(s.retreat===undefined||typeof s.retreat==='boolean')&&(s.retreatLeft===undefined||Number.isFinite(s.retreatLeft)&&s.retreatLeft>=0&&s.retreatLeft<=3.2)),
      hydrate,persist,
      intro(){arm(G.time+(G.reduced?.4:2.6));if(snakes.some(sn=>sn.mode==='lurk'))api.later(.7,()=>{if(snakes.some(sn=>sn.mode==='lurk'))emergeAll();});},
      shifted(){arm(G.time+1.5);},
      charging,exploded,
      pending:()=>sparks.length>0||debris.length>0||snakes.some(sn=>sn.mode==='lunge'),
      calm(){sparks=[];portals=[];debris=[];ghosts=[];eclipse=null;if(dim){dim=false;G.predictionVersion++;}},
      reset(){snakes=[];sparks=[];portals=[];debris=[];fx=[];ghosts=[];dust=[];split=null;eclipse=null;dim=false;owner=null;fresh=false;},
      contact,destroyed,pre,post,drawBack,drawField,drawFront,
      debug:()=>({snakes:snakes.map(sn=>({mode:sn.mode,head:{...sn.head},segs:sn.segs.length,live:sn.segs.filter(s=>s.b).length,twin:sn.twin,exit:sn.exit,cracks:sn.cracks,fed:sn.fed,mouth:sn.mouth,max:sn.max,regen:!!sn.regen,retreat:sn.retreat})),
        regrowth:fight()?.data.regrowth||0,sparks:sparks.length,portals:portals.length,split:split?{cut:split.cut,merging:!!split.merging}:null,eclipse:!!eclipse,dim,debris:debris.length})
    };
    return def;
  });
})();
