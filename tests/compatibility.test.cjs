const ROOT=require('node:path').resolve(__dirname,'..');
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=file=>fs.readFileSync(ROOT+'/'+file,'utf8');
const html=source('game/index.html');

test('shipped scripts and browser benchmarks do not require post-89 collection APIs',()=>{
  const files=[...html.matchAll(/<script src="([^"]+)"/g)].map(m=>'game/'+m[1]);
  files.push('bench/particles.js','bench/fx-page.js','bench/fx-board.js');
  for(const file of files){
    assert.doesNotMatch(source(file),/\.(?:at|findLast|findLastIndex|toSorted|toReversed|toSpliced|with)\s*\(/,file);
    assert.doesNotMatch(source(file),/Object\.hasOwn\s*\(|\bstructuredClone\s*\(|crypto\.randomUUID\s*\(/,file);
  }
});

test('all shipping styles use Chromium 89 selectors, colours and composed transforms',()=>{
  for(const file of fs.readdirSync(ROOT+'/game/styles').filter(name=>name.endsWith('.css')).map(name=>'game/styles/'+name)){
    const css=source(file).replace(/\/\*[\s\S]*?\*\//g,'');
    assert.doesNotMatch(css,/color-mix\(|:has\(|(?:^|[;{])\s*(?:translate|rotate|scale|accent-color)\s*:|overflow\s*:\s*clip|\d(?:dvh|svh|lvh|cqw|cqh)\b/,file);
  }
});

test('viewport-pixel skill flight is excluded from stage-zoomed dialogs',()=>{
  const css=source('game/styles/mobile.css').replace(/\/\*[\s\S]*?\*\//g,'');
  assert.match(css,/dialog:not\(#game-intro\):not\(\.skill-flight\)/);
  for(const rule of css.matchAll(/([^{}]+)\{([^{}]+)\}/g)){
    if(!/zoom:\s*var\(--stage-k\)/.test(rule[2]))continue;
    for(const selector of rule[1].split(',')){
      assert.notEqual(selector.trim(),'.skill-flight','flight must not be stage-zoomed');
      if(/\bdialog\b/.test(selector))assert.match(selector,/:not\(\.skill-flight\)/);
    }
  }
  const ui=source('game/src/ui/skills-ui.js');
  const commit=ui.indexOf('if(!G.chooseSkill(id))return;');
  const flush=ui.indexOf('G.flushUi();',commit);
  assert.ok(flush>commit&&flush<ui.indexOf('landed=hudQueue()',commit),
    'flush queued layout writes before resolving the real destination');
});

test('every sRGB companion channel matches its static theme token',()=>{
  const css=source('game/styles/tokens.css');let checked=0;
  for(const block of css.matchAll(/\{([^{}]+)\}/g)){
    const declarations=new Map([...block[1].matchAll(/(--[\w-]+):\s*([^;]+);/g)].map(m=>[m[1],m[2].trim()]));
    for(const [name,value] of declarations){
      if(!/^#[\da-f]{6}$/i.test(value)||!declarations.has(name+'-r'))continue;
      for(const [i,c] of [...'rgb'].entries())assert.equal(Number(declarations.get(name+'-'+c)),parseInt(value.slice(1+i*2,3+i*2),16),name+'-'+c);
      checked++;
    }
  }
  assert.ok(checked>=30);
});

test('all blend references are defined, and colour support loads before its consumers',()=>{
  const definitions=new Set([...source('game/styles/color-blends.css').matchAll(/(--mix-[\w-]+):/g)].map(m=>m[1]));
  for(const file of fs.readdirSync(ROOT+'/game/styles').filter(name=>name.endsWith('.css')).map(name=>'game/styles/'+name)){
    for(const ref of source(file).matchAll(/var\((--mix-[\w-]+)\)/g))assert.ok(definitions.has(ref[1]),file+': '+ref[1]);
  }
  assert.ok(html.indexOf('src/theme/colors.js')<html.indexOf('src/effects/skill-effects.js'));
  assert.ok(html.includes('href="styles/color-blends.css"'));
});

test('dynamic colours keep exact RGB channels and reject unsafe inline CSS',()=>{
  const context=vm.createContext({window:{}});vm.runInContext(source('game/src/theme/colors.js'),context);
  const C=context.window.SlingColors,props=new Map();
  assert.deepEqual(Array.from(C.channels('#abc')),[170,187,204]);
  assert.deepEqual(Array.from(C.channels('#439be8')),[67,155,232]);
  C.set({style:{setProperty:(key,value)=>props.set(key,String(value))}},'--skill-color','#439be8');
  assert.equal(props.get('--skill-color-r'),'67');assert.equal(props.get('--skill-color-g'),'155');assert.equal(props.get('--skill-color-b'),'232');
  assert.equal(C.style('--skill-color','#abc'),'--skill-color:#abc;--skill-color-r:170;--skill-color-g:187;--skill-color-b:204;');
  assert.throws(()=>C.channels('red;opacity:0'),/opaque hex/);
});
