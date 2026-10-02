import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {diagnoseSource} from './fx-diagnose.mjs';
import {instrument} from './fx-instrument.mjs';
test('diagnostic lexical probes remain test-only, parse and compose with the existing private hooks',()=>{
  for(const name of ['game.js','skills.js','achievements.js','render.js','fx.js','audio.js','ui.js','skills-ui.js',
    'skill-signatures.js','skill-effects.js','skill-expansion.js','skill-overdrive.js','achievements-ui.js','juice.js','transitions.js','milestone.js']){
    const original=fs.readFileSync(name,'utf8'),probe=diagnoseSource(name,original);
    assert.notEqual(probe,original,name);assert.doesNotThrow(()=>new vm.Script(instrument(name,probe)),name);
    assert.equal(fs.readFileSync(name,'utf8'),original);
  }
  assert.equal(diagnoseSource('palette.js','const x=1;'),'const x=1;');
});
test('diagnostic timing preserves return values, this, nesting, exceptions and disable/reset boundaries',()=>{
  class Storage{setItem(){}}
  class Element{animate(){}getBoundingClientRect(){}}
  class HTMLElement extends Element{}
  class CanvasRenderingContext2D{}
  let now=0;const win={};
  const c=vm.createContext({window:win,performance:{now:()=>now,mark(){}},Storage,Element,HTMLElement,CanvasRenderingContext2D,JSON:Object.create(JSON)});
  vm.runInContext(fs.readFileSync('bench/fx-diagnose.js','utf8'),c);const D=win.__FXDiagnose;
  const self={v:3},leaf=D.wrap('leaf',function(n){now+=10;return this.v+n;});
  const root=D.wrap('root',function(n){now+=2;const v=leaf.call(this,n);now+=3;return v;});
  assert.equal(root.call(self,4),7);assert.equal(D.data.totals.length,0);
  D.begin('example');assert.equal(root.call(self,4),7);D.end();
  const t=new Map(D.data.totals.map(t=>[t.name,t]));assert.equal(t.get('root').totalMs,15);assert.equal(t.get('root').selfMs,5);
  assert.equal(t.get('leaf').totalMs,10);assert.equal(D.data.slow[0].context,'example');
  D.begin('throws');assert.throws(()=>D.scope('failure',()=>{now+=8;throw Error('sentinel');}),/sentinel/);D.end();
  assert.equal(D.data.totals.find(t=>t.name==='failure').maxMs,8);D.reset();assert.equal(D.data.totals.length,0);
});
