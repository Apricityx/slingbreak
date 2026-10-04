const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const Matter=require('./vendor/matter.min.js');
const BOSS_FILES=['game.js','skills.js',...['eye','forge','serpent','clock'].filter(id=>fs.existsSync(__dirname+`/boss-${id}.js`)).map(id=>`boss-${id}.js`),'milestone.js'];
function boot(saved,{files=BOSS_FILES,seed=4242,search='',reduced=true}={}){
  let storage=saved?JSON.stringify(saved):null;
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const context={Matter,Math:math,console,window:{},URLSearchParams,location:{search},matchMedia:()=>({matches:reduced}),localStorage:{getItem:()=>storage,setItem:(k,v)=>storage=v},document:{getElementById:()=>({})}};
  vm.createContext(context);for(const file of files)vm.runInContext(fs.readFileSync(__dirname+'/'+file,'utf8'),context);
  const G=context.window.Game;G.burst=G.float=G.ring=()=>{};G.toasts=[];G.toast=t=>G.toasts.push(t);return{G,read:()=>JSON.parse(storage)};
}
const save=(level,boss='eye')=>({level,coins:0,total:0,best:0,comboRulesVersion:2,legacyBest:0,up:{power:0,arrow:0,brick:0,comboCap:0,slots:3},sound:true,board:null,skills:{titan:1},skillScopeVersion:3,skillChosenLevel:level,draft:null,skillRuntime:null,skillGateVersion:1,bossDeck:[boss]});
const run=(G,seconds)=>{for(let i=0;i<Math.round(seconds*60);i++)G.tick(1/60);};
// A boss fight with fixed abilities whose intro has already played.
function fight(abilities=[['tear'],['summon','gaze'],['doom','mirage']],saved=save(100)){
  const session=boot(saved),{G}=session;
  G.bossDefs.eye.resist={grace:1e9,burst:1e9};
  G.boss().abilities=abilities;G.state.board=null;G.generate();
  run(G,.6);assert.ok(G.boss().intro,'intro starts once the board is ready');
  return session;
}
const remove=(G,keep=()=>false)=>{for(const b of G.bricks.filter(b=>!keep(b)))Matter.Composite.remove(G.engine.world,b.body);G.bricks=G.bricks.filter(keep);};
const clearLane=G=>{remove(G,b=>b.type==='anchor');for(const o of G.obstacles)Matter.Composite.remove(G.engine.world,o.body);G.obstacles=[];};
// Unlike a no-op canvas mock, this records the state that actually affects
// later drawing: nested transforms and clips must both survive save/restore.
function eyeCanvas(){
  let state={x:17,y:29,sx:1.5,sy:1.5,clips:0};
  const stack=[],calls=[],point=(x,y)=>({x:state.x+x*state.sx,y:state.y+y*state.sy});
  const ctx=new Proxy({
    save(){stack.push({...state});},
    restore(){assert.ok(stack.length,'restore must have a matching save');state=stack.pop();},
    translate(x,y){state.x+=x*state.sx;state.y+=y*state.sy;},
    clip(){state.clips++;},
    createRadialGradient(){return {addColorStop(){}};},
    createLinearGradient(){return {addColorStop(){}};},
  },{
    get(target,key){
      if(key in target)return target[key];
      if(key in state)return state[key];
      return (...args)=>calls.push({method:key,args,at:point(args[0],args[1]),clips:state.clips});
    },
    set(target,key,value){state[key]=value;return true;}
  });
  return {ctx,calls,stack,point,state:()=>({...state})};
}

for(const mode of ['closed','open','gaze','doom','mirage','dazed','shifted','dying']){
  test(`eye: ${mode} rendering keeps the eye, effects and subsequent sling in their own coordinates`,()=>{
    const {G}=fight(),def=G.bossDefs.eye;
    if(mode!=='closed')run(G,2);
    if(['gaze','doom','mirage'].includes(mode)){assert.ok(def.start(mode));run(G,1);}
    if(mode==='dazed'){G.boss().data.ward=40;G.bricks.filter(b=>b.type==='anchor').forEach(b=>G.hit(b,1e9));assert.ok(G.riftState().dazed);}
    if(mode==='shifted')def.shifted();
    if(mode==='dying'){G.boss().phase=3;finishPhase(G);assert.ok(G.riftState().dying);}
    const {ctx,calls,stack,point,state}=eyeCanvas(),before=state();
    for(let frame=0;frame<3;frame++){
      calls.length=0;
      // Match render.js's field hook, then the sling drawn later in the frame.
      G.drawSkillEffects(ctx,'field');
      assert.equal(stack.length,0,'eye must not leak a saved canvas state');
      assert.deepEqual(state(),before,'field wrapper restores transforms, clipping and brushes');
      const eyeCalls=calls.filter(c=>c.method==='ellipse'&&c.args[0]===0&&c.args[1]===0);
      if(mode!=='closed'){
        const eyes=mode==='mirage'?G.riftState().eyes:[G.riftEye];
        assert.equal(eyeCalls.length,eyes.length,'every eye has its own glow');
        eyes.forEach((eye,i)=>{
          assert.deepEqual(eyeCalls[i].at,point(eye.x,eye.y+(mode==='dazed'?6:0)),'eye glow is at its world position');
          assert.equal(eyeCalls[i].clips,0,'eye is not clipped by a previous eye');
          const outlines=calls.filter(c=>c.method==='moveTo'&&c.args[0]===-G.riftEye.r*(mode==='mirage'?.8:1)*1.55&&c.args[1]===0);
          const outline=outlines[i*2+1].at,expected=point(eye.x-G.riftEye.r*(mode==='mirage'?.8:1)*1.55,eye.y+(mode==='dazed'?6:0));
          assert.ok(Math.hypot(outline.x-expected.x,outline.y-expected.y)<1e-9,'outline aligns with the eye');
          if(!['dazed','dying','shifted'].includes(mode))assert.ok(calls.some(c=>c.method==='arc'&&c.at.x===point(eye.x,eye.y).x&&c.at.y===point(eye.x,eye.y).y&&c.clips===0),'ward is centred on the eye and not iris-clipped');
        });
      }
      ctx.arc(G.origin.x,G.origin.y,48,0,Math.PI*2);
      assert.deepEqual(calls.at(-1).at,point(G.origin.x,G.origin.y),'sling retains its world position');
      assert.equal(calls.at(-1).clips,0,'eye clip cannot hide the sling');
    }
  });
}
// Fires straight up at the eye and returns the arrow once it has bounced.
function fire(G){G.phase='flying';const a=G.addArrow(G.riftEye.x,420,0,-22);for(let i=0;i<60&&a.body.velocity.y<0;i++)G.tick(1/60);return a;}

test('only every 100th level is a boss fight; normal levels keep the core',()=>{
  const {G}=boot(save(99));
  assert.equal(G.boss(),null);assert.ok(!G.state.milestone);
  for(const level of [1,99,101,150])assert.equal(G.isRiftLevel(level),false);
  for(const level of [100,200,1000])assert.equal(G.isRiftLevel(level),true);
  G.bricks.forEach(b=>b.type='normal');for(let i=0;i<99&&!G.core;i++)G.hit(G.bricks[0],1e9);assert.ok(G.core,'level 99 still raises its core');
});

test('a boss level has no core, a shielded eye with chain anchors and three rolled phases',()=>{
  const {G}=boot(save(100)),m=G.boss();
  assert.ok(m);assert.equal(m.phase,1);assert.equal(m.abilities.length,3);
  assert.equal(new Set(m.abilities.flat()).size,m.abilities.flat().length,'no ability repeats across phases');
  assert.equal(G.bricks.filter(b=>b.type==='anchor').length,2);assert.ok(G.riftState().shielded);
  assert.ok(G.bricks.some(b=>b.type==='void')&&G.bricks.some(b=>b.type==='hydra'));
  G.bricks.filter(b=>b.type!=='anchor').slice(0,50).forEach(b=>G.hit(b,1e9,80));
  assert.equal(G.core,null,'killing bricks never raises a core');
  G.clear();assert.equal(G.state.level,100,'a stray clear cannot skip the fight');
});

test('the ward turns every arrow; chain anchors drain it, and an empty ward dazes the eye for ×3',()=>{
  const {G}=fight(),m=G.boss(),rs=()=>G.riftState();clearLane(G);
  const hp=m.hp,a=fire(G);
  assert.ok(a.body.velocity.y>0,'the ward bounces the arrow');assert.equal(m.hp,hp);assert.ok(G.toasts.length,'one hint');
  const anchor=G.bricks.find(b=>b.type==='anchor'),w0=rs().ward;
  G.withArrow(G.addArrow(100,1200,0,0),()=>G.hit(anchor,.01));assert.ok(rs().ward<=w0-8+1e-6,'an anchor hit drains the ward');
  m.data.ward=40;G.bricks.filter(b=>b.type==='anchor').forEach(b=>G.hit(b,1e9));
  assert.ok(rs().dazed,'two broken chains empty it');assert.equal(rs().ward,0);assert.equal(rs().shielded,false);
  const before=m.hp,coins=G.state.coins,b=fire(G);
  assert.ok(Math.abs(before-m.hp-b.damage*3)<1e-6,'×3 on the dazed eye');assert.ok(G.state.coins>coins);assert.equal(m.hits,1);
});
test('after a daze the ward reforms and the chains lash onto fresh bricks',()=>{
  const {G}=fight(),m=G.boss(),rs=()=>G.riftState(),def=G.bossDefs.eye;
  m.data.ward=40;G.bricks.filter(b=>b.type==='anchor').forEach(b=>G.hit(b,1e9));assert.equal(rs().anchors,0);assert.ok(rs().dazed);
  run(G,4.1);assert.ok(!rs().dazed);assert.ok(rs().mend,'the ward re-forms');assert.equal(rs().anchors,2,'new chains');assert.equal(rs().move,null);
  run(G,1.3);assert.equal(rs().ward,100);assert.ok(!rs().mend);assert.equal(def.status().text,'结界 100% · 锁链 2');
});
test('the ward mends itself, faster while chains hold, and survives a reload',()=>{
  const {G,read}=fight(),m=G.boss();m.data.ward=40;run(G,2);
  const held=G.riftState().ward;assert.ok(held>=40+2*4.5-.2&&held<=40+2*4.5+.2,`ward ${held}`);
  G.save();assert.ok(Math.abs(boot(read()).G.riftState().ward-held)<1e-9);
  remove(G,b=>b.type!=='anchor');m.data.ward=40;run(G,2);assert.ok(Math.abs(G.riftState().ward-43)<.2,'no chains: slow');
});

