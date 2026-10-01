const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const paletteSource=fs.readFileSync(__dirname+'/palette.js','utf8');
const settingsSource=fs.readFileSync(__dirname+'/settings.js','utf8');

// palette.js runs in <head>: it only needs <html>, the theme-color meta,
// localStorage and the prefers-color-scheme query.
function boot({stored=null,systemDark=false,withSettings=false,withAudio=false}={}){
  const storage=new Map(stored==null?[]:[['slingbreak-theme',stored]]);
  const attrs=new Map(),classes=new Set(),metaAttrs=new Map(),listeners={};
  const scheme={matches:systemDark,addEventListener:(name,fn)=>{listeners.scheme=fn;}};
  const root={style:{},setAttribute:(k,v)=>attrs.set(k,String(v)),classList:{add:c=>classes.add(c),remove:c=>classes.delete(c)}};
  const meta={setAttribute:(k,v)=>metaAttrs.set(k,v)};
  const el=(extra={})=>({handlers:{},addEventListener(name,fn){const previous=this.handlers[name];this.handlers[name]=previous?(...args)=>{previous(...args);fn(...args);}:fn;},...extra});
  const radios=['system','light','dark'].map(value=>el({value,checked:false}));
  const dialog=el({open:false,showModal(){this.open=true;},close(){this.open=false;},querySelectorAll:()=>radios});
  const hint={textContent:''};
  const elements=withSettings?{'settings-toggle':el(),settings:dialog,'close-settings':el(),'theme-hint':hint}:{};
  const window={localStorage:{getItem:k=>storage.has(k)?storage.get(k):null,setItem:(k,v)=>storage.set(k,v)}};
  const calls=[];
  if(withAudio){
    window.Game={state:{volume:80,sound:true,performanceMode:false},reduced:false,setPerformanceMode(on){this.state.performanceMode=on;this.reduced=on;calls.push('performance');},audio:{sync:()=>calls.push('sync'),unlock:()=>calls.push('unlock')},save:()=>calls.push('save')};
    elements['sound-volume']=el({value:''});elements['sound-volume-value']={textContent:''};
    elements['performance-mode']=el({checked:false});
  }
  const context={window,console,setTimeout:()=>0,clearTimeout(){},
    matchMedia:q=>q.includes('color-scheme')?scheme:{matches:false},
    document:{documentElement:root,querySelector:s=>s.includes('theme-color')?meta:null,getElementById:id=>elements[id]||null}};
  vm.createContext(context);
  vm.runInContext(paletteSource,context);
  if(withSettings)vm.runInContext(settingsSource,context);
  return {theme:window.SlingTheme,game:window.Game,calls,storage,attrs,classes,metaAttrs,scheme,listeners,radios,dialog,hint,elements};
}

test('defaults to following the system scheme',()=>{
  const light=boot();
  assert.equal(light.theme.mode,'system');
  assert.equal(light.attrs.get('data-theme'),'light');
  const dark=boot({systemDark:true});
  assert.equal(dark.attrs.get('data-theme'),'dark');
  assert.equal(dark.theme.canvas,dark.theme.palettes.dark);
  assert.equal(dark.metaAttrs.get('content'),dark.theme.palettes.dark.pageMeta,'browser chrome follows the page');
});

test('an explicit choice persists and overrides the system scheme',()=>{
  const {theme,storage,attrs}=boot({systemDark:true});
  theme.set('light');
  assert.equal(storage.get('slingbreak-theme'),'light');
  assert.equal(attrs.get('data-theme'),'light');
  assert.equal(attrs.get('data-theme-mode'),'light');
  assert.equal(boot({stored:'dark'}).attrs.get('data-theme'),'dark','a stored choice applies on the next load');
});

test('unknown stored values fall back to system and invalid modes are ignored',()=>{
  const {theme,attrs}=boot({stored:'sepia'});
  assert.equal(theme.mode,'system');
  theme.set('neon');
  assert.equal(theme.mode,'system');
  assert.equal(attrs.get('data-theme'),'light');
});

test('system mode tracks OS changes; explicit modes ignore them',()=>{
  const {theme,attrs,scheme,listeners}=boot();
  const seen=[];theme.onChange(t=>seen.push(t.resolved));
  scheme.matches=true;listeners.scheme();
  assert.equal(attrs.get('data-theme'),'dark');
  theme.set('light');
  scheme.matches=false;listeners.scheme();scheme.matches=true;listeners.scheme();
  assert.equal(attrs.get('data-theme'),'light');
  assert.deepEqual(seen,['dark','light']);
});

