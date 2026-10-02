import {test} from 'node:test';
import assert from 'node:assert/strict';
import {summarize} from './fx-profile.mjs';
test('CPU attribution includes only the evaluated whole-board strike subtree, not boss hits or tail drawing',()=>{
  const node=(id,name,url,children=[])=>({id,callFrame:{functionName:name,url,lineNumber:1},children});
  const profile={nodes:[node(1,'root','',[2,5,7]),node(2,'strike','',[3]),node(3,'G.hit','game.js',[4]),
    node(4,'format',''),node(5,'strike','milestone.js',[6]),node(6,'format',''),node(7,'render','render.js')],
    samples:[3,4,6,7],timeDeltas:[1000,2000,4000,8000]};
  const r=summarize(profile);assert.equal(r.sampledMs,15);assert.equal(r.burstMs,3);assert.equal(r.burstSamples,2);
  assert.deepEqual(r.burst.map(n=>n.selfMs),[2,1]);assert.equal(r.overall.length,3);
});
test('profiles without samples are supported and invalid deltas do not create misleading durations',()=>{
  assert.deepEqual(summarize({nodes:[]}).burst,[]);
  const n={id:1,callFrame:{functionName:'strike',url:'',lineNumber:0}};
  assert.equal(summarize({nodes:[n],samples:[1,1,1],timeDeltas:[-1,NaN,1000]}).burstMs,1);
});
