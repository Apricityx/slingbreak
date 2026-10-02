import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url),Matter=require('../vendor/matter.min.js');
const read=name=>fs.readFileSync(new URL('../'+name,import.meta.url),'utf8');
function boot(){
  const context=vm.createContext({Matter,console,window:{},URLSearchParams,location:{search:''},
    matchMedia:()=>({matches:false,addEventListener:()=>{}}),localStorage:{getItem:()=>null,setItem:()=>{}},
    document:{documentElement:{classList:{toggle:()=>{}}},getElementById:()=>({})}});
  for(const name of ['game.js','skills.js','achievements.js','bench/fx-board.js'])vm.runInContext(read(name),context,{filename:name});
  return {G:context.window.Game,B:context.window.__FXBoard};
}
test('the browser helper stays test-only and parses without a build step',()=>{
  assert.doesNotThrow(()=>new vm.Script(read('bench/fx-board.js')));
  assert.doesNotMatch(read('index.html'),/fx-board\.js/);
});
test('whole-board fixtures are deterministic, bounded, non-overlapping and include all five special types',()=>{
  const {B}=boot();
  assert.equal(B.cases().length,12);
  assert.equal(new Set(B.cases().map(c=>c.id+'/'+c.n)).size,12);
  for(const c of B.cases()){
    const f=B.fixture(c.n,c.rate,c.seed,7),again=B.fixture(c.n,c.rate,c.seed,7);
    assert.equal(JSON.stringify(f),JSON.stringify(again));assert.equal(f.bricks.length,c.n);
    assert.equal(f.quota,Math.floor(c.n*c.rate));assert.equal(f.actualRate,f.quota/c.n);
    assert.equal(Object.values(f.counts).reduce((a,b)=>a+b,0),c.n);
    for(const b of f.bricks){
      assert.equal(b.hp,7);assert.equal(b.max,7);assert.ok(b.x-b.w/2>0&&b.x+b.w/2<780);
      assert.ok(b.y-b.h/2>100&&b.y+b.h/2<970);
      for(const other of f.bricks)if(other!==b)assert.ok(Math.abs(b.x-other.x)>=(b.w+other.w)/2||Math.abs(b.y-other.y)>=(b.h+other.h)/2);
    }
    if(c.rate)for(const type of ['bomb','lightning','frost','prism','gold'])assert.ok(f.counts[type]>0);
    else assert.equal(f.counts.normal,c.n);
  }
  assert.throws(()=>B.fixture(241,.22));assert.throws(()=>B.fixture(77,1));
});
test('every stress case restores real Matter bricks and kills/rewards each once in one simulation instant',()=>{
  for(const reduced of [false,true])for(const c of boot().B.cases()){
    const {G,B}=boot(),f=B.install(G,c,reduced);
    assert.equal(G.initial,c.n);assert.equal(G.bricks.length,c.n);
    assert.deepEqual(Object.fromEntries(Object.keys(f.counts).map(type=>[type,G.bricks.filter(b=>b.type===type).length])),{...f.counts});
    assert.ok(G.bricks.every(b=>G.engine.world.bodies.includes(b.body)&&b.body.brick===b));
    const seen=new Set(),destroyed=G.onBrickDestroyed;
    G.onBrickDestroyed=(b,...args)=>{assert.equal(seen.has(b.body.id),false,'a brick must not be rewarded/destroyed twice');seen.add(b.body.id);return destroyed?.(b,...args);};
    assert.equal(G.shoot(0,100),true);
    const arrow=G.arrows[0],damage=arrow.damage,result=B.strike(G,arrow);
    assert.equal(arrow.damage,damage);assert.equal(G.activeArrow,undefined);
    assert.equal(result.destroyed,c.n);assert.equal(result.totalDelta,c.n);assert.equal(result.remaining,0);
    assert.equal(seen.size,c.n);
    assert.equal(result.simulationAdvanced,0);assert.equal(result.coreSpawned,true);
    assert.equal(result.coinDelta,G.state.coins);assert.equal(result.coinDelta,G.levelMoney);
    assert.equal(result.coinDelta,G.shotMoney);assert.ok(result.coinDelta>0);
    assert.equal(result.directCalls+result.recursiveKills,c.n);assert.ok(result.directCalls>0);
    assert.ok(G.particles.length<=300);assert.ok(G.arrows.length<=64);
    assert.ok(G.rings.length<=(reduced?24:48));
    assert.equal(G.engine.world.bodies.some(b=>b.label==='brick'),false);
    // A second sweep of an empty board must not give the same rewards again.
    const coins=G.state.coins;assert.throws(()=>B.strike(G,arrow),/rewards/);assert.equal(G.state.coins,coins);
  }
});
test('lethal damage override and active-arrow scope are restored even if a hook throws',()=>{
  const {G,B}=boot(),c=B.cases()[0];B.install(G,c,false);G.shoot(0,100);
  const arrow=G.arrows[0],damage=arrow.damage;
  G.projectileHit=()=>{throw Error('fixture failure');};
  assert.throws(()=>B.strike(G,arrow),/fixture failure/);
  assert.equal(arrow.damage,damage);assert.equal(G.activeArrow,undefined);
});
