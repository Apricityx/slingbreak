const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync(__dirname+'/fx.js','utf8');
function canvas(){
  const calls=[],stack=[],state={globalAlpha:1,lineWidth:1,fillStyle:'#000000',strokeStyle:'#000000'};
  const ctx=new Proxy(state,{get(t,key){
    if(key in t)return t[key];
    if(key==='save')return ()=>stack.push({...state});
    if(key==='restore')return ()=>Object.assign(state,stack.pop());
    if(key==='createRadialGradient'||key==='createLinearGradient')return (...args)=>{calls.push([key,args]);return {addColorStop(){}};};
    return (...args)=>calls.push([key,args]);
  }});return {ctx,calls};
}
function boot({dom=true}={}){
  const layers=[],G={state:{performanceMode:false},view:{scale:1},reduced:false};let themeChange;
  const context={window:{Game:G,SlingStage:{k:.5},SlingTheme:{onChange:fn=>{themeChange=fn;}}},devicePixelRatio:2};
  if(dom)context.document={createElement:()=>{const layer=canvas();layers.push(layer);return {getContext:()=>layer.ctx};}};
  vm.createContext(context);vm.runInContext(source,context);
  return {G,context,layers,themeChange:()=>themeChange()};
}
test('FX sprites reuse paint, evict least-recent entries, and respect byte and entry limits',()=>{
  const {G}=boot();let paints=0;const paint=()=>paints++;
  const first=G.fx.sprite('first',20,20,paint);assert.equal(G.fx.sprite('first',20,20,paint),first);assert.equal(paints,1);
  for(let i=0;i<500;i++)G.fx.sprite('small:'+i,20,20,paint);
  assert.equal(G.fx.stats().entries,384);assert.notEqual(G.fx.sprite('first',20,20,paint),first);
  for(let i=0;i<40;i++)G.fx.sprite('large:'+i,512,512,paint);
  assert.ok(G.fx.stats().bytes<=G.fx.stats().maxBytes);
  assert.equal(G.fx.sprite('oversized',3000,3000,paint),null);
});
test('theme changes invalidate FX colour textures without modifying gameplay state',()=>{
  const {G,themeChange}=boot();const state=G.state;
  G.fx.sprite('a',20,20,()=>{});themeChange();assert.equal(G.fx.stats().bytes,0);assert.equal(G.fx.stats().entries,0);assert.equal(G.state,state);
});
test('glow restores brush alpha and repeated gradient sizes reuse one texture',()=>{
  const {G,layers}=boot(),{ctx,calls}=canvas();ctx.globalAlpha=.7;
  assert.equal(G.fx.glow(ctx,1,2,30,'#ffaa33',.4),true);assert.equal(ctx.globalAlpha,.7);
  G.fx.glow(ctx,100,200,100,'#ffaa33',.8);
  assert.equal(layers.length,1);assert.equal(layers[0].calls.filter(c=>c[0]==='createRadialGradient').length,1);
  assert.equal(calls.filter(c=>c[0]==='drawImage').length,2);
});
test('slow atmosphere layer updates at its requested cadence and resets after time rewinds',()=>{
  const {G}=boot(),{ctx}=canvas();let paints=0;
  const draw=t=>G.fx.layer(ctx,'sky',780,1100,t,()=>paints++,.5,30);
  draw(1);draw(1.01);assert.equal(paints,1);draw(1.04);assert.equal(paints,2);draw(0);assert.equal(paints,3);
});
test('all 81 signature silhouettes render through bounded caching in both modes',()=>{
  const {G,context}=boot(),{ctx,calls}=canvas();
  vm.runInContext(fs.readFileSync(__dirname+'/skill-signatures.js','utf8'),context);
  const ids=[...fs.readFileSync(__dirname+'/skills.js','utf8').matchAll(/entry\('([^']+)'/g)].map(m=>m[1]);assert.equal(ids.length,81);
  for(const reduced of [false,true]){G.reduced=reduced;for(const id of ids)for(const r of [12,75,190])G.paintSkillSignature(ctx,id,.5,r,'#785fb0','#53a59b','impact');}
  assert.ok(calls.some(c=>c[0]==='drawImage'));assert.ok(calls.some(c=>c[0]==='stroke'));
  assert.ok(G.fx.stats().entries<=384);assert.ok(G.fx.stats().bytes<=G.fx.stats().maxBytes);
});
test('signature cache tracks pose, theme colours, aura, reduction and effective density',()=>{
  const {G,context,layers}=boot(),{ctx}=canvas();const paint=()=>{};
  const draw=(p=.5,accent='#ffaa33',stage='impact')=>G.fx.signature(ctx,paint,'test',p,75,'#ffffff',accent,stage);
  draw();draw(.501);assert.equal(layers.length,1);
  draw(.7);draw(.7,'#ff0033');draw(.7,'#ff0033','aura');assert.equal(layers.length,4);
  G.reduced=true;draw();assert.equal(layers.length,5);
  context.window.SlingStage.k=1;draw();assert.equal(layers.length,6);
});
test('FX absence of a canvas keeps vector fallback functional',()=>{
  const {G,context}=boot({dom:false}),{ctx,calls}=canvas();
  assert.equal(G.fx.glow(ctx,0,0,40,'#ffaa33'),false);
  vm.runInContext(fs.readFileSync(__dirname+'/skill-signatures.js','utf8'),context);
  G.paintSkillSignature(ctx,'blizzard',.5,75,'#258eb2','#ffffff');
  assert.ok(calls.some(c=>c[0]==='stroke'));assert.ok(!calls.some(c=>c[0]==='drawImage'));
});
test('cold signature builds have a per-frame budget, while hits remain unlimited',()=>{
  const {G}=boot(),{ctx}=canvas();let paints=0;const paint=()=>paints++;
  const draw=p=>G.fx.signature(ctx,paint,'blizzard',p,75,'#258eb2','#ffffff','impact');
  G.fx.beginFrame();assert.equal(draw(.1),true);assert.equal(draw(.3),true);assert.equal(draw(.5),false);
  for(let i=0;i<10;i++)assert.equal(draw(.1),true);assert.equal(paints,2);
  G.fx.beginFrame();assert.equal(draw(.5),true);assert.equal(paints,3);
});
test('shards batch by opacity without transforms and preserve the caller brush',()=>{
  const {G}=boot(),{ctx,calls}=canvas();ctx.globalAlpha=.3;ctx.lineWidth=7;
  const list=Array.from({length:300},(_,i)=>({x:i,y:i,a:i,s:10,born:1}));
  G.fx.shards(ctx,list,1.4,'#ffaa33','#ffffff');
  assert.equal(ctx.globalAlpha,.3);assert.equal(ctx.lineWidth,7);
  assert.ok(calls.filter(c=>c[0]==='moveTo').length<=96);assert.ok(calls.filter(c=>c[0]==='fill').length<=4);
  assert.ok(!calls.some(c=>c[0]==='translate'||c[0]==='rotate'));
});