test('aim prediction bends around the eye exactly like the live arrow',()=>{
  const {G}=fight();clearLane(G);
  const path=G.predictPath(390,970,-1.2,-26,1800);
  G.phase='flying';const a=G.addArrow(390,970,-1.2,-26);let bounced=false;
  for(const p of path.slice(1)){
    G.tick(G.physicsStep);if(!G.arrows.includes(a))break;
    assert.ok(Math.hypot(p.x-a.body.position.x,p.y-a.body.position.y)<1e-6);if(a.body.velocity.y>0)bounced=true;
  }
  assert.ok(bounced,'scenario must hit the shield');
});

test('emptying a phase rebuilds the board; the last phase collapses into a triple-bonus clear',()=>{
  const {G}=fight(),m=G.boss();
  for(const phase of [1,2]){G.phase='flying';G.addArrow(100,1200,0,0);finishPhase(G);assert.equal(m.phase,phase+1);assert.equal(G.state.level,100);assert.ok(G.bricks.length>=40);assert.equal(G.arrows.length,0);run(G,1.4);}
  assert.equal(G.bricks.filter(b=>b.type==='anchor').length,3);
  assert.ok(G.obstacles.length>=5,'phase three brings back barriers');
  const bonus=G.bonus(),plain=boot(save(100),{files:['game.js']}).G.bonus(100);assert.equal(bonus,plain*3);
  finishPhase(G);
  assert.ok(G.riftState().dying);assert.equal(G.shoot(0,100),false,'no shots during the collapse');
  const coins=G.state.coins;
  for(let i=0;i<600&&G.state.level===100;i++)G.tick(1/60);
  assert.equal(G.state.level,101);assert.equal(G.state.milestone,null);assert.ok(G.state.coins-coins>=bonus);
});

test('a hydra brick splits into two 40-wide halves after it breaks',()=>{
  const {G}=fight();const h=G.bricks.find(b=>b.type==='hydra'&&b.w>=60);assert.ok(h);
  const {x,y,max}=h,before=G.bricks.length;G.hit(h,1e9);assert.equal(G.bricks.length,before-1);
  run(G,.4);const kids=G.bricks.filter(b=>b.y===y&&Math.abs(Math.abs(b.x-x)-22)<1e-6);
  assert.equal(kids.length,2);assert.ok(kids.every(b=>b.w===40&&b.hp===Math.ceil(max*.5)||b.w===40));
});

test('a void well keeps the volley flying, grinds nearby bricks and then closes',()=>{
  const {G}=fight();const v=G.bricks.find(b=>b.type==='void');assert.ok(v);
  for(const b of G.bricks)if(b!==v){b.type='normal';b.hp=b.max=1e12;}
  const near=G.bricks.filter(b=>b!==v&&Math.hypot(b.x-v.x,b.y-v.y)<110),hp=near.map(b=>b.hp);assert.ok(near.length);
  G.phase='flying';G.hit(v,1e9);assert.equal(G.riftState().wells,1);
  run(G,1);assert.equal(G.phase,'flying','an open well holds the volley');
  assert.ok(near.some((b,i)=>b.hp<hp[i]),'the well grinds bricks');
  run(G,3);assert.notEqual(G.phase,'flying');
});

test('chain anchors stay breakable for low-damage builds in every phase',()=>{
  const {G}=fight(),m=G.boss();G.damage=()=>1;
  for(const phase of [1,2]){finishPhase(G);assert.equal(m.phase,phase+1);run(G,1.4);
    const anchors=G.bricks.filter(b=>b.type==='anchor');assert.ok(anchors.length&&anchors.every(b=>b.max<=3+m.phase),`phase ${m.phase} anchors need at most ${3+m.phase} hits`);}
});
// ── Eye moves.
const clearAll=G=>{remove(G);for(const o of G.obstacles)Matter.Composite.remove(G.engine.world,o.body);G.obstacles=[];};
const shot=(G,x,y,vx,vy,ticks=6)=>{G.arrows.forEach(a=>Matter.Composite.remove(G.engine.world,a.body));G.arrows=[];G.phase='flying';const a=G.addArrow(x,y,vx,vy);for(let i=0;i<ticks;i++)G.tick(1/60);return a;};
const ers=G=>G.riftState();
test('eye: phase one opens with a target move; the last phase always adds doom',()=>{
  for(const seed of [1,7,99,4242]){
    const m=boot(save(100),{seed}).G.boss(),[a,b,c]=m.abilities;
    assert.equal(a.length,1);assert.ok(['orbit','summon','tear'].includes(a[0]));
    assert.equal(b.length,2);assert.equal(c[0],'doom');assert.equal(new Set(m.abilities.flat()).size,5);
  }
});
test('eye: one move at a time, on its own clock after the intro',()=>{
  const {G}=fight();assert.equal(ers(G).move,null);
  run(G,5);assert.equal(ers(G).move,'tear','the phase-one move opens');
  assert.equal(G.bossDefs.eye.start('orbit'),false,'a second move cannot start over the first');
});
test('eye: breaking the glowing heart of the crystal ring dazes the eye; left alone the shards land as bricks',()=>{
  const ORBIT=[['orbit'],['summon','gaze'],['doom','mirage']],{G}=fight(ORBIT);
  assert.ok(G.bossDefs.eye.start('orbit'));const shards=G.bricks.filter(b=>b.orbit);assert.equal(shards.length,6);assert.equal(shards.filter(b=>b.heart).length,1);
  const x=shards[0].x;run(G,.5);assert.notEqual(shards[0].x,x,'the ring turns');
  G.withArrow(G.addArrow(100,1200,0,0),()=>G.hit(shards.find(b=>b.heart),1e9));
  assert.ok(ers(G).dazed,'the heart breaks the ward');assert.equal(ers(G).move,null);run(G,.1);assert.equal(G.bricks.filter(b=>b.orbit).length,0,'the ring bursts');
  const miss=fight(ORBIT).G;remove(miss,b=>b.type==='anchor');miss.boss().data.ward=20;
  miss.bossDefs.eye.start('orbit');const n=miss.bricks.length;run(miss,8.8);
  assert.equal(ers(miss).move,null);assert.equal(miss.bricks.filter(b=>b.orbit).length,0);
  assert.ok(miss.bricks.length>=n-6+5,'shards land as bricks');assert.ok(ers(miss).ward>=55,'and mend the ward');
});
test('eye: shooting the sigil before it opens dazes the eye; an open sigil pours out bricks',()=>{
  const {G}=fight();clearAll(G);
  assert.ok(G.bossDefs.eye.start('summon'));const s=ers(G).sigil;assert.ok(s&&s.y>=500);
  shot(G,s.x,s.y+40,0,-14);assert.ok(ers(G).dazed,'broken');assert.equal(ers(G).move,null);
  const miss=fight().G;clearAll(miss);miss.bossDefs.eye.start('summon');run(miss,4.6);
  assert.equal(ers(miss).move,null);assert.ok(miss.bricks.length>=5,'bricks pour out');
});
test('eye: a falling tear shot down dazes the eye; one that lands shatters into bricks',()=>{
  const {G}=fight();clearAll(G);
  G.bossDefs.eye.start('tear');run(G,1.6);const t=ers(G).tear;assert.ok(t.y>200&&t.y<800,`tear at ${t.y}`);
  shot(G,t.x,t.y+80,0,-14);assert.ok(ers(G).dazed,'shot down');
  const miss=fight().G;clearAll(miss);miss.bossDefs.eye.start('tear');run(miss,4.2);
  assert.equal(ers(miss).move,null);assert.ok(miss.bricks.length>=4,'it shatters into bricks');
});
test('eye: during the gaze an arrow along the beam slips through the notch; unanswered, the beam sprouts bricks',()=>{
  const {G}=fight();clearAll(G);
  G.bossDefs.eye.start('gaze');run(G,1.5);const a=ers(G).beam;
  shot(G,390+Math.cos(a)*120,92+Math.sin(a)*120,-Math.cos(a)*14,-Math.sin(a)*14,8);assert.ok(ers(G).dazed,'through the notch');
  const off=fight().G;clearAll(off);off.bossDefs.eye.start('gaze');run(off,1.5);const b=ers(off).beam+1.2;
  shot(off,390+Math.cos(b)*120,92+Math.sin(b)*120,-Math.cos(b)*14,-Math.sin(b)*14,8);assert.ok(!ers(off).dazed,'off the beam the ward holds');
  const miss=fight().G;remove(miss,b=>b.type==='anchor');miss.boss().data.ward=20;miss.bossDefs.eye.start('gaze');const n=miss.bricks.length;run(miss,5.8);
  assert.equal(ers(miss).move,null);const made=miss.bricks.length-n;assert.ok(made>=1&&made<=4,`gaze made ${made}`);assert.ok(ers(miss).ward>=50);
});
test('eye: of two mirage eyes only the real one dazes; a fake just bursts; unanswered, the fake beams in bricks',()=>{
  const {G}=fight();clearAll(G);
  G.bossDefs.eye.start('mirage');run(G,1);assert.equal(ers(G).eyes.length,2);
  const fake=ers(G).eyes.find(e=>!e.real);shot(G,fake.x,fake.y+80,0,-14);assert.equal(ers(G).eyes.length,1);assert.ok(!ers(G).dazed);
  const real=ers(G).eyes.find(e=>e.real);assert.equal(G.riftEye.x,real.x,'the real eye carries the collider');
  run(G,.2);shot(G,real.x,real.y+80,0,-14);assert.ok(ers(G).dazed,'seen through');
  const miss=fight().G;clearAll(miss);miss.bossDefs.eye.start('mirage');run(miss,7.4);
  assert.equal(ers(miss).move,null);assert.ok(miss.bricks.length>=2,'the fake beams in bricks');
});
test('eye: three pupil hits while doom charges daze it for longer; unanswered, the chains regrow and the ward fills',()=>{
  const {G}=fight();clearAll(G);
  G.bossDefs.eye.start('doom');run(G,1);
  for(let i=0;i<3;i++){shot(G,390,192,0,-14);run(G,.2);}
  assert.ok(ers(G).dazed,'three hits');run(G,4.9);assert.ok(ers(G).dazed,'a longer daze');
  const miss=fight().G;miss.bricks.filter(b=>b.type==='anchor').forEach(b=>miss.hit(b,1e9));assert.equal(ers(miss).anchors,0);
  miss.bossDefs.eye.start('doom');run(miss,6);assert.equal(ers(miss).move,null);assert.equal(ers(miss).anchors,2);assert.equal(ers(miss).ward,100);
});
test('eye: from phase two, watcher eyes drain the ward only while open; blinding all three dazes the eye',()=>{
  const {G}=fight();finishPhase(G);run(G,1.4);clearAll(G);
  const ws=G.bossDefs.eye.watchers();assert.equal(ws.length,3);
  const w=ws[0];w.t0=G.time-1.56;shot(G,w.x,w.y+60,0,-14);assert.ok(!w.blind,'a shut eye deflects');assert.equal(ers(G).ward,100);
  for(const t of ws){t.t0=G.time;shot(G,t.x,t.y+60,0,-14);assert.ok(t.blind,`watcher ${t.i} blinded`);if(t!==ws.at(-1))assert.ok(!ers(G).dazed);}
  assert.ok(ers(G).dazed,'three blind watchers daze the eye');
  run(G,5.5);assert.ok(ws.every(t=>!t.blind),'they reopen after the mend');
});
test('eye: phase three alternates its move with doom',()=>{
  const {G}=fight();finishPhase(G);run(G,1.4);finishPhase(G);assert.equal(G.boss().phase,3);
  const seen=[];for(let i=0;i<60*40;i++){G.tick(1/60);const id=ers(G).move;if(id&&id!==seen.at(-1))seen.push(id);}
  assert.equal(seen[0],'mirage');assert.ok(seen.length>=3);
  seen.forEach((id,i)=>assert.equal(id,i%2?'doom':'mirage'));
});

