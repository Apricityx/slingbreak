import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createRequire} from 'node:module';
import {summarizeSkillBurst,rankBy,problemSkills,hotDrawMs,validateSkillBurstResult} from './skill-burst-summary.mjs';
const require=createRequire(import.meta.url),Matter=require('../game/vendor/matter.min.js');
const read=name=>fs.readFileSync(new URL('../'+name,import.meta.url),'utf8');
function boot(){
  const context=vm.createContext({Matter,console,window:{},URLSearchParams,location:{search:''},
    matchMedia:()=>({matches:false,addEventListener:()=>{}}),localStorage:{getItem:()=>null,setItem:()=>{}},
    document:{documentElement:{classList:{toggle:()=>{}}},getElementById:()=>({})}});
  for(const name of ['game/src/core/game.js','game/src/skills/skills.js','game/src/core/achievements.js',
    'game/src/skills/skill-expansion.js','game/src/skills/skill-overdrive.js','bench/fx-board.js'])
    vm.runInContext(read(name),context,{filename:name});
  return {G:context.window.Game,B:context.window.__FXBoard,context};
}
const outcome=n=>({destroyed:n,remaining:0,totalDelta:n,simulationAdvanced:0,coinDelta:1,shotMoney:1,levelMoney:1});
const zeroTail={particles:0,rings:0,bolts:0,texts:0,arrows:0,effects:0,tallies:0,signals:0,fields:0,dom:0};
function row(id,{burst=10,first=4,event=14,early=6,peak}={}){
  return {group:'skill-burst',id,name:id,n:240,rate:.22,tier:'none',
    burstMs:{median:burst},firstDrawMs:{median:first},eventMs:{median:event,max:event+2},
    updateMs:{max:1},costMs:{median:1},peaks:peak||{particles:1,effects:1,signals:0,fields:0},
    phases:[{costMs:{p95:early-1}},{costMs:{p95:early}}],
    runs:[{outcome:outcome(240),tail:{...zeroTail}}]};
}
function data(rows){return {results:rows,errors:[],pageErrors:[]};}

