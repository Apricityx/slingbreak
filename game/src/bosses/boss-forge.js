(() => {
  'use strict';
  // 熔炉巨像: the board is the colossus's body. Its molten heart sits in the
  // middle of the board behind iron plates; dig a lane and shoot it. Every
  // brick broken chips the boss and stokes the furnace. At full heat it
  // overheats: the heart takes double damage and breaking bricks set off blasts.
  (window.SlingBosses||=[]).push(api=>{
    const {G,Body,has,rage}=api,fight=api.fight;
    const HEART={x:390,y:470,r:30},MOUTH={x:390,y:78},PALM={y:835,half:50,r:14};
    const fallback={iron:'#3b342f',ironEdge:'#6b6258',ember:'#f08a3c',molten:'#ffb347',core:'#fff1c7',glow:'#e2562a',crack:'#ff7a2e',smoke:'#8a7f75',wind:'#b09a82',text:'#9a3f12',weak:'#d8401f'};
    const R=()=>window.SlingTheme?.canvas.forge||fallback;
    const abilities={
      meteor:{name:'陨火',desc:'口中喷出陨火，落地化为熔岩砖，可在空中击落'},
      magma:{name:'熔流',desc:'熔岩砖更多，爆裂时点燃周围砖块'},
      slam:{name:'锻锤',desc:'巨锤砸落整列，未碎的砖锻成铁甲'},
      bellows:{name:'炉息',desc:'炉风横扫战场，箭矢随风偏移'},
      palm:{name:'石掌',desc:'石掌在弹弓前拦截来箭，击打数次可击碎'}
    };
    let meteors=[],slam=null,wind=null,palm=null,embers=[];
    let meteorAt=0,slamAt=0,windAt=0,hurt=0,mouth=0,overheatUntil=0,hinted=false;
    const heat=()=>fight()?.data.heat||0;
    const overheated=()=>G.time<overheatUntil;
    const plateHp=phase=>Math.max(G.baseHp()*2,Math.ceil(G.damage()*(3+phase)));

    // ── Board: an iron frame around the heart cell, magma veins elsewhere.
    function decorate(){
      const m=fight(),base=G.baseHp(),hp=plateHp(m.phase);
      for(const b of G.bricks.filter(b=>Math.hypot(b.x-HEART.x,b.y-HEART.y)<20))api.removeBrick(b);
      for(let dc=-1;dc<=1;dc++)for(let dr=-1;dr<=1;dr++){
        if(!dc&&!dr)continue;
        const x=HEART.x+dc*96,y=HEART.y+dr*60;
        const b=G.bricks.find(b=>b.x===x&&b.y===y)||G.makeBrick({x,y,w:84,h:44,hp,max:hp,type:'plate',frozen:false});
        b.type='plate';b.hp=b.max=hp;
      }
      const rest=api.shuffle(G.bricks.filter(b=>b.type==='normal'));
      rest.slice(0,has('magma')?9:3).forEach(b=>{b.type='magma';b.hp=b.max=base;});
      m.data.heat=0;
    }

    // ── Heart, stone palm and shootable meteors.
    function contact(a,live){
      const hit=api.bounceCircle(a,HEART.x,HEART.y,HEART.r+3);
      if(hit&&live){a.trail=[];strikeHeart(a,hit.x,hit.y);}
      if(palm&&G.time>=palm.down){
        const p=api.bounceCapsule(a,palm.x-PALM.half,PALM.y,palm.x+PALM.half,PALM.y,PALM.r,.8);
        if(p&&live&&G.time>=(a.palmAt||0)){a.palmAt=G.time+.2;a.trail=[];hitPalm(a,p.x,p.y);}
      }
    }
    function strikeHeart(a,x,y){
      if(!api.canStrike(a))return;
      const P=R(),hot=overheated();
      api.strike(a,x,y,hot?6:3);hurt=1;
      G.burst(x,y,hot?P.core:P.molten,hot?22:14,1.8);G.ring(x,y,P.glow,hot?110:70);
      G.shake=Math.min(14,G.shake+(hot?7:4));G.sound('eyehit',1,x);G.sound('clang',1,x);api.freeze(hot?80:45);
      addHeat(6);
    }
    function hitPalm(a,x,y){
      const P=R();palm.hits++;palm.flash=1;
      G.burst(x,y,P.smoke,8,1);G.sound('clang',1,x);G.shake=Math.max(G.shake,3);
      if(!hinted){hinted=true;G.toast?.('连击可击碎石掌');}
      if(palm.hits>=4){
        palm.down=G.time+(rage()?4:6);palm.hits=0;
        api.pay(a,x,y-10,2);G.float(x,y-34,'击碎',P.text,18);
        G.burst(x,y,P.iron,26,2.2);G.burst(x,y,P.ember,12,1.6);G.ring(x,y,P.ember,120);G.sound('shatter',1,x);api.freeze(70);
      }
    }
    function physics(){
      // Meteors in flight can be shot down with any live arrow.
      for(const m of meteors)if(!m.dead&&G.time>=m.born)for(const a of G.arrows){
        const p=meteorPos(m),q=a.body.position;
        if(Math.hypot(p.x-q.x,p.y-q.y)<26){shootDown(m,a,p);break;}
      }
    }
    function shootDown(m,a,p){
      const P=R();m.dead=true;
      G.withArrow(a,()=>{api.pay(a,p.x,p.y,1.5);});
      G.float(p.x,p.y-24,'击落',P.text,16);G.burst(p.x,p.y,P.molten,20,1.8);G.ring(p.x,p.y,P.ember,80);G.sound('shatter',1,p.x);
      addHeat(12);
    }
    function destroyed(b,depth){
      const P=R();
      api.hurt(G.damage()*(b.type==='plate'?1:.12),b.x,b.y,{quiet:b.type!=='plate'});
      addHeat(b.type==='magma'?10:b.type==='plate'?8:4);
      if(b.type==='plate')G.sound('clang',1,b.x);
      if(b.type==='magma'&&depth<6)erupt(b,depth);
      // Overheat: every break throws a small blast into its neighbours.
      else if(overheated()&&depth<3){
        G.ring(b.x,b.y,P.ember,96);G.burst(b.x,b.y,P.molten,6,1.2);
        G.bricks.filter(t=>Math.hypot(t.x-b.x,t.y-b.y)<100).forEach(t=>G.hit(t,G.damage()*.8,depth+1));
      }
    }
    function erupt(b,depth){
      const P=R();
      G.ring(b.x,b.y,P.ember,130);G.ring(b.x,b.y,P.molten,70);G.burst(b.x,b.y,P.ember,22,2);G.burst(b.x,b.y,P.core,8,1.4);
      G.shake=Math.max(G.shake,6);G.sound('boom',1,b.x);embers.push({x:b.x,y:b.y,born:G.time});
      const near=G.bricks.filter(t=>Math.hypot(t.x-b.x,t.y-b.y)<125);
      near.forEach(t=>G.hit(t,G.damage()*1.6,depth+1));
      if(has('magma'))G.bricks.filter(t=>t.type==='normal'&&Math.hypot(t.x-b.x,t.y-b.y)<125).slice(0,2).forEach(t=>{t.type='magma';t.flash=.3;G.predictionVersion++;});
    }
    function addHeat(n){
      const m=fight();if(!m||overheated()||api.dying())return;
      m.data.heat=Math.min(100,heat()+n);
      if(m.data.heat>=100)overheat();
    }
    function overheat(){
      const P=R();fight().data.heat=0;overheatUntil=G.time+6;
      G.shake=12;G.coreFlash=1;api.freeze(120);
      G.ring(HEART.x,HEART.y,P.core,520);G.ring(HEART.x,HEART.y,P.ember,300);G.burst(HEART.x,HEART.y,P.molten,50,2.6);
      G.sound('forge');G.sound('boom',1,HEART.x);
      api.flash('weak');api.banner('OVERHEAT','过热','心核伤害翻倍','weak');
    }
    // ── Meteors: an arc from the mouth to a brick (becomes magma) or an empty slot (new magma).
    const meteorPos=m=>{const u=Math.max(0,Math.min(1,(G.time-m.born)/m.dur));return{x:m.x0+(m.x1-m.x0)*u,y:m.y0+(m.y1-m.y0)*u-Math.sin(u*Math.PI)*m.arc,u};};
    function launch(){
      const P=R(),count=rage()?4:3,targets=[];
      const bricks=api.shuffle(G.bricks.filter(b=>!b.orbit&&b.type==='normal')),open=api.shuffle(api.openSlots());
      for(let i=0;i<count;i++){const t=(i%2?open.shift():bricks.shift())||bricks.shift()||open.shift();if(t)targets.push(t);}
      targets.forEach((t,i)=>meteors.push({x0:MOUTH.x+(i-1)*14,y0:MOUTH.y+10,x1:t.x,y1:t.y,born:G.time+.35+i*.22,dur:1.25,arc:120+Math.random()*80,dead:false,trail:[]}));
      mouth=1;G.sound('forge');G.float(MOUTH.x,MOUTH.y+40,'陨火',P.text,15);
    }
    function land(m){
      const P=R(),{x1:x,y1:y}=m,b=G.bricks.find(b=>!b.orbit&&Math.abs(b.x-x)<30&&Math.abs(b.y-y)<20);
      if(b){if(b.type==='normal'){b.type='magma';G.predictionVersion++;}b.flash=.3;}
      else if(G.bricks.length<230&&!api.occupied(x,y)){
        const hp=G.baseHp(),n=G.makeBrick({x,y,w:84,h:44,hp,max:hp,type:'magma',frozen:false});api.pop(n,P.ember);G.initial++;G.predictionVersion++;
      }
      G.ring(x,y,P.ember,90);G.burst(x,y,P.molten,16,1.6);G.shake=Math.max(G.shake,5);G.sound('meteor',1,x);
    }
    // ── Hammer: a telegraphed column slam. Survivors are forged into iron plates.
    function strikeColumn(){
      const P=R(),x=slam.x,hp=plateHp(fight().phase);slam.hit=true;
      G.shake=16;api.freeze(110);G.coreFlash=.6;G.sound('clang',1,x);G.sound('boom',1,x);
      for(let y=170;y<=800;y+=60)G.burst(x,y,P.smoke,4,1.4);
      G.ring(x,800,P.ember,160);
      const column=G.bricks.filter(b=>!b.orbit&&Math.abs(b.x-x)<48);
      // Depth 70 keeps hammer kills out of chip damage and magma chains: it is the boss's own blow.
      column.forEach(b=>G.hit(b,G.damage()*2.5,70));
      for(const b of column)if(G.bricks.includes(b)&&b.type!=='plate'){b.type='plate';b.max=Math.max(b.max,hp);b.hp=Math.min(b.max,Math.max(b.hp,hp*.6));b.flash=.3;}
      G.predictionVersion++;
    }
    // ── Stone palm hovers in front of the sling and slides toward the aim.
    function movePalm(dt){
      if(!palm)return;
      let target=390+Math.sin(G.time*.8)*150;
      if(G.drag&&G.drag.dy>5){const d=G.drag,dy=G.origin.y-PALM.y;target=G.origin.x-d.dx/d.dy*dy;}
      target=Math.max(110,Math.min(670,target));
      const step=(rage()?130:90)*dt;palm.x+=Math.max(-step,Math.min(step,target-palm.x));
      palm.flash=Math.max(0,palm.flash-dt*4);
    }
    function pre(dt){if(!api.dying())movePalm(dt);}
    function post(dt){
      const P=R();
      for(const m of meteors)if(!m.dead&&G.time>=m.born){const p=meteorPos(m);m.trail.push({x:p.x,y:p.y});if(m.trail.length>10)m.trail.shift();if(p.u>=1){m.dead=true;land(m);}}
      meteors=meteors.filter(m=>!m.dead);
      if(slam&&!slam.hit&&G.time>=slam.at)strikeColumn();
      if(slam&&G.time>=slam.end)slam=null;
      if(wind){
        const k=G.time<wind.start?0:G.time>=wind.end?0:Math.min(1,(G.time-wind.start)/.5,(wind.end-G.time)/.5);
        const gx=api.GRAVITY.x+wind.dir*.22*k;
        if(G.engine.gravity.x!==gx){G.engine.gravity.x=gx;G.predictionVersion++;}
        if(G.time>=wind.end){wind=null;api.restoreGravity();}
      }
      embers=embers.filter(e=>G.time-e.born<.8);
      hurt=Math.max(0,hurt-dt*3);mouth=Math.max(0,mouth-dt*1.2);
      if(api.dying()||!api.ready())return;
      if(has('meteor')&&G.time>=meteorAt){meteorAt=G.time+(rage()?5:7);launch();}
      if(has('slam')&&!slam&&G.time>=slamAt){
        slamAt=G.time+(rage()?6.5:8.5);
        const cols=[0,1,2,3,4,5,6].map(c=>102+c*96).filter(x=>G.bricks.some(b=>!b.orbit&&Math.abs(b.x-x)<48));
        if(cols.length){const x=cols[Math.floor(Math.random()*cols.length)];slam={x,at:G.time+1.2,end:G.time+1.9,hit:false};G.sound('forge');}
      }
      if(has('bellows')&&!wind&&G.time>=windAt){
        windAt=G.time+(rage()?7:9.5);
        wind={dir:Math.random()<.5?-1:1,start:G.time+.9,end:G.time+4.4};
        api.banner('BELLOWS',wind.dir>0?'炉息 →':'← 炉息','','minor');
      }
      if(overheated()&&!G.reduced&&Math.random()<.3)G.burst(HEART.x+(Math.random()-.5)*300,HEART.y+(Math.random()-.5)*500,P.ember,1,.6);
    }
    const arm=(t=G.time)=>{meteorAt=t+3;slamAt=t+5;windAt=t+4;};
    const clearFx=()=>{meteors=[];slam=null;wind=null;embers=[];overheatUntil=0;};
    // ── Canvas. Backdrop: the colossus silhouette glowing through gaps in the board.
    const jitter=i=>Math.sin(i*127.1)*.5+Math.sin(i*311.7)*.5;
    function drawBack(ctx){
      const P=R(),d=api.dying(),rise=Math.min(1,Math.max(0,api.introAge()/1.6)),hot=overheated()?1:heat()/100;
      if(d?.exploded)return;
      ctx.save();ctx.globalAlpha=.9*rise;ctx.fillStyle=P.iron;
      // Helmet, shoulders and torso.
      ctx.beginPath();ctx.moveTo(300,150);ctx.quadraticCurveTo(292,24,390,16);ctx.quadraticCurveTo(488,24,480,150);ctx.closePath();ctx.fill();
      ctx.beginPath();ctx.moveTo(40,250);ctx.quadraticCurveTo(70,150,260,140);ctx.lineTo(520,140);ctx.quadraticCurveTo(710,150,740,250);ctx.lineTo(700,820);ctx.quadraticCurveTo(390,880,80,820);ctx.closePath();
      ctx.globalAlpha=.32*rise;ctx.fill();ctx.globalAlpha=.6*rise;ctx.strokeStyle=P.ironEdge;ctx.lineWidth=2;ctx.stroke();
      // Visor eyes track the lowest arrow, else the aim.
      let tx=0;if(G.drag)tx=-G.drag.dx/105;else if(G.arrows.length)tx=Math.max(-1,Math.min(1,(G.arrows[0].body.position.x-390)/300));
      const glow=.55+.35*Math.sin(G.time*3)+hurt*.4;
      ctx.globalAlpha=Math.min(1,glow)*rise;ctx.fillStyle=rage()?P.weak:P.ember;
      for(const s of [-1,1]){ctx.beginPath();ctx.ellipse(390+s*38+tx*8,92,22,6,s*.12,0,Math.PI*2);ctx.fill();}
      // Mouth grate glows before meteors.
      ctx.globalAlpha=(.25+mouth*.75)*rise;ctx.fillStyle=mouth>.1?P.molten:P.glow;ctx.fillRect(360,118,60,12);
      ctx.globalAlpha=rise;ctx.strokeStyle=P.iron;ctx.lineWidth=2;for(let x=368;x<420;x+=10){ctx.beginPath();ctx.moveTo(x,118);ctx.lineTo(x,130);ctx.stroke();}
      // Magma cracks from the heart, hotter with heat and during the collapse.
      const k=d?Math.min(1,(G.time-d.at)/1.3):0,n=9+Math.ceil(k*10);
      ctx.strokeStyle=P.crack;ctx.lineCap='round';
      for(let i=0;i<n;i++){
        const a=i/n*Math.PI*2+jitter(i)*.4,len=(170+jitter(i+5)*80)*(1+k*.9);
        ctx.globalAlpha=(.25+hot*.45+k*.3)*rise*(.75+.25*Math.sin(G.time*4+i));ctx.lineWidth=2+hot*2+k*3;
        ctx.beginPath();ctx.moveTo(HEART.x,HEART.y);
        for(let j=1;j<=4;j++){const u=j/4;ctx.lineTo(HEART.x+Math.cos(a+jitter(i*7+j)*.25)*len*u,HEART.y+Math.sin(a+jitter(i*7+j)*.25)*len*u);}
        ctx.stroke();
      }
      ctx.globalAlpha=(.25+hot*.35)*rise;
      if(!G.fx?.radial(ctx,HEART.x,HEART.y,190,[[0,P.glow],[1,'transparent']],10/190)){
        const g=ctx.createRadialGradient(HEART.x,HEART.y,10,HEART.x,HEART.y,190);g.addColorStop(0,P.glow);g.addColorStop(1,'transparent');
        ctx.fillStyle=g;ctx.fillRect(HEART.x-190,HEART.y-190,380,380);
      }
      ctx.restore();
    }
    function drawField(ctx){
      const P=R(),d=api.dying();
      if(d?.exploded)return;
      // Slam telegraph and hammer.
      if(slam){
        const t=G.time,pre=Math.min(1,(t-(slam.at-1.2))/1.2);
        if(!slam.hit){ctx.globalAlpha=.12+.18*pre+.1*Math.sin(t*20);ctx.fillStyle=P.ember;ctx.fillRect(slam.x-48,150,96,670);}
        const drop=slam.hit?1:pre**3,hy=-80+drop*(slam.hit?820:200);
        ctx.globalAlpha=slam.hit?Math.max(0,(slam.end-t)/.7):.9;ctx.fillStyle=P.iron;ctx.strokeStyle=P.ironEdge;ctx.lineWidth=3;
        ctx.fillRect(slam.x-58,hy-34,116,52);ctx.strokeRect(slam.x-58,hy-34,116,52);ctx.fillRect(slam.x-9,hy-150,18,118);
        if(slam.hit){ctx.globalAlpha*=.6;ctx.fillStyle=P.molten;ctx.fillRect(slam.x-48,150,96,670);}
      }
      drawHeart(ctx,P);
      // Meteors with trails; landing rings pulse where they will hit.
      for(let mi=0;mi<meteors.length;mi++){const m=meteors[mi],detailed=mi>=meteors.length-(G.reduced?8:24);
        if(G.time<m.born)continue;const p=meteorPos(m);
        ctx.globalAlpha=.5+.3*Math.sin(G.time*16);ctx.strokeStyle=P.ember;ctx.lineWidth=1.6;ctx.setLineDash([5,5]);ctx.beginPath();ctx.arc(m.x1,m.y1,22+8*(1-p.u),0,Math.PI*2);ctx.stroke();ctx.setLineDash([]);
        if(detailed){ctx.fillStyle=P.ember;
          for(let step=0;step<3;step++){ctx.globalAlpha=(step+1)/3*.7;ctx.beginPath();
            for(let i=0;i<m.trail.length;i++)if(Math.min(2,i/m.trail.length*3|0)===step){const q=m.trail[i],r=4+i*.8;ctx.moveTo(q.x+r,q.y);ctx.arc(q.x,q.y,r,0,Math.PI*2);}ctx.fill();
          }
        }
        ctx.globalAlpha=1;
        if(!G.fx?.radial(ctx,p.x,p.y,15,[[0,P.core],[.6,P.molten],[1,P.glow]],2/18)){
          const g=ctx.createRadialGradient(p.x,p.y,2,p.x,p.y,18);g.addColorStop(0,P.core);g.addColorStop(.5,P.molten);g.addColorStop(1,P.glow);
          ctx.fillStyle=g;ctx.beginPath();ctx.arc(p.x,p.y,15,0,Math.PI*2);ctx.fill();
        }
      }
      // Wind streaks.
      if(wind&&G.time>=wind.start-.9){
        const on=G.time>=wind.start,k=on?1:.35;ctx.strokeStyle=P.wind;ctx.lineWidth=1.4;
        for(let i=0;i<(G.reduced?6:16);i++){const y=180+i*47%660,x=((G.time*(on?520:160)*wind.dir+i*173)%900+900)%900-60;ctx.globalAlpha=(.25+.3*Math.sin(i))*k;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x-wind.dir*70,y+4);ctx.stroke();}
      }
      for(const e of embers){const u=(G.time-e.born)/.8;ctx.globalAlpha=(1-u)*.5;ctx.fillStyle=P.ember;ctx.beginPath();ctx.arc(e.x,e.y,20+u*60,0,Math.PI*2);ctx.fill();}
      if(palm)drawPalm(ctx,P);
      ctx.globalAlpha=1;
    }
    function drawHeart(ctx,P){
      const hot=overheated(),s=hurt&&!G.reduced?(Math.random()-.5)*hurt*5:0,x=HEART.x+s,y=HEART.y,pulse=1+.06*Math.sin(G.time*(hot?9:4));
      ctx.globalAlpha=1;
      if(!G.fx?.radial(ctx,x,y,HEART.r*pulse,[[0,P.core],[.45,hot?P.core:P.molten],[1,P.glow]],.06)){
        const g=ctx.createRadialGradient(x,y,3,x,y,HEART.r*pulse);g.addColorStop(0,P.core);g.addColorStop(.45,hot?P.core:P.molten);g.addColorStop(1,P.glow);
        ctx.fillStyle=g;ctx.beginPath();ctx.arc(x,y,HEART.r*pulse,0,Math.PI*2);ctx.fill();
      }
      ctx.beginPath();ctx.arc(x,y,HEART.r*pulse,0,Math.PI*2);
      ctx.strokeStyle=P.iron;ctx.lineWidth=3;ctx.stroke();
      // Rune ring and heat gauge.
      ctx.strokeStyle=P.ironEdge;ctx.lineWidth=1.2;ctx.globalAlpha=.8;
      for(let i=0;i<6;i++){const a=G.time*.6+i*Math.PI/3;ctx.beginPath();ctx.arc(x,y,HEART.r+8,a,a+.5);ctx.stroke();}
      const fill=hot?(overheatUntil-G.time)/6:heat()/100;
      ctx.globalAlpha=1;ctx.strokeStyle=hot?P.core:P.ember;ctx.lineWidth=4;ctx.lineCap='round';
      ctx.beginPath();ctx.arc(x,y,HEART.r+15,-Math.PI/2,-Math.PI/2+Math.PI*2*fill);ctx.stroke();
      if(hurt){ctx.globalAlpha=hurt*.6;ctx.fillStyle=P.core;ctx.beginPath();ctx.arc(x,y,HEART.r,0,Math.PI*2);ctx.fill();}
      ctx.globalAlpha=1;
    }
    function drawPalm(ctx,P){
      const down=G.time<palm.down,cracks=palm.hits,x=palm.x,y=PALM.y;
      if(down){ctx.globalAlpha=.25;ctx.setLineDash([4,6]);ctx.strokeStyle=P.ironEdge;ctx.lineWidth=1.5;ctx.strokeRect(x-PALM.half-PALM.r,y-PALM.r,PALM.half*2+PALM.r*2,PALM.r*2);ctx.setLineDash([]);return;}
      ctx.globalAlpha=1;ctx.fillStyle=P.iron;ctx.strokeStyle=palm.flash?P.molten:P.ironEdge;ctx.lineWidth=2.4;
      ctx.beginPath();
      if(typeof ctx.roundRect==='function')ctx.roundRect(x-PALM.half-PALM.r,y-PALM.r,PALM.half*2+PALM.r*2,PALM.r*2,PALM.r);
      else{
        // Same capsule, not a square-cornered rectangle on Chromium 89.
        ctx.moveTo(x-PALM.half,y-PALM.r);ctx.lineTo(x+PALM.half,y-PALM.r);
        ctx.arc(x+PALM.half,y,PALM.r,-Math.PI/2,Math.PI/2);
        ctx.lineTo(x-PALM.half,y+PALM.r);ctx.arc(x-PALM.half,y,PALM.r,Math.PI/2,Math.PI*1.5);ctx.closePath();
      }
      ctx.fill();ctx.stroke();
      ctx.lineWidth=1.4;for(let i=-2;i<=2;i++){ctx.beginPath();ctx.moveTo(x+i*20,y-PALM.r+3);ctx.lineTo(x+i*20,y+PALM.r-3);ctx.stroke();}
      ctx.strokeStyle=P.crack;ctx.lineWidth=1.6;
      for(let i=0;i<cracks;i++){const cx=x-40+i*27;ctx.beginPath();ctx.moveTo(cx,y-PALM.r);ctx.lineTo(cx+6,y-2);ctx.lineTo(cx-3,y+PALM.r);ctx.stroke();}
    }
    function drawFront(ctx){
      const d=api.dying();if(!d||d.exploded)return;
      const P=R(),k=Math.min(1,(G.time-d.at)/1.3);
      ctx.globalAlpha=.3+k*.5;
      if(!G.fx?.radial(ctx,HEART.x,HEART.y,120+k*500,[[0,P.core],[.4,P.molten],[1,'transparent']])){
        const g=ctx.createRadialGradient(HEART.x,HEART.y,5,HEART.x,HEART.y,120+k*500);g.addColorStop(0,P.core);g.addColorStop(.4,P.molten);g.addColorStop(1,'transparent');ctx.fillStyle=g;ctx.fillRect(0,0,780,G.H);
      }ctx.globalAlpha=1;
    }
    // Archived concept: keep manual entry and saved fights, but never deal it randomly.
    return {
      id:'forge',name:'熔炉巨像',title:'FORGE COLOSSUS',tagline:'',archived:true,
      kicker:'WARNING · FORGE',note:'',rageNote:'炉心暴走',hitLabel:'熔心命中',roar:'forge',
      seal:['FORGE EXTINGUISHED','熔炉巨像 · 熄灭',''],
      phaseNames:['点火','熔铸','暴走'],abilities,
      hp:phase=>Math.ceil(G.damage()*(24+6*phase)),
      mods:m=>({hp:1+.15*(m.phase-1),barriers:m.phase===api.phases()?7:4,decorate}),
      palette:()=>{const P=R();return {main:P.ember,hot:P.weak,light:P.core,text:P.text};},
      focus:()=>HEART,
      moving:()=>has('palm')||!!wind,
      status:()=>overheated()?{text:'过热 · 伤害 ×2',state:'exposed'}:{text:`炉温 ${Math.round(heat())}%`,state:'shielded'},
      init:data=>{data.heat=0;},
      validate:data=>typeof data.heat==='number'&&data.heat>=0&&data.heat<=100,
      hydrate(){palm=has('palm')?{x:390,hits:0,down:0,flash:0}:null;arm();},
      intro(){arm(G.time+2.6);},
      shifted(){arm();palm=has('palm')?{x:390,hits:0,down:0,flash:0}:null;},
      charging(t){const P=R();hurt=.8;if(Math.random()<.4)G.burst(HEART.x+(Math.random()-.5)*80,HEART.y+(Math.random()-.5)*80,Math.random()<.5?P.ember:P.molten,4,1.6);},
      pending:()=>!!slam&&!slam.hit,
      calm:clearFx,reset(){clearFx();palm=null;},
      contact,physics,destroyed,pre,post,drawBack,drawField,drawFront,
      debug:()=>({heat:heat(),overheated:overheated(),meteors:meteors.length,slam:!!slam,wind:wind?wind.dir:0,palm:palm?{x:palm.x,down:G.time<palm.down,hits:palm.hits}:null})
    };
  });
})();