test('reloading mid-fight keeps phase, eye hp and board, and skips the intro',()=>{
  const {G,read}=fight(),m=G.boss();finishPhase(G);
  assert.equal(m.phase,2);G.bricks.find(b=>b.type==='anchor').hp=7;m.hp=33;G.save();
  const saved=read(),next=boot(saved).G,n=next.boss();
  assert.equal(n.phase,2);assert.equal(n.hp,33);assert.equal(n.intro,true);
  assert.equal(next.bricks.length,saved.board.bricks.length);assert.ok(next.bricks.some(b=>b.type==='anchor'&&b.hp===7));
  next.tick(1/60);assert.equal(next.phase,'ready','no second intro lock after a reload');
});

test('a full reset throws the fight away',()=>{
  const {G}=fight();G.reset?.();assert.equal(G.state.level,1);assert.equal(G.boss(),null);
});

for(const id of ['eye','forge','serpent','clock'])test(`?boss=${id} settles level 12 and replaces level 13 without consuming the deck`,()=>{
  const saved={...save(12),coins:2048,total:27,bossDeck:['clock','forge'],lastBoss:'serpent'};
  const {G,read}=boot(saved,{search:`?boss=${id}`});
  assert.equal(G.state.level,13);
  assert.equal(G.phase,'clearing');
  const coins=2048+G.bonus(12);
  assert.equal(G.state.coins,coins);
  assert.equal(read().bossOverride.level,13);
  assert.equal(read().bossOverride.boss,id);
  run(G,3);
  assert.equal(G.boss().boss,id);
  assert.equal(G.boss().phase,1);
  assert.equal(G.boss().hp,G.boss().max);
  assert.equal(G.phase,'ready');
  assert.equal(G.state.draft,null);
  assert.equal(G.state.coins,coins);
  assert.equal(G.state.total,27);
  assert.equal(G.state.skills.titan,1);
  assert.equal(G.state.up.slots,3);
  assert.deepEqual(Array.from(G.state.bossDeck),saved.bossDeck);
  assert.equal(G.state.lastBoss,'serpent');
  assert.equal(G.core,null);
  assert.equal(G.threshold,Infinity);
  assert.equal(read().milestone.boss,id);
  assert.equal(read().board.level,13);
  assert.equal(G.isRiftLevel(13),true);
  run(G,.6);assert.ok(G.boss().intro);
  G.boss().hp-=1;G.save();
  const next=boot(read(),{search:`?boss=${id}`}).G;
  assert.equal(next.state.level,13,'reload resumes the requested fight without advancing again');
  assert.equal(next.state.coins,coins);
  assert.equal(next.boss().hp,G.boss().hp);
  assert.equal(next.boss().intro,true);
});

test('invalid boss IDs fall back to the saved level without creating a fight',()=>{
  for(const id of ['', 'missing', 'constructor', '__proto__', 'Eye']){
    const {G}=boot(save(12),{search:`?boss=${id}`});
    assert.equal(G.state.level,12);
    assert.equal(G.boss(),null);
    assert.equal(G.enterBoss(id),false);
  }
});

test('reloading during settlement keeps the replacement and never pays the clear twice',()=>{
  const {G,read}=boot({...save(37),coins:600},{search:'?boss=eye'});
  assert.equal(G.phase,'clearing');
  const saved=read(),next=boot(saved,{search:'?boss=eye'}).G;
  assert.equal(next.state.level,38);
  assert.equal(next.state.coins,saved.coins);
  assert.equal(next.boss().boss,'eye');
  assert.equal(next.boss().phase,1);
  assert.equal(next.phase,'ready');
  const withoutQuery=boot(saved).G;
  assert.equal(withoutQuery.boss().boss,'eye','the saved replacement also resumes without the URL flag');
});

test('a replaced boss level clears with the boss bonus and then returns to ordinary progression',()=>{
  const {G}=boot(save(12),{search:'?boss=clock'});
  run(G,3);
  const bonus=G.bonus(),plain=boot(save(13),{files:['game.js']}).G.bonus();
  assert.equal(bonus,plain*3);
  const n=G.bossApi.phases();
  for(let phase=1;phase<n;phase++){G.boss().hp=0;run(G,.05);run(G,1.4);}
  const coins=G.state.coins;
  G.boss().hp=0;run(G,.05);
  for(let i=0;i<600&&G.state.level===13;i++)G.tick(1/60);
  assert.equal(G.state.level,14);
  assert.ok(G.state.coins-coins>=bonus);
  run(G,3);
  assert.equal(G.boss(),null);
  assert.equal(G.state.bossOverride,null);
  assert.equal(G.isRiftLevel(14),false);
  assert.equal(G.phase,'draft','subsequent normal levels use the usual draft');
});

test('replacement at a natural milestone honors the requested boss and leaves the deck intact',()=>{
  const {G}=boot(save(99,'forge'),{search:'?boss=eye'});
  run(G,3);
  assert.equal(G.state.level,100);
  assert.equal(G.boss().boss,'eye');
  assert.deepEqual(Array.from(G.state.bossDeck),['forge']);
  G.reset();
  assert.equal(G.state.level,1);
  assert.equal(G.state.bossOverride,null);
  assert.equal(G.boss(),null);
});

test('direct boss entry clears phase locks, effects and gravity but refuses active or paused rounds',()=>{
  const {G}=bossFight('forge',[['bellows'],['meteor','slam'],['palm','magma']]);
  for(const phase of ['flying','entering','clearing']){
    G.phase=phase;assert.equal(G.enterBoss('clock'),false);assert.equal(G.boss().boss,'forge');
  }
  G.phase='ready';G.paused=true;
  assert.equal(G.enterBoss('clock'),false);
  G.paused=false;G.boss().hp=0;run(G,.05);
  assert.equal(G.boss().phase,2,'old fight has an active shift lock');
  G.engine.gravity.x=.4;
  const coins=G.state.coins,bonus=G.bonus();
  assert.equal(G.enterBoss('clock'),true);
  assert.equal(G.state.coins,coins+bonus,'settling an existing boss preserves its triple bonus');
  assert.equal(G.engine.gravity.x,0);
  assert.equal(G.state.level,101);
  assert.equal(G.phase,'clearing');
  run(G,3);
  assert.equal(G.boss().phase,1);
  assert.equal(G.riftState().spawns,0);
  run(G,.6);
  assert.equal(G.shoot(0,100),true,'old shift lock must not carry over');
});

// ── Boss deck and the other bosses.
function bossFight(id,abilities){
  const session=boot({...save(100,id),bossOverride:{level:100,boss:id}}),{G}=session;
  if(abilities){G.boss().abilities=abilities;G.state.board=null;G.generate();}
  run(G,.6);assert.ok(G.boss().intro);assert.equal(G.boss().boss,id);return session;
}
const killAll=G=>[...G.bricks].forEach(b=>G.hit(b,1e9));
function finishPhase(G){const m=G.boss();m.hp=0;run(G,.05);}

for(const id of ['eye','forge','serpent','clock'])for(const reduced of [true,false])test(`${id}: the ${reduced?'reduced-motion':'animated'} intro has no heavy roar or explosion, but phase shifts keep their effects`,()=>{
  const {G}=boot({...save(100,id),bossOverride:{level:100,boss:id}},{reduced}),sounds=[];
  G.sound=(type)=>sounds.push(type);G.bossApi.freeze=()=>{};
  run(G,3);
  assert.ok(G.boss().intro);assert.ok(!sounds.includes(G.bossDefs[id].roar),'no opening roar');assert.ok(!sounds.includes('boom'),'no opening explosion');
  sounds.length=0;finishPhase(G);
  assert.ok(sounds.includes('boom'));assert.ok(sounds.includes(G.bossDefs[id].roar),'combat and phase transition effects are not globally muted');
});

test('every hundredth level deals the next boss from a shuffled deck; all three active bosses appear before any repeats',()=>{
  const {G}=boot({...save(99),bossDeck:undefined}),seen=[];
  for(let i=0;i<12;i++){
    G.state.level=(i+1)*100;G.state.milestone=null;G.state.board=null;G.generate();seen.push(G.boss().boss);
  }
  assert.ok(!seen.includes('forge'),'archived forge is never dealt');
  for(let i=0;i<seen.length;i+=3){
    assert.deepEqual([...new Set(seen.slice(i,i+3))].sort(),['clock','eye','serpent']);
    if(i)assert.notEqual(seen[i-1],seen[i],'a new pass never opens with the boss that closed the last one');
  }
});

test('old boss decks skip archived forge while keeping the remaining order',()=>{
  const {G}=boot({...save(100),bossDeck:['forge','serpent','forge','clock','missing']});
  assert.equal(G.bossDefs.forge.archived,true);
  assert.equal(G.boss().boss,'serpent');
  assert.deepEqual(Array.from(G.state.bossDeck),['clock']);
  const next=boot(save(100,'forge')).G;
  assert.notEqual(next.boss().boss,'forge','a deck containing only forge refills from active bosses');
  assert.ok(!next.state.bossDeck.includes('forge'));
});

test('an archived forge fight already in progress still resumes without a manual override',()=>{
  const {G:first,read}=bossFight('forge');
  first.boss().hp-=1;first.save();
  const saved=read();saved.bossOverride=null;
  const {G}=boot(saved);
  assert.equal(G.boss().boss,'forge');
  assert.equal(G.boss().hp,first.boss().hp);
  assert.equal(G.boss().intro,true);
});

