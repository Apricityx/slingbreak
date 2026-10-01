const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
test('opening impact retains 60 rotated fragments with only three colour fills',()=>{
  const calls=[],noop=()=>{},ctx=new Proxy({globalAlpha:1},{get(t,key){if(key in t)return t[key];return (...args)=>calls.push([key,args]);}});
  const elements=new Map(),el=()=>({classList:{add:noop,remove:noop,contains:()=>false},addEventListener:noop,showModal:noop,close:noop,focus:noop,getContext:()=>ctx});
  const Game={reduced:false,phase:'ready',ui:noop},intro={active:false};
  const context={Game,window:{SlingBreakIntro:intro,SlingTheme:{canvas:{intro:{dot:'#cdd3c6',frame:'#24351b',blocks:['#b6ed66','#f67b65','#dce4d4'],sheen:'#ffffff70'}}}},
    document:{documentElement:el(),getElementById:id=>{if(!elements.has(id))elements.set(id,el());return elements.get(id);},addEventListener:noop,removeEventListener:noop},
    matchMedia:()=>({matches:false,addEventListener:noop,removeEventListener:noop}),URLSearchParams,location:{search:''},devicePixelRatio:2,
    performance:{now:()=>0},requestAnimationFrame:()=>1,cancelAnimationFrame:noop,setTimeout:()=>1,clearTimeout:noop};
  const source=fs.readFileSync(__dirname+'/intro.js','utf8').replace('})();','Game.paintTest=()=>draw(start+1400);})();');
  vm.createContext(context);vm.runInContext(source,context);Game.paintTest();
  assert.equal(calls.filter(c=>c[0]==='closePath').length,60);
  assert.equal(calls.filter(c=>c[0]==='fill').length,4,'three fragment colours and one sparse-dot path');
  assert.equal(calls.filter(c=>c[0]==='rotate'||c[0]==='translate').length,0,'fragment vertices rotate directly without canvas state churn');
  const before=calls.map(c=>JSON.stringify(c));calls.length=0;Game.paintTest();
  // The first paint's canvas scale happens during module setup, not per frame.
  assert.deepEqual(calls.map(c=>JSON.stringify(c)),before.filter(c=>!c.startsWith('["scale"')));
});
