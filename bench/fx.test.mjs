import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {instrument,bootstrap} from './fx-instrument.mjs';

test('test-only instrumentation keeps every modified response valid JavaScript',()=>{
  for(const name of ['render.js','skill-effects.js','juice.js','skill-expansion.js','skill-overdrive.js',
    'intro.js','transitions.js','achievements-ui.js','boss-eye.js','boss-forge.js','boss-clock.js','boss-serpent.js']){
    const source=fs.readFileSync(name,'utf8');
    const result=instrument(name,source);
    assert.notEqual(result,source,name);
    assert.doesNotThrow(()=>new vm.Script(result,{filename:name}));
    assert.equal(fs.readFileSync(name,'utf8'),source,'instrument() must not write shipping source');
  }
});
test('unrelated JavaScript is served unchanged',()=>{
  const source=fs.readFileSync('game.js','utf8');
  assert.equal(instrument('game.js',source),source);
});
test('bootstrap attaches audit state without replacing the Game object or ticking it',()=>{
  const win={requestAnimationFrame:()=>19};
  const context=vm.createContext({window:win});
  vm.runInContext(bootstrap,context);
  const game={particles:[]};win.Game=game;
  assert.equal(win.Game,game);assert.ok(game.__audit.bosses);
  assert.equal(win.requestAnimationFrame(()=>{}),0);
  assert.equal(win.__nativeRAF(()=>{}),19);
});
test('the complete benchmark driver parses as standalone JavaScript',()=>{
  assert.doesNotThrow(()=>new vm.Script(fs.readFileSync('bench/fx-page.js','utf8')));
});