test('an old single-boss save migrates to the eye',()=>{
  const {G:first}=boot(save(100)),m=first.state.milestone,old={...m,v:2,ring:6};delete old.boss;delete old.data;
  const {G}=boot({...save(100),milestone:old});assert.equal(G.boss().boss,'eye');assert.equal(G.boss().data.ring,6);
});

for(const id of ['forge','serpent','clock'])test(`${id}: every phase ends in a collapse and a triple-bonus clear`,()=>{
  const {G}=bossFight(id);
  if(!G.bossDefs[id])return;
  const n=G.bossDefs[id].phases||3;assert.equal(G.bossApi.phases(),n);
  for(let phase=1;phase<n;phase++){finishPhase(G);assert.equal(G.boss().phase,phase+1);assert.ok(G.bricks.length>=30);run(G,1.4);}
  const coins=G.state.coins;finishPhase(G);assert.ok(G.riftState().dying);
  for(let i=0;i<600&&G.state.level===100;i++)G.tick(1/60);
  assert.equal(G.state.level,101);assert.ok(G.state.coins-coins>=G.bonus(100));
  assert.deepEqual({x:G.engine.gravity.x,y:G.engine.gravity.y},{x:0,y:.48},'gravity restored');
});

test('forge: iron plates frame the heart; a clear lane lets arrows strike it for triple damage',()=>{
  const {G}=bossFight('forge',[['meteor'],['slam','bellows'],['palm','magma']]),m=G.boss();
  const plates=G.bricks.filter(b=>b.type==='plate');assert.equal(plates.length,8);
  assert.ok(plates.every(b=>Math.abs(b.x-390)<=96&&Math.abs(b.y-470)<=60));
  assert.ok(!G.bricks.some(b=>b.x===390&&b.y===470),'the heart cell is empty');
  remove(G);G.obstacles.forEach(o=>Matter.Composite.remove(G.engine.world,o.body));G.obstacles=[];
  const hp=m.hp,coins=G.state.coins;G.phase='flying';const a=G.addArrow(390,700,0,-22);run(G,.5);
  assert.ok(hp-m.hp>=a.damage*3-1e-9,'heart hit deals triple damage');assert.ok(G.state.coins>coins);assert.equal(m.hits,1);
});

test('forge: broken bricks chip the boss and stoke heat; full heat overheats',()=>{
  const {G}=bossFight('forge',[['meteor'],['slam','bellows'],['palm','magma']]),m=G.boss(),hp=m.hp;
  G.hit(G.bricks.find(b=>b.type==='plate'),1e9);assert.ok(m.hp<hp);assert.ok(G.riftState().heat>0);
  m.data.heat=99;G.hit(G.bricks.find(b=>b.type==='normal'),1e9);assert.ok(G.riftState().overheated);
  const n=G.bricks.find(b=>b.type==='normal'&&G.bricks.some(t=>t!==b&&Math.hypot(t.x-b.x,t.y-b.y)<100));
  const near=G.bricks.filter(t=>t!==n&&Math.hypot(t.x-n.x,t.y-n.y)<100),before=near.map(t=>t.hp);
  G.hit(n,1e9);assert.ok(near.some((t,i)=>!G.bricks.includes(t)||t.hp<before[i]),'overheat breaks blast neighbours');
});

test('forge: meteors land as magma bricks and can be shot down for gold',()=>{
  const {G}=bossFight('forge',[['meteor'],['slam','bellows'],['palm','magma']]);
  const magma=()=>G.bricks.filter(b=>b.type==='magma').length,before=magma();
  run(G,5.4);assert.ok(G.riftState().meteors>0,'meteors launched');run(G,2.5);
  assert.ok(magma()>before,'landed meteors make magma');
});

test('forge: the hammer forges surviving bricks in its column into iron plates',()=>{
  const {G}=bossFight('forge',[['slam'],['meteor','bellows'],['palm','magma']]);
  G.bricks.forEach(b=>{if(b.type!=='plate'){b.type='normal';b.hp=b.max=1e6;}});
  run(G,7.6);assert.ok(G.riftState().slam,'slam telegraphed');run(G,1.5);
  const cols=[102,198,294,390,486,582,678].filter(x=>G.bricks.filter(b=>b.x===x).every(b=>b.type==='plate'));
  assert.ok(cols.length>=1,'one whole column became plates');
});

test('forge: bellows bends gravity sideways for a few seconds, then restores it',()=>{
  const {G}=bossFight('forge',[['bellows'],['meteor','slam'],['palm','magma']]);
  let peak=0;for(let i=0;i<60*8;i++){G.tick(1/60);peak=Math.max(peak,Math.abs(G.engine.gravity.x));}
  assert.ok(peak>.2);run(G,4);assert.equal(G.engine.gravity.x,0);
});

test('forge: the stone palm deflects arrows and shatters after four hits',()=>{
  const {G}=bossFight('forge',[['palm'],['meteor','slam'],['bellows','magma']]);
  for(let i=0;i<4;i++){
    const x=G.riftState().palm.x;G.phase='flying';const a=G.addArrow(x,960,0,-20);
    for(let j=0;j<30&&a.body.velocity.y<0;j++)G.tick(1/60);
    assert.ok(a.body.velocity.y>0,'palm bounces the arrow');run(G,.3);
  }
  assert.ok(G.riftState().palm.down);
});