test('skill-burst driver plumbing stays wired to the isolated case list',()=>{
  assert.match(read('bench/fx-run.mjs'),/skillBurst:args\['skill-burst'\]==='1'/);
  assert.match(read('bench/fx-page.js'),/if\(O\.skillBurst\)for\(const c of window\.__FXBoard\.skillCases\(\)\.filter\(c=>c\.warmup\|\|filter\(c\)\)\)/);
  assert.match(read('bench/skill-burst.mjs'),/--skill-burst=1/);
  assert.match(read('bench/skill-burst.mjs'),/--filter=\^skill-burst\//);
});

test('skill-burst cases cover every catalog skill exactly once plus one baseline',()=>{
  const {G,B,context}=boot();
  const cases=B.skillCases();
  assert.equal(cases.length,G.skillCatalog.length+2);
  assert.equal(cases[0].id,'warmup');assert.equal(cases[0].warmup,true);assert.equal(cases[0].skills.length,0);
  assert.equal(cases[1].id,'none');assert.equal(cases[1].skills.length,0);
  assert.equal(new Set(cases.map(c=>c.id)).size,cases.length);
  for(const skill of G.skillCatalog){
    const c=cases.find(c=>c.id===skill.id);
    assert.ok(c,`missing case ${skill.id}`);
    assert.equal(c.skills.length,1);assert.equal(c.skills[0],skill.id);
    assert.equal(c.group,'skill-burst');assert.equal(c.n,240);assert.equal(c.rate,.22);
    assert.equal(c.level,50);assert.equal(c.loadout,'single');assert.equal(c.seed,843427);
    assert.equal(c.shotPhase,11);
  }
  context.window.__FX_OPTIONS__={boardCount:77,skillRate:0};
  const small=B.skillCases();
  assert.ok(small.every(c=>c.n===77&&c.rate===0));
  context.window.__FX_OPTIONS__={boardCount:240,skillRate:.5};
  assert.ok(B.skillCases().every(c=>c.n===240&&c.rate===.5));
});

test('every skill destroys the whole dense board exactly once in one instant',()=>{
  const {G,B}=boot();
  for(const c of B.skillCases()){
    B.install(G,c,false);
    assert.equal(G.bricks.length,c.n,`board size ${c.id}`);
    assert.equal(G.activeSkills().length,c.skills.length,`equipped ${c.id}`);
    if(!c.skills.length)assert.equal(G.activeSkills().length,0);
    else assert.equal(G.activeSkills()[0].id,c.id);
    assert.equal(G.shoot(0,100),true,`shoot ${c.id}`);
    const arrow=G.arrows[0],damage=arrow.damage;
    const result=B.strike(G,arrow);
    assert.equal(result.destroyed,c.n,`destroyed ${c.id}`);
    assert.equal(result.remaining,0,`remaining ${c.id}`);
    assert.equal(result.directCalls+result.recursiveKills,c.n,`calls ${c.id}`);
    assert.equal(result.simulationAdvanced,0,`sim time ${c.id}`);
    assert.equal(arrow.damage,damage,`damage restore ${c.id}`);
    assert.ok(G.particles.length<=300,`particle cap ${c.id}`);
    assert.ok(G.arrows.length<=64,`arrow cap ${c.id}`);
  }
});

test('skill-burst summary validates outcomes and ranks deltas against the baseline',()=>{
  const base=row('none');
  const warm=row('warmup',{burst:100,first:100,event:200,early:100});warm.warmup=true;
  const slow=row('slow',{burst:40,first:30,event:70,early:40,peak:{particles:300,effects:56,signals:80,fields:6}});
  const medium=row('medium',{burst:12,first:5,event:17,early:6});
  const drawHeavy=row('drawHeavy',{burst:10,first:10,event:14,early:6});
  const spike=row('spike',{burst:10,first:4,event:14,early:15});
  const mildSpike=row('mildSpike',{burst:10,first:4,event:14,early:12});
  const summary=summarizeSkillBurst(data([warm,base,slow,medium,drawHeavy,spike,mildSpike]));
  assert.equal(summary.rows.length,6);
  assert.equal(summary.rows.some(r=>r.id==='warmup'),false);
  assert.deepEqual(summary.baseline,{id:'none',burst:10,first:4,event:14,earlyP95:6});
  assert.equal(summary.rows.find(r=>r.id==='slow').burstDelta,30);
  assert.equal(summary.rows.find(r=>r.id==='slow').eventDelta,56);
  assert.equal(summary.rows.find(r=>r.id==='slow').eventPerBrick,70/240);
  assert.deepEqual(rankBy(summary.rows,'eventDelta').map(r=>r.id),['slow','medium','none','drawHeavy','spike','mildSpike']);
  assert.deepEqual(problemSkills(summary.rows,{baselineEvent:14}).map(r=>r.id),['slow','drawHeavy','spike']);
  assert.deepEqual(problemSkills(summary.rows,{baselineEvent:14,minEventDeltaMs:3}).map(r=>r.id),['slow','medium','drawHeavy','spike']);
  assert.deepEqual(problemSkills(summary.rows,{baselineEvent:14,minEventDeltaMs:100,minDrawDeltaMs:100,minEarlyDeltaMs:9}).map(r=>r.id),['slow','spike']);
  assert.equal(hotDrawMs(slow),40);
});

test('skill-burst summary rejects missing baselines and invalid whole-board outcomes',()=>{
  assert.throws(()=>summarizeSkillBurst(data([row('slow')])),/baseline/);
  const duplicate=data([row('slow'),row('slow')]);
  assert.throws(()=>summarizeSkillBurst(duplicate),/Duplicate/);
  const unresolved=data([row('none'),row('slow')]);
  unresolved.results[1].runs[0].outcome.remaining=1;
  assert.throws(()=>validateSkillBurstResult(unresolved),/whole board/);
  const alive=data([row('none'),row('slow')]);
  alive.results[1].runs[0].tail.effects=1;
  assert.throws(()=>validateSkillBurstResult(alive),/transient/);
  const lost=data([row('none')]);
  lost.results[0].runs[0].outcome.coinDelta=2;
  assert.throws(()=>validateSkillBurstResult(lost),/rewards/);
});
