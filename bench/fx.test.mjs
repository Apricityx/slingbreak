import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {instrument,bootstrap} from './fx-instrument.mjs';

test('test-only instrumentation keeps every modified response valid JavaScript',()=>{
  for(const name of ['game/src/render/render.js','game/src/effects/skill-effects.js','game/src/effects/juice.js','game/src/skills/skill-expansion.js','game/src/skills/skill-overdrive.js',
    'game/src/effects/intro.js','game/src/effects/transitions.js','game/src/ui/achievements-ui.js','game/src/bosses/boss-eye.js','game/src/bosses/boss-forge.js','game/src/bosses/boss-clock.js','game/src/bosses/boss-serpent.js']){
    const source=fs.readFileSync(new URL('../'+name,import.meta.url),'utf8');
    const result=instrument(name,source);
    assert.notEqual(result,source,name);
    assert.doesNotThrow(()=>new vm.Script(result,{filename:name}));
    assert.equal(fs.readFileSync(new URL('../'+name,import.meta.url),'utf8'),source,'instrument() must not write shipping source');
  }
});
test('unrelated JavaScript is served unchanged',()=>{
  const source=fs.readFileSync(new URL('../game/src/core/game.js',import.meta.url),'utf8');
  assert.equal(instrument('game/src/core/game.js',source),source);
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
  assert.doesNotThrow(()=>new vm.Script(fs.readFileSync(new URL('./fx-page.js',import.meta.url),'utf8')));
});