// Mechanic tests switch the damage reduction off so multipliers read exactly.
function serp(abilities=[['coil'],['dive','devour'],['comet','eclipse'],['twin','coil']],{resist=false,regen=false}={}){
  const list=abilities.length<4?[...abilities,['twin','coil']]:abilities;
  const s=bossFight('serpent',list);if(!resist)s.G.bossDefs.serpent.resist={grace:1e9,burst:1e9};if(!regen)s.G.bossDefs.serpent.regen=false;return s;
}
const sstate=G=>G.riftState().snakes;
test('serpent: all four phases have doubled lengths, including the final twin bodies',()=>{
  const {G}=serp([[],[],[],['twin']]),lengths=[32,36,42,48];
  for(const [i,length] of lengths.entries()){
    assert.equal(G.boss().phase,i+1);assert.equal(sstate(G)[0].max,length);assert.equal(sstate(G)[0].segs,length);
    assert.equal(G.bricks.filter(b=>b.type==='scale').length,length);
    if(i<3){finishPhase(G);run(G,1.4);}
  }
  assert.ok(until(G,()=>sstate(G).length===2,8));assert.equal(sstate(G).map(sn=>sn.segs).join(),'24,24');
});
test('serpent: a 64-scale tail stays complete while moving and the save cap rejects a 65th scale',()=>{
  const {G}=serp([[],[],[],[]]);G.save();const saved=JSON.parse(JSON.stringify(G.state));
  saved.milestone.data.snakes=[{max:64,segs:Array(64).fill(20)}];
  const next=boot(saved).G;run(next,30);
  assert.equal(sstate(next)[0].segs,64);assert.equal(sstate(next)[0].live,64,'the longer trail must retain the last scale');
  const data={lengthVersion:2,regrowth:0,snakes:[{max:64,segs:Array(64).fill(20)}]};
  assert.equal(next.bossDefs.serpent.validate(data),true);data.snakes[0].max=65;data.snakes[0].segs.push(20);
  assert.equal(next.bossDefs.serpent.validate(data),false);
});
for(const twins of [false,true])test(`serpent: old ${twins?'twin':'single'} tails upgrade once, preserving damage, missing scales and portal armour`,()=>{
  const {G}=serp([[],[],[],[]]);G.save();const saved=JSON.parse(JSON.stringify(G.state));
  delete saved.milestone.data.lengthVersion;saved.milestone.data.regrowth=2;
  const oldHp=[1.5,10,20,30,40,50],max=twins?8:16;
  saved.milestone.data.snakes=Array.from({length:twins?2:1},()=>({max,segs:[...oldHp]}));
  const {G:next,read}=boot(saved);next.save();
  for(const sn of sstate(next)){assert.equal(sn.max,max*2);assert.equal(sn.segs,oldHp.length*2);}
  for(const sn of next.boss().data.snakes)assert.deepEqual(Array.from(sn.segs),oldHp.flatMap(h=>[h,h]));
  assert.equal(next.riftState().regrowth,2);assert.equal(next.state.coins,saved.coins);
  const reloaded=boot(read()).G;
  assert.equal(reloaded.boss().data.lengthVersion,2);
  assert.equal(sstate(reloaded)[0].max,max*2);assert.equal(sstate(reloaded)[0].segs,oldHp.length*2,'a second load never doubles again');
});
test('serpent: the boss backdrop restores canvas brush state, including when drawing fails',()=>{
  const {G}=serp(),stack=[],ctx={lineWidth:1,lineCap:'butt',save(){stack.push([this.lineWidth,this.lineCap]);},restore(){[this.lineWidth,this.lineCap]=stack.pop();}};
  G.bossDefs.serpent.drawBack=c=>{c.lineWidth=70;c.lineCap='round';};G.drawBossBackdrop(ctx);
  assert.equal(ctx.lineWidth,1);assert.equal(ctx.lineCap,'butt');assert.equal(stack.length,0);
  G.bossDefs.serpent.drawBack=c=>{c.lineWidth=70;throw Error('draw failed');};
  assert.throws(()=>G.drawBossBackdrop(ctx),/draw failed/);assert.equal(ctx.lineWidth,1);assert.equal(stack.length,0);
});
const until=(G,pred,seconds=12)=>{for(let i=0;i<seconds*60&&!pred();i++)G.tick(1/60);return pred();};
// Fire at a head from just below it so the arrow meets it within a few frames.
function shootHead(G,sn){G.phase='flying';return G.addArrow(sn.head.x,sn.head.y+44,0,-18);}
const hitHead=(G,i=0)=>{const m=G.boss(),hp=m.hp,a=shootHead(G,sstate(G)[i]);until(G,()=>m.hp<hp,.5);return {a,dealt:hp-m.hp};};
test('serpent: scale bricks trail the moving head; breaking one chips the boss and shortens the body',()=>{
  const {G}=serp(),m=G.boss(),scales=()=>G.bricks.filter(b=>b.type==='scale');
  assert.equal(scales().length,32);assert.ok(scales().every(b=>b.orbit&&b.skin));
  const x=scales()[0].x;run(G,.5);assert.notEqual(scales()[0].x,x,'the body moves');
  const hp=m.hp;G.hit(scales()[3],1e9);assert.ok(m.hp<hp);run(G,.1);
  assert.equal(sstate(G)[0].segs,31);assert.equal(scales().length,31);
});
test('serpent: the tail is armoured; a shortened body regrows scale by scale and cannot be stopped',()=>{
  const {G}=serp([['coil'],['coil'],['coil'],['twin']],{regen:true}),scales=()=>G.bricks.filter(b=>b.type==='scale');
  const d=G.boss().data.snakes[0].segs;assert.ok(d.at(-1)>d[0]*2,'tail scales carry more hp');
  scales().slice(-8).forEach(b=>G.hit(b,1e9));run(G,.1);assert.equal(sstate(G)[0].segs,24);
  assert.ok(until(G,()=>sstate(G)[0].regen,8),'starts regrowing');
  const counts=new Set();for(let i=0;i<120&&sstate(G)[0].regen;i++){G.tick(1/60);counts.add(sstate(G)[0].segs);if(i%20===0&&scales().at(-1))G.hit(scales().at(-1),1);}
  assert.ok(counts.size>=4,'one scale at a time');assert.ok(sstate(G)[0].segs>=30,'chipping the tip does not stop it');
});
test('serpent: the armoured head only takes 1.5x while it swims; cracking five scales stuns it for 5x',()=>{
  const {G}=serp([['comet'],['coil','dive'],['devour','twin']]);remove(G,b=>b.type==='scale');
  const first=hitHead(G);assert.ok(Math.abs(first.dealt-first.a.damage*1.5)<1e-6,'armoured head');
  G.bricks.filter(b=>b.type==='scale').slice(0,5).forEach(b=>G.hit(b,1e9));run(G,.05);
  assert.equal(sstate(G)[0].mode,'stun','five broken scales crack the guard');
  remove(G,b=>b.type==='scale');const second=hitHead(G);assert.ok(second.dealt>=second.a.damage*5-1e-6,'stunned head takes 5x');
});
test('serpent: a head hit during the coil interrupts it and stuns; an unanswered lunge smashes a lane',()=>{
  const {G}=serp([['coil'],['dive','devour'],['comet','twin']]);
  assert.ok(until(G,()=>sstate(G)[0].mode==='coil'),'coils');
  remove(G,b=>b.type==='scale');const {a,dealt}=hitHead(G);
  assert.ok(dealt>=a.damage*4-1e-6);assert.equal(sstate(G)[0].mode,'stun');
  const next=serp([['coil'],['dive','devour'],['comet','twin']]).G,before=next.bricks.filter(b=>!b.orbit).length;
  assert.ok(until(next,()=>sstate(next)[0].mode==='lunge'));assert.ok(until(next,()=>sstate(next)[0].mode!=='lunge',2));
  assert.ok(next.bricks.filter(b=>!b.orbit).length<before,'the lunge crushes bricks');
});
test('serpent: a dive telegraphs its exit gate; erupting smashes bricks, shooting the gate yanks it out stunned',()=>{
  const {G}=serp([['dive'],['coil','devour'],['comet','twin']]),before=G.bricks.filter(b=>!b.orbit).length;
  assert.ok(until(G,()=>sstate(G)[0].mode==='under'),'dives');
  assert.ok(until(G,()=>sstate(G)[0].mode==='rise',3),'erupts');
  assert.ok(G.bricks.filter(b=>!b.orbit).length<before,'eruption smashes bricks');
  assert.ok(until(G,()=>G.bricks.filter(b=>b.type==='scale').length>=8,8),'body follows out of the gate');
  assert.ok(until(G,()=>sstate(G)[0].live===sstate(G)[0].segs||sstate(G)[0].mode==='sink',22));const q=sstate(G)[0];
  if(q.mode!=='sink'){run(G,.8);assert.ok(G.riftState().portals===0||sstate(G)[0].mode==='sink','gates close once the body is through');}
  const {G:H}=serp([['dive'],['coil','devour'],['comet','twin']]);
  assert.ok(until(H,()=>sstate(H)[0].mode==='under'));remove(H,b=>b.type==='scale');
  const {exit}=sstate(H)[0];H.phase='flying';H.addArrow(exit.x,exit.y+60,0,-14);
  assert.ok(until(H,()=>sstate(H)[0].mode==='stun',.5),'yanked out and stunned');
});
test('serpent: every portal return restores a full tail and increases its armour',()=>{
  const {G}=serp([['dive'],[],[],[]]),m=G.boss(),original=Array.from(m.data.snakes[0].segs);
  const scales=G.bricks.filter(b=>b.type==='scale');G.hit(scales[0],1e9);scales[1].hp=1;
  assert.ok(until(G,()=>sstate(G)[0].mode==='under'));
  assert.equal(sstate(G)[0].segs,31,'the missing scale stays missing while submerged');
  assert.ok(until(G,()=>sstate(G)[0].mode==='rise',3));G.save();
  assert.equal(sstate(G)[0].segs,32);assert.equal(G.riftState().regrowth,1);
  assert.deepEqual(Array.from(m.data.snakes[0].segs),original.map(h=>Math.ceil(h*1.5)),'all scales, including damaged ones, return stronger');
  assert.equal(sstate(G)[0].live,0,'the tail emerges along the trail rather than appearing all at once');
  assert.ok(until(G,()=>sstate(G)[0].mode==='under',28));
  assert.ok(until(G,()=>sstate(G)[0].mode==='rise',3));G.save();
  assert.equal(G.riftState().regrowth,2);
  assert.deepEqual(Array.from(m.data.snakes[0].segs),original.map(h=>Math.ceil(h*2)));
});
test('serpent: the exit gate survives until a long tail emerges and dive cannot hide it early',()=>{
  const {G}=serp([['dive'],[],[],[]]);
  assert.ok(until(G,()=>sstate(G)[0].mode==='under'));assert.ok(until(G,()=>sstate(G)[0].mode==='rise',3));
  const start=G.time;
  for(let i=0;i<22*60&&sstate(G)[0].live<32;i++){
    assert.notEqual(sstate(G)[0].mode,'sink','wait for the entire body before another dive');
    assert.ok(G.riftState().portals>0,'the gate must not time out with scales still inside');G.tick(1/60);
  }
  assert.equal(sstate(G)[0].live,32);assert.ok(G.time-start>8,'the doubled tail takes longer than the old eight-second gate limit');
});
test('serpent: shooting the exit also restores a harder tail while retaining the stun reward',()=>{
  const {G}=serp([['dive'],[],[],[]]);G.hit(G.bricks.find(b=>b.type==='scale'),1e9);
  assert.ok(until(G,()=>sstate(G)[0].mode==='under'));
  const {exit}=sstate(G)[0];G.phase='flying';G.addArrow(exit.x,exit.y+60,0,-14);
  assert.ok(until(G,()=>sstate(G)[0].mode==='stun',.5));
  assert.equal(sstate(G)[0].segs,32);assert.equal(G.riftState().regrowth,1);assert.equal(sstate(G)[0].retreat,false);
});
test('serpent: an empty tail stuns, grants fivefold head damage, then escapes quickly even without dive equipped',()=>{
  const {G}=serp([[],[],[],[]],{resist:true,regen:true}),m=G.boss();m.hp=m.max=1e6;
  G.bricks.filter(b=>b.type==='scale').forEach(b=>G.hit(b,1e9));run(G,.05);
  assert.equal(sstate(G)[0].mode,'stun');assert.equal(sstate(G)[0].retreat,true);
  assert.equal(sstate(G)[0].segs,0);assert.equal(sstate(G)[0].regen,false);
  assert.equal(G.bossDefs.serpent.status().text,'断尾 · 破绽');
  const {a,dealt}=hitHead(G);assert.ok(Math.abs(dealt-a.damage*5)<1e-6);
  run(G,1);assert.equal(sstate(G)[0].mode,'stun','the player gets a real damage window');
  assert.ok(until(G,()=>sstate(G)[0].mode==='sink',1));
  assert.ok(until(G,()=>sstate(G)[0].mode==='under',.15),'the empty body escapes in a fraction of a second');
  assert.ok(until(G,()=>sstate(G)[0].mode==='rise',.8));
  assert.equal(sstate(G)[0].segs,32);assert.equal(sstate(G)[0].retreat,false);assert.equal(G.riftState().regrowth,1);
  assert.ok(until(G,()=>sstate(G)[0].live===32,18),'the complete tail gradually emerges');
  G.bricks.filter(b=>b.type==='scale').forEach(b=>G.hit(b,1e9));run(G,.05);
  assert.ok(until(G,()=>sstate(G)[0].mode==='rise',4));assert.equal(G.riftState().regrowth,2,'the depletion cycle can repeat');
});
test('serpent: clearing the tail as it starts diving still interrupts the escape with a stun',()=>{
  const {G}=serp([['dive'],[],[],[]]);G.boss().hp=G.boss().max=1e6;
  assert.ok(until(G,()=>sstate(G)[0].mode==='sink'));
  const scales=G.bricks.filter(b=>b.type==='scale');assert.equal(scales.length,32);
  scales.forEach(b=>G.hit(b,1e9));
  assert.equal(sstate(G)[0].mode,'stun');assert.equal(sstate(G)[0].retreat,true);
  assert.equal(sstate(G)[0].segs,0,'a disappearing head must not silently skip the depletion reward');
});
test('serpent: portal armour and an empty-tail retreat survive save/reload and phase changes',()=>{
  const {G,read}=serp([[],[],[],[]]);G.boss().hp=G.boss().max=1e6;
  G.bricks.filter(b=>b.type==='scale').forEach(b=>G.hit(b,1e9));run(G,.5);G.save();
  let next=boot(read()).G;
  assert.equal(sstate(next)[0].segs,0);assert.equal(sstate(next)[0].retreat,true);assert.equal(sstate(next)[0].mode,'stun');
  assert.ok(until(next,()=>sstate(next)[0].mode==='sink',1.7),'reload keeps the remaining stun rather than restarting it');
  assert.ok(until(next,()=>sstate(next)[0].mode==='rise',1));next.save();
  const snapshot=JSON.parse(JSON.stringify(next.state)),hp=Array.from(snapshot.milestone.data.snakes[0].segs);
  next=boot(snapshot).G;
  assert.equal(next.riftState().regrowth,1);assert.deepEqual(Array.from(next.boss().data.snakes[0].segs),hp);
  finishPhase(next);run(next,1.4);assert.equal(next.riftState().regrowth,1,'stage change does not reset portal armour');
  assert.ok(next.boss().data.snakes[0].segs[0]>=hp[0]);
});
test('serpent: a depleted twin regrows without forcing its sibling into a stuck merge',()=>{
  const {G}=twinFight();G.boss().hp=G.boss().max=1e6;
  // Complete both bodies so the depleted twin has no hidden surviving scales.
  assert.ok(until(G,()=>sstate(G).every(sn=>sn.live===sn.segs),4));
  // A saved depleted twin also exercises the real reload path.
  G.save();const depleted=G.boss().data.snakes.map(sn=>({...sn,segs:[]}));
  const saved=JSON.parse(JSON.stringify(G.state));saved.milestone.data.snakes[0]=depleted[0];
  const next=boot(saved).G;run(next,.05);
  assert.equal(sstate(next)[0].retreat,true);assert.equal(sstate(next)[1].retreat,false);
  assert.ok(until(next,()=>sstate(next)[0].mode==='rise',4));assert.equal(sstate(next)[0].segs,16);
  assert.ok(until(next,()=>sstate(next).length===1,20),'twins can still reunite after the retreat');
});
test('serpent: devour swallows bricks and grows; three shots into the maw choke it into star bricks',()=>{
  const {G}=serp([['devour'],['coil','dive'],['comet','twin']]),m=G.boss();
  assert.ok(until(G,()=>sstate(G)[0].mode==='maw'),'rears and opens its maw');
  const segs=sstate(G)[0].segs;run(G,1.8);assert.ok(G.riftState().debris>0||sstate(G)[0].fed>0,'bricks are pulled in');
  assert.ok(sstate(G)[0].segs>segs,'eating grows the body');
  remove(G,b=>b.type==='scale');const hp=m.hp;
  for(let i=0;i<4&&sstate(G)[0].mode==='maw';i++){shootHead(G,sstate(G)[0]);run(G,.35);}
  assert.equal(sstate(G)[0].mode,'stun','choked');assert.ok(m.hp<hp);
  assert.ok(G.bricks.some(b=>b.type==='star'),'spat out star bricks');
});
test('serpent: devour pulls the aim line toward the maw',()=>{
  const {G}=serp([['devour'],['coil','dive'],['comet','twin']]);
  assert.ok(until(G,()=>sstate(G)[0].mode==='maw'));run(G,.5);remove(G,b=>b.type==='scale');
  const {head}=sstate(G)[0],path=G.predictPath(head.x+(head.x>390?-160:160),970,0,-22,900);
  assert.ok(path.some(p=>Math.abs(p.x-head.x)<120&&p.y<head.y+150),'the path curves into the mouth');
});
const twinFight=()=>{const s=serp([['twin'],['coil','dive'],['devour','comet']]);assert.ok(until(s.G,()=>sstate(s.G).length===2),'tears in two');run(s.G,1.2);return s;};
test('serpent: twin tears the body in two heads joined by a star thread; cutting it stuns both and forces a merge',()=>{
  const {G}=twinFight(),s=sstate(G);
  assert.ok(s[1].twin);assert.equal(s.map(x=>x.segs).join(),'16,16');assert.ok(G.riftState().split);
  remove(G,b=>b.type==='scale');
  const [a,b]=s.map(x=>x.head),mx=(a.x+b.x)/2,my=(a.y+b.y)/2,nx=-(b.y-a.y),ny=b.x-a.x,len=Math.hypot(nx,ny);
  G.phase='flying';G.addArrow(mx-nx/len*80,my-ny/len*80,nx/len*14,ny/len*14,64);
  assert.ok(until(G,()=>G.riftState().split?.cut,.6),'the thread is cut');
  assert.ok(sstate(G).every(x=>x.mode==='stun'));
  assert.ok(until(G,()=>sstate(G).length===1,8),'forced merge');assert.equal(sstate(G)[0].mode,'stun');
  assert.equal(sstate(G)[0].segs,32);
});
test('serpent: striking both twin heads within a second resonates into a forced merge',()=>{
  const {G}=twinFight(),m=G.boss();remove(G,b=>b.type==='scale');const hp=m.hp;
  shootHead(G,sstate(G)[0]);shootHead(G,sstate(G)[1]);
  assert.ok(until(G,()=>G.riftState().split?.merging,.6),'resonance');assert.ok(hp-m.hp>=G.damage()*6);
  assert.ok(until(G,()=>sstate(G).length===1,3));assert.equal(sstate(G)[0].mode,'stun');
});
test('serpent: left alone the twins merge back and regrow lost scales',()=>{
  const {G}=twinFight();G.bricks.filter(b=>b.type==='scale').slice(0,3).forEach(b=>G.hit(b,1e9));run(G,.1);
  assert.equal(sstate(G).reduce((n,x)=>n+x.segs,0),29);
  assert.ok(until(G,()=>sstate(G).length===1,20),'merged');assert.equal(sstate(G)[0].segs,32);assert.notEqual(sstate(G)[0].mode,'stun');
});
test('serpent: eclipse shortens the aim line; two head hits break it',()=>{
  const {G}=serp([['eclipse'],['coil','dive'],['devour','twin']]);
  assert.ok(until(G,()=>G.riftState().dim),'darkness falls');remove(G,b=>b.type==='scale');
  const path=G.predictPath(390,970,0,-22,720);let len=0;for(let i=1;i<path.length;i++)len+=Math.hypot(path[i].x-path[i-1].x,path[i].y-path[i-1].y);
  assert.ok(len<=190,`aim line shortened (${len})`);
  hitHead(G);run(G,.2);hitHead(G);assert.equal(sstate(G)[0].mode,'stun');
  assert.ok(until(G,()=>!G.riftState().dim,1),'light returns');
});
test('serpent: star bricks release sparks that home in on the head',()=>{
  const {G}=serp([['comet'],['coil','dive'],['devour','twin']]),m=G.boss();
  assert.equal(G.bricks.filter(b=>b.type==='star').length,4);
  const star=G.bricks.find(b=>b.type==='star'),hp=m.hp;
  G.hit(star,1e9);assert.equal(G.riftState().sparks,3);run(G,3.6);assert.ok(m.hp<hp,'sparks hurt the boss');
});
test('serpent: four phases; phase one opens with an attack, phases one to three never repeat, phase four is the twin split',()=>{
  const {G}=serp(),d=G.bossDefs.serpent;assert.equal(d.phases,4);
  for(let i=0;i<30;i++){
    const r=d.roll(Object.keys(d.abilities));assert.equal(r.length,4);
    assert.ok(['coil','dive','devour'].includes(r[0][0]));assert.equal(new Set(r.slice(0,3).flat()).size,5);
    assert.ok(!r.slice(0,3).flat().includes('twin'));assert.equal(r[3][0],'twin');assert.notEqual(r[3][1],'twin');
  }
});
test('serpent: a phase change slips the body into a gate and bursts it out of another',()=>{
  const {G}=serp();G.reduced=false;const before={...sstate(G)[0].head};finishPhase(G);
  G.reduced=true;const s=sstate(G)[0];for(const t=Date.now()+400;Date.now()<t;);// hit-stop runs on wall-clock time
assert.equal(G.boss().phase,2);assert.equal(s.mode,'sink');
  assert.ok(Math.hypot(s.head.x-before.x,s.head.y-before.y)<60,'dives where the old body was');assert.ok(G.riftState().portals>0);
  assert.ok(until(G,()=>sstate(G)[0].mode==='under',6),'goes under');
  assert.ok(until(G,()=>sstate(G)[0].mode==='rise',3),'bursts out');assert.equal(sstate(G)[0].segs,36);
});
test('serpent: phase four opens by tearing into twins; left alone they strangle-merge and tear apart again',()=>{
  const {G}=serp();for(let i=0;i<3;i++){finishPhase(G);run(G,1.4);}
  assert.equal(G.boss().phase,4);assert.ok(G.bossApi.rage(),'phase four is the rage phase');
  assert.ok(until(G,()=>sstate(G).length===2,8),'tears in two at once');assert.equal(sstate(G).map(x=>x.segs).join(),'24,24');
  assert.ok(until(G,()=>sstate(G).length===1,20),'strangle merge');assert.notEqual(sstate(G)[0].mode,'stun');
  assert.ok(until(G,()=>sstate(G).length===2,8),'splits again');
});
test('serpent: reloading keeps the scale count and damage without doubling bricks',()=>{
  const {G,read}=serp();const sc=G.bricks.filter(b=>b.type==='scale');G.hit(sc[0],1e9);sc[1].hp=1.5;run(G,.1);G.save();
  const next=boot(read()).G,n=next.bricks.filter(b=>b.type==='scale');
  assert.equal(n.length,31);assert.ok(n.some(b=>b.hp===1.5));
  next.tick(1/60);assert.equal(next.bricks.filter(b=>b.type==='scale').length,31);
});
test('serpent: a split fight reloads as two twins',()=>{
  const {G,read}=twinFight();G.save();const next=boot(read()).G;
  assert.equal(next.riftState().snakes.length,2);assert.ok(next.riftState().split);assert.equal(next.bricks.filter(b=>b.type==='scale').length,32);
});