test('works without storage or a DOM (game scripts under node)',()=>{
  const context={window:{},console};
  vm.createContext(context);
  assert.doesNotThrow(()=>vm.runInContext(paletteSource,context));
  assert.equal(context.window.SlingTheme.resolved,'light');
  assert.doesNotThrow(()=>context.window.SlingTheme.set('dark'));
});

// WCAG relative luminance contrast.
const lum=hex=>{const c=[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255).map(v=>v<=.03928?v/12.92:((v+.055)/1.055)**2.4);return .2126*c[0]+.7152*c[1]+.0722*c[2];};
const contrast=(a,b)=>{const x=lum(a),y=lum(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05);};
const shape=o=>Object.fromEntries(Object.entries(o).map(([k,v])=>[k,typeof v==='object'&&!Array.isArray(v)?shape(v):typeof v]));

test('light and dark canvas palettes define the same keys',()=>{
  const {palettes}=boot().theme;
  const {brickEdge:a,...light}=palettes.light,{brickEdge:b,...dark}=palettes.dark;
  assert.deepEqual(shape(light),shape(dark));
});

test('brick HP numbers stay readable on every brick fill in both themes',()=>{
  for(const [name,p] of Object.entries(boot().theme.palettes)){
    for(const type of Object.keys(p.brick))
      assert.ok(contrast(p.brickInk[type],p.brick[type])>=4.5,`${name} ${type}: ${contrast(p.brickInk[type],p.brick[type]).toFixed(2)}`);
    assert.ok(contrast(p.brickInk.normal,p.frozen)>=4.5,`${name} frozen brick`);
    assert.ok(contrast(p.brick.lightning,p.brick.gold)>=1.3,`${name}: lightning and gold need a lightness gap, not just hue`);
  }
});

test('settings dialog reflects and changes the theme',()=>{
  const {theme,radios,dialog,hint,elements,classes,attrs}=boot({withSettings:true,systemDark:true});
  assert.equal(radios.find(r=>r.checked).value,'system');
  assert.match(hint.textContent,/跟随系统.*深色/);
  elements['settings-toggle'].handlers.click();
  assert.ok(dialog.open);
  const light=radios.find(r=>r.value==='light');light.checked=true;light.handlers.change();
  assert.equal(theme.mode,'light');
  assert.equal(attrs.get('data-theme'),'light');
  assert.ok(classes.has('theme-switching'),'colours cross-fade for one beat');
  assert.equal(hint.textContent,'始终使用亮色');
  assert.deepEqual(radios.filter(r=>r.checked).map(r=>r.value),['light']);
  elements['close-settings'].handlers.click();
  assert.ok(!dialog.open);
});
test('volume control updates and saves immediately, including zero and reload state',()=>{
  const {game,calls,elements}=boot({withSettings:true,withAudio:true});
  const slider=elements['sound-volume'],value=elements['sound-volume-value'];
  assert.equal(slider.value,'80');assert.equal(value.textContent,'80%');
  slider.value='0';slider.handlers.input();
  assert.equal(game.state.volume,0);assert.equal(game.state.sound,false);
  assert.equal(value.textContent,'0%');assert.deepEqual(calls,['sync','save']);
  slider.value='25';slider.handlers.input();
  assert.equal(game.state.volume,25);assert.equal(game.state.sound,true);
  assert.deepEqual(calls,['sync','save','sync','unlock','save']);
  game.state.volume=40;elements['settings-toggle'].handlers.click();
  assert.equal(slider.value,'40');assert.equal(value.textContent,'40%');
});
test('performance checkbox reflects saved preference and updates game mode',()=>{
  const {game,calls,elements}=boot({withSettings:true,withAudio:true});
  const checkbox=elements['performance-mode'];
  assert.equal(checkbox.checked,false);
  checkbox.checked=true;checkbox.handlers.change();
  assert.equal(game.state.performanceMode,true);assert.deepEqual(calls,['performance']);
  checkbox.checked=false;elements['settings-toggle'].handlers.click();
  assert.equal(checkbox.checked,true,'opening settings restores the saved preference');
  checkbox.checked=false;checkbox.handlers.change();
  assert.equal(game.state.performanceMode,false);assert.deepEqual(calls,['performance','performance']);
});