const CLOCK=[['stop'],['toll','rewind'],['midnight','pendulum']];
function clock(abilities=CLOCK){const s=bossFight('clock',abilities);s.G.bossDefs.clock.resist={grace:1e9,burst:1e9};return s;}
const plain=G=>{remove(G);for(const o of G.obstacles)Matter.Composite.remove(G.engine.world,o.body);G.obstacles=[];};
const noArrows=G=>{G.arrows.forEach(a=>Matter.Composite.remove(G.engine.world,a.body));G.arrows=[];};
const cs=G=>G.riftState();
// Fires from just below a point, straight up into it.
const upAt=(G,p,v=14)=>{noArrows(G);G.phase='flying';const a=G.addArrow(p.x,p.y+40,0,-v);for(let i=0;i<6;i++)G.tick(1/60);return a;};
// Straight into the core through the widest gap between the hands.
function coreShot(G){
  const {minute:mi,hour:ho}=cs(G);let best=0,gap=-1;
  for(let i=0;i<72;i++){const a=i/72*Math.PI*2,d=Math.min(...[mi,ho].map(h=>Math.abs(Math.atan2(Math.sin(a-h),Math.cos(a-h)))));if(d>gap){gap=d;best=a;}}
  noArrows(G);G.phase='flying';const a=G.addArrow(390+Math.cos(best)*60,470+Math.sin(best)*60,-Math.cos(best)*12,-Math.sin(best)*12);run(G,.1);return a;
}
test('clock: twelve numeral bricks ring the dial; the core cell is empty',()=>{
  const {G}=clock();
  const n=G.bricks.filter(b=>b.type==='hour');assert.ok(n.length>=9&&n.length<=12);
  assert.ok(!G.bricks.some(b=>Math.hypot(b.x-390,b.y-470)<60));
  assert.deepEqual([...new Set(n.map(b=>b.hourIndex))].length,n.length,'each numeral appears once');
});
test('clock: phase one opens with a target move; the last phase always adds midnight',()=>{
  for(const seed of [1,7,99,4242]){
    const m=boot(save(100,'clock'),{seed}).G.boss(),[a,b,c]=m.abilities;
    assert.equal(a.length,1);assert.ok(['stop','toll','pendulum'].includes(a[0]));
    assert.equal(b.length,2);assert.equal(c[0],'midnight');assert.equal(new Set(m.abilities.flat()).size,5);
  }
});
test('clock: the sealed core takes no damage while the clock runs; the hands deflect arrows',()=>{
  const {G}=clock(),m=G.boss();plain(G);
  const a0=cs(G).minute;run(G,.5);assert.notEqual(cs(G).minute,a0);
  const {minute}=cs(G),tip={x:390+Math.cos(minute)*200,y:470+Math.sin(minute)*200},n=minute+Math.PI/2;
  G.phase='flying';const hand=G.addArrow(tip.x+Math.cos(n)*40,tip.y+Math.sin(n)*40,-Math.cos(n)*8,-Math.sin(n)*8);
  const hp=m.hp;for(let i=0;i<6;i++)G.tick(1/60);
  const v=hand.body.velocity;assert.ok(v.x*-Math.cos(n)+v.y*-Math.sin(n)<0,'hand bounces the arrow');assert.equal(m.hp,hp);
  const b=coreShot(G);assert.equal(m.hp,hp,'the case turns every shot');assert.ok(Math.hypot(b.body.velocity.x,b.body.velocity.y)>0);
});
test('clock: breaking a numeral chips the boss lightly and slows the hands',()=>{
  const {G}=clock(),m=G.boss();
  const n=G.bricks.find(b=>b.type==='hour'&&b.hourIndex!==cs(G).hourIdx),hp=m.hp;G.hit(n,1e9);
  assert.ok(hp-m.hp>0&&hp-m.hp<=G.damage()*.5+1e-9);
  const t0=cs(G).minute;run(G,1);const turned=cs(G).minute-t0;assert.ok(turned>0&&turned<.9);
});
test('clock: each lap of the minute hand steps the hour hand onto the next numeral',()=>{
  const {G}=clock();plain(G);const h=cs(G).hourIdx;
  let steps=0,prev=h;for(let i=0;i<60*16;i++){G.tick(1/60);if(cs(G).hourIdx!==prev){steps++;assert.equal(cs(G).hourIdx,(prev+1)%12);prev=cs(G).hourIdx;}}
  assert.ok(steps>=1,'the hour hand steps');
});
test('clock: hitting the lit numeral drains the spring; empty, the clock stalls and the core takes ×3, then it rewinds',()=>{
  const {G}=clock(),m=G.boss(),def=G.bossDefs.clock;
  const lit=()=>G.bricks.find(b=>b.type==='hour'&&b.hourIndex===cs(G).hourIdx);
  if(!lit())G.bricks.find(b=>b.type==='hour').hourIndex=cs(G).hourIdx;
  G.tick(1/60);
  const b=lit();assert.ok(b,'the hour hand points at a numeral');b.hp=b.max=1e12;
  const a=G.addArrow(100,1200,0,0);G.withArrow(a,()=>G.hit(b,1));assert.ok(cs(G).spring<=100-16+1e-6,'one hit drains the spring');
  const hp=m.hp;
  for(let i=0;i<8&&!cs(G).stunned;i++)G.withArrow(a,()=>G.hit(lit()||b,1));
  assert.ok(cs(G).stunned,'an empty spring stalls the clock');assert.equal(cs(G).spring,0);
  plain(G);const s=coreShot(G);assert.ok(Math.abs(hp-m.hp-s.damage*3)<1e-6,'×3 on the open core');
  run(G,4);assert.ok(!cs(G).stunned);run(G,.3);assert.ok(cs(G).refill,'a key winds it back');
  run(G,1.2);assert.equal(cs(G).spring,100);assert.ok(!cs(G).refill);
  assert.equal(def.status().text,'发条 100%');
});
test('clock: the spring winds itself back up and survives a reload',()=>{
  const {G,read}=clock();G.boss().data.spring=40;run(G,2);
  const s=cs(G).spring;assert.ok(s>45&&s<50,`spring ${s}`);
  G.save();assert.ok(Math.abs(boot(read()).G.riftState().spring-s)<1e-9);
});
test('clock: from phase two, escapement gears jam only on their glowing tooth; all three stall the clock',()=>{
  const {G}=clock();finishPhase(G);run(G,1.4);plain(G);
  const gears=G.bossDefs.clock.gears();assert.equal(gears.length,3);
  const g=gears[0];g.a=-Math.PI/2+Math.PI;const miss=cs(G).spring;
  noArrows(G);G.phase='flying';G.addArrow(g.x,g.y-70,0,14);run(G,.1);assert.ok(!g.jammed,'off-tooth hits glance off');
  assert.ok(cs(G).spring>=miss);
  for(const t of gears){let tries=0;while(!t.jammed&&tries++<10){t.a=Math.PI/2;noArrows(G);G.phase='flying';G.addArrow(t.x,t.y+70,0,-14);run(G,.1);}assert.ok(t.jammed,`gear ${t.i} jams`);}
  assert.ok(cs(G).stunned,'three jammed gears stall the clock');
  run(G,5.5);assert.ok(gears.every(t=>!t.jammed),'the rewind frees the gears');
});
test('clock: one move at a time, on its own clock after the intro',()=>{
  const {G}=clock();assert.equal(cs(G).move,null);
  run(G,4.8);assert.equal(cs(G).move,'stop','the phase-one move opens');
  G.bossDefs.clock.start('toll');run(G,.1);assert.equal(cs(G).move,'stop','a second move cannot start over the first');
});
test('clock: phase three alternates its move with midnight',()=>{
  const {G}=clock();finishPhase(G);run(G,1.4);finishPhase(G);assert.equal(G.boss().phase,3);
  let seen=[];for(let i=0;i<60*30;i++){G.tick(1/60);const id=cs(G).move;if(id&&id!==seen.at(-1))seen.push(id);}
  assert.equal(seen[0],'pendulum');assert.ok(seen.length>=3);
  seen.forEach((id,i)=>assert.equal(id,i%2?'midnight':'pendulum'));
});
test('clock: breaking the winding key stalls the clock; the open core takes ×3',()=>{
  const {G}=clock(),m=G.boss();plain(G);
  G.bossDefs.clock.start('stop');const key=cs(G).key;assert.ok(key);
  upAt(G,key);assert.ok(cs(G).stunned,'jammed');assert.equal(cs(G).move,null);
  const hp=m.hp,a=coreShot(G);assert.ok(Math.abs(hp-m.hp-a.damage*3)<1e-6,'×3 on the core');
});
test('clock: a missed key freezes flying arrows, then throws them back',()=>{
  const {G}=clock();plain(G);
  G.bossDefs.clock.start('stop');run(G,2.5);G.phase='flying';const a=G.addArrow(700,600,0,-3);run(G,.2);
  assert.equal(cs(G).move,null);assert.equal(cs(G).frozen,1);assert.equal(G.arrows.length,0);
  const y=a.body.position.y;run(G,.6);assert.equal(G.phase,'flying','the volley holds');assert.equal(a.body.position.y,y);
  run(G,1.6);assert.equal(cs(G).frozen,null);assert.ok(a.body.velocity.y>0,'thrown back down');
});
test('clock: hitting the bell before the third toll shatters wards; missing it wards the dial',()=>{
  const miss=clock([['toll'],['stop','rewind'],['midnight','pendulum']]).G;
  miss.bossDefs.clock.start('toll');run(miss,4.5);assert.equal(cs(miss).move,null);
  const w=miss.bricks.filter(b=>b.ward);assert.ok(w.length>=8,`${w.length} warded`);
  const b=w[0],hp=b.hp;miss.hit(b,1);assert.equal(b.hp,hp,'a ward absorbs one hit');assert.ok(!b.ward);miss.hit(b,1);assert.ok(b.hp<hp);
  const {G}=clock([['toll'],['stop','rewind'],['midnight','pendulum']]);plain(G);
  G.bossDefs.clock.start('toll');run(G,1);upAt(G,cs(G).bell,20);assert.ok(cs(G).stunned,'the bell shatters');assert.equal(cs(G).move,null);
});
test('clock: three hits snap the pendulum; letting it swing winds the hands up',()=>{
  const {G}=clock([['pendulum'],['stop','rewind'],['midnight','toll']]);plain(G);
  G.bossDefs.clock.start('pendulum');run(G,1.1);
  for(let i=0;i<3;i++){upAt(G,cs(G).bob,20);run(G,.25);}
  assert.ok(cs(G).stunned,'snapped');
  const miss=clock([['pendulum'],['stop','rewind'],['midnight','toll']]).G;
  miss.bossDefs.clock.start('pendulum');run(miss,8.2);assert.equal(cs(miss).move,null);assert.ok(cs(miss).wound>1);
});
test('clock: rewind restores broken bricks unless a core shot interrupts it',()=>{
  const {G}=clock([['rewind'],['stop','toll'],['midnight','pendulum']]);
  G.bricks.filter(b=>b.type==='normal').slice(0,5).forEach(b=>G.hit(b,1e9));const n=G.bricks.length;
  assert.ok(G.bossDefs.clock.start('rewind'));assert.equal(cs(G).ghosts,5);run(G,4);assert.equal(G.bricks.length,n+5);
  const hit=clock([['rewind'],['stop','toll'],['midnight','pendulum']]).G;
  hit.bricks.filter(b=>b.type==='normal').slice(0,3).forEach(b=>hit.hit(b,1e9));plain(hit);
  hit.bossDefs.clock.start('rewind');coreShot(hit);assert.ok(cs(hit).stunned,'interrupted');run(hit,4);assert.equal(hit.bricks.length,0);
});
test('clock: during haste the lit numeral jams the gears; missing it regrows numerals',()=>{
  const {G}=clock([['haste'],['stop','toll'],['midnight','pendulum']]);
  G.bricks.filter(b=>b.type==='hour').slice(0,3).forEach(b=>G.hit(b,1e9));const n=cs(G).numerals;
  G.bossDefs.clock.start('haste');run(G,5.6);assert.equal(cs(G).move,null);assert.equal(cs(G).numerals,n+2);
  G.bossDefs.clock.start('haste');run(G,1);let lit=null;for(let i=0;i<220&&!lit;i++){G.tick(1/60);const i2=cs(G).lit;lit=i2===null?null:G.bricks.find(b=>b.type==='hour'&&b.hourIndex===i2);}
  assert.ok(lit);G.withArrow(G.addArrow(390,900,0,0),()=>G.hit(lit,1));assert.ok(cs(G).stunned,'jammed');
});
test('clock: midnight needs three core hits within twelve tolls; missing it regrows every numeral',()=>{
  const {G}=clock();plain(G);
  G.bossDefs.clock.start('midnight');run(G,1.3);
  for(let i=0;i<3;i++){upAt(G,{x:390,y:520},14);run(G,.2);}
  assert.ok(cs(G).stunned,'three hits jam midnight');
  const miss=clock().G;plain(miss);
  miss.bossDefs.clock.start('midnight');run(miss,6.8);assert.equal(cs(miss).move,null);assert.ok(cs(miss).wound>1);
  run(miss,2.5);assert.equal(cs(miss).numerals,12,'every numeral regrows');
});

// ── Dynamic damage reduction, shared by every boss.
for(const id of ['eye','forge','serpent','clock'])test(`${id}: burst damage past 30% of a phase in three seconds lands at a quarter`,()=>{
  const {G}=bossFight(id),m=G.boss(),api=G.bossApi,hp=m.hp;
  const dealt=api.hurt(m.max*.5,390,470);
  assert.ok(Math.abs(dealt-m.max*(.3+.2*.25))<1e-6,`dealt ${dealt/m.max}`);
  assert.ok(api.resist()<=.25+1e-9,'the burst cap holds');assert.ok(m.hp<hp);
  run(G,3.2);assert.ok(api.resist()>.25,'the burst window expires');
});
test('damage reduction: outpacing the phase clock scales damage down; keeping pace lands in full',()=>{
  const {G}=bossFight('forge'),m=G.boss(),api=G.bossApi;
  m.hp=m.max*.5;m.clock=0;const fast=api.hurt(m.max*.05,390,470);
  assert.ok(fast<m.max*.05*.8,'ahead of pace: reduced');
  const slow=bossFight('forge').G,s=slow.boss();s.hp=s.max*.5;s.clock=30;
  assert.ok(Math.abs(slow.bossApi.hurt(s.max*.05,390,470)-s.max*.05)<1e-6,'on pace: full damage');
});
test('damage reduction: the phase clock pauses for intros and shifts, resets each phase and survives a reload',()=>{
  const {G,read}=bossFight('clock'),m=G.boss();
  const c0=m.clock;run(G,2);const c=m.clock;assert.ok(c0<.6&&Math.abs(c-c0-2)<.05,'clock runs with the fight');
  G.save();assert.ok(Math.abs(boot(read()).G.boss().clock-c)<1e-9,'saved');
  finishPhase(G);assert.equal(G.boss().phase,2);assert.ok(G.boss().clock<.1,'reset');run(G,1);assert.ok(G.boss().clock<.1,'paused during the shift');
});

// ── Boss score (pure event data; the Web Audio engine is not run under node).
const scoreOf=()=>{const {G}=serp();return {G,score:G.bossDefs.serpent.score};};
const loop=(score,phase,mood,twin=false)=>Array.from({length:16*score.bars},(_,s)=>score.events(s,phase,mood,twin)).flat();
test('serpent score: layers build phase by phase; the lead enters in phase three',()=>{
  const {score}=scoreOf(),has=(p,i,mood='fight')=>loop(score,p,mood).some(e=>e.i===i);
  assert.ok(has(1,'pad')&&has(1,'bass')&&has(1,'kick'));assert.ok(!has(1,'arp')&&!has(1,'lead')&&!has(1,'snare'));
  assert.ok(has(2,'arp')&&has(2,'snare'));assert.ok(!has(2,'lead'));
  assert.ok(has(3,'lead'));assert.ok(score.bpm(4)>score.bpm(1),'the last phase is faster');
  assert.ok(loop(score,4,'fight').length>loop(score,1,'fight').length*2,'much denser at the end');
});
test('serpent score: every lead and twin note sits in D minor (C# over the A chord)',()=>{
  const {score}=scoreOf(),ok=new Set([2,4,5,7,9,10,0,1]);
  for(const e of loop(score,4,'fight',true).filter(e=>e.i==='lead'))assert.ok(ok.has(e.note%12),`note ${e.note}`);
  const twins=loop(score,4,'fight',true).filter(e=>e.i==='lead'),solo=loop(score,4,'fight',false).filter(e=>e.i==='lead');
  assert.equal(twins.length,solo.length*2,'split serpent: the lead splits into two voices');
  assert.ok(twins.some(e=>e.pan<0)&&twins.some(e=>e.pan>0));
});
test('serpent score: eclipse strips it to a heartbeat; stun brings bells; devour drops the lead',()=>{
  const {score}=scoreOf(),count=(mood,i)=>loop(score,3,mood).filter(e=>e.i===i).length;
  assert.equal(count('eclipse','hat'),0);assert.equal(count('eclipse','arp'),0);assert.ok(count('eclipse','lead')<count('fight','lead'));
  assert.ok(count('stun','bell')>0&&count('fight','bell')===0);
  assert.equal(count('devour','lead'),0);
  const intro=loop(score,1,'intro');assert.ok(intro.every(e=>e.i==='pad'||e.i==='kick'));
});
test('serpent score: the mood follows the fight',()=>{
  const {G}=serp([['devour'],['coil','dive'],['comet','eclipse'],['twin','coil']]),mood=()=>G.bossDefs.serpent.music().mood;
  assert.equal(mood(),'fight');
  assert.ok(until(G,()=>mood()==='devour'));assert.ok(until(G,()=>sstate(G)[0].mode==='maw',3));
  remove(G,b=>b.type==='scale');for(let i=0;i<4&&mood()==='devour';i++){shootHead(G,sstate(G)[0]);run(G,.35);}
  assert.equal(mood(),'stun');
});

// ── Clock score.
test('clock score: layers build phase by phase; the lead enters in phase three',()=>{
  const {G}=clock(),score=G.bossDefs.clock.score,has=(p,i,mood='fight')=>loop(score,p,mood).some(e=>e.i===i);
  assert.ok(has(1,'pad')&&has(1,'bass')&&has(1,'tick')&&has(1,'box'));assert.ok(!has(1,'kick')&&!has(1,'lead'));
  assert.ok(has(2,'kick')&&has(2,'snare'));assert.ok(!has(2,'lead'));assert.ok(has(3,'lead'));
  assert.ok(score.bpm(3,'fight')>score.bpm(1,'fight'));assert.ok(score.bpm(2,'haste')>score.bpm(2,'fight'),'haste pushes the tempo');
  assert.ok(loop(score,3,'fight').length>loop(score,1,'fight').length*2,'much denser at the end');
});
test('clock score: the lead sits in A harmonic minor and G# only sounds over E',()=>{
  const {G}=clock(),score=G.bossDefs.clock.score,ok=new Set([9,11,0,2,4,5,7,8]);
  for(const e of loop(score,3,'fight').filter(e=>e.i==='lead'))assert.ok(ok.has(e.note%12),`note ${e.note}`);
  for(let s=0;s<16*score.bars;s++)for(const e of score.events(s,3,'fight'))if(e.i==='lead'&&e.note%12===8)assert.ok([1,6,7].includes(s>>4),`G# in bar ${s>>4}`);
});
test('clock score: a jam stops the tick for bells; frozen time is a muffled pad; telegraphs wind the tick up',()=>{
  const {G}=clock(),score=G.bossDefs.clock.score,count=(mood,i,p=2)=>loop(score,p,mood).filter(e=>e.i===i).length;
  assert.equal(count('stun','tick'),0);assert.ok(count('stun','bell')>0&&count('fight','bell')===0);
  assert.ok(loop(score,2,'frozen').every(e=>e.i==='pad'||e.i==='bell'));assert.equal(score.filter.frozen<1000,true);
  assert.ok(count('wind','tick')>count('fight','tick'),'the tick doubles under a telegraph');
  assert.equal(count('midnight','lead',3),0);assert.ok(count('midnight','bell',3)>0);
  assert.ok(loop(score,1,'intro').every(e=>e.i==='pad'||e.i==='tick'));
});
test('clock score: the mood follows the fight',()=>{
  const {G}=clock(),mood=()=>G.bossDefs.clock.music().mood;plain(G);
  assert.equal(mood(),'fight');
  G.bossDefs.clock.start('stop');assert.equal(mood(),'wind');
  upAt(G,cs(G).key);assert.equal(mood(),'stun');run(G,4.2);assert.equal(mood(),'wind','the rewind winds the tick up');run(G,1.3);assert.equal(mood(),'fight');
  G.bossDefs.clock.start('midnight');assert.equal(mood(),'midnight');
});

// ── Eye score.
test('eye score: layers build phase by phase; the lead enters in phase three',()=>{
  const {G}=fight(),score=G.bossDefs.eye.score,has=(p,i,mood='fight')=>loop(score,p,mood).some(e=>e.i===i);
  assert.ok(has(1,'pad')&&has(1,'bass')&&has(1,'kick')&&has(1,'bell'));assert.ok(!has(1,'arp')&&!has(1,'snare')&&!has(1,'lead'));
  assert.ok(has(2,'arp')&&has(2,'snare'));assert.ok(!has(2,'lead'));assert.ok(has(3,'lead'));
  assert.ok(score.bpm(3,'fight')>score.bpm(1,'fight'));
  assert.ok(loop(score,3,'fight').length>loop(score,1,'fight').length*2,'much denser at the end');
});
test('eye score: the lead sits in E phrygian',()=>{
  const {G}=fight(),ok=new Set([4,5,7,9,11,0,2]);
  for(const e of loop(G.bossDefs.eye.score,3,'fight').filter(e=>e.i==='lead'))assert.ok(ok.has(e.note%12),`note ${e.note}`);
});
test('eye score: a daze drops the drums for bells; doom is a racing heartbeat; a telegraph wakes the arp',()=>{
  const {G}=fight(),score=G.bossDefs.eye.score,count=(mood,i,p=1)=>loop(score,p,mood).filter(e=>e.i===i).length;
  assert.equal(count('stun','kick'),0);assert.ok(count('stun','bell')>count('fight','bell'));
  assert.ok(loop(score,3,'doom').every(e=>['pad','kick','bell','bass'].includes(e.i)));assert.ok(count('doom','kick',3)>count('fight','kick',1));
  assert.equal(count('fight','arp'),0);assert.ok(count('glare','arp')>0);
  assert.ok(loop(score,1,'intro').every(e=>e.i==='pad'||e.i==='kick'));
});
test('eye score: the mood follows the fight',()=>{
  const {G}=fight(),mood=()=>G.bossDefs.eye.music().mood;clearAll(G);
  assert.equal(mood(),'fight');
  G.bossDefs.eye.start('summon');assert.equal(mood(),'glare');
  shot(G,ers(G).sigil.x,ers(G).sigil.y+40,0,-14);assert.equal(mood(),'stun');run(G,4.1);assert.equal(mood(),'mend');run(G,1.3);assert.equal(mood(),'fight');
  G.bossDefs.eye.start('doom');assert.equal(mood(),'doom');
});
