const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');

function boot(){
  const noop=()=>{},skill={id:'titan',name:'泰坦',icon:'arrow'},G={state:{skills:{titan:1}},time:3,H:1100,reduced:true,bricks:[],arrows:[],skillCatalog:[skill],skillSlots:1,activeSkills:()=>[skill],outgoingSkill:()=>null,skillRank:()=>0};
  const element=()=>({style:{setProperty:noop},dataset:{},classList:{add:noop,remove:noop},before:noop,querySelector:()=>element(),replaceChildren:noop,append:noop,setAttribute:noop,addEventListener:noop});
  const context={window:{Game:G},document:{createElement:element,getElementById:element,documentElement:element()},lucide:{createIcons:noop}};
  vm.createContext(context);
  for(const file of ['colors.js','skill-effects.js','boss-serpent.js'])vm.runInContext(fs.readFileSync(__dirname+'/'+file,'utf8'),context);
  const def=context.window.SlingBosses[0]({G,Composite:{},Body:{},has:()=>false,rage:()=>false,fight:()=>({data:{regrowth:0}}),dying:()=>null,introAge:()=>Infinity});
  return {G,def};
}
function canvas(){
  const strokes=[],stack=[],state={lineWidth:1,lineCap:'butt',lineJoin:'miter',globalAlpha:1,strokeStyle:'#000000',fillStyle:'#000000'};
  const ctx=new Proxy(state,{get(t,key){
    if(key in t)return t[key];
    if(key==='save')return ()=>stack.push({...state});
    if(key==='restore')return ()=>Object.assign(state,stack.pop());
    if(key==='stroke')return ()=>strokes.push({...state});
    if(key==='createRadialGradient')return ()=>({addColorStop(){}});
    return ()=>{};
  }});
  return {ctx,strokes};
}
test('frozen brick and serpent scale corners explicitly use thin strokes even after a 70px background brush',()=>{
  const {G,def}=boot(),{ctx,strokes}=canvas();def.drawBack(ctx);
  assert.equal(ctx.lineWidth,70,'reproduce the serpent backdrop brush');
  G.bricks=[{x:100,y:100,w:84,h:44,type:'normal',frozen:true},{x:100,y:200,w:40,h:40,type:'scale',frozen:true}];
  for(let frame=0;frame<2;frame++)G.drawSkillEffects(ctx,'field');
  const corners=strokes.filter(s=>s.strokeStyle==='#258eb2');
  assert.equal(corners.length,8);assert.ok(corners.every(s=>s.lineWidth===1.5&&s.lineCap==='round'));
  assert.equal(ctx.lineWidth,70,'the corner painter also restores its caller state');
});
test('dense effects retain every hit signature but bound large shockwaves and hero lights',()=>{
  const {G}=boot();G.reduced=false;G.origin={x:390,y:900};G.bricks=[];
  const signatures=[],lights=[];G.paintSkillSignature=(ctx,id,t,r)=>signatures.push({id,r});G.fx={glow:(...args)=>lights.push(args)};
  const skill={id:'titan',kind:'power',x:100,y:200,r:75,duration:1,born:2.5,color:'#ff8833',accent:'#ffffff',hero:true};
  // Insert private fixtures only into this VM, never expose production state.
  const source=fs.readFileSync(__dirname+'/skill-effects.js','utf8').replace('  refresh();\n})();','  G.testEffects=effects;refresh();\n})();');
  const noop=()=>{},el=()=>({style:{setProperty:noop},dataset:{},classList:{add:noop,remove:noop},before:noop,querySelector:()=>el(),replaceChildren:noop,append:noop,setAttribute:noop,addEventListener:noop});
  const context={window:{Game:G},document:{createElement:el,getElementById:el,documentElement:el()},lucide:{createIcons:noop}};vm.createContext(context);vm.runInContext(fs.readFileSync(__dirname+'/colors.js','utf8'),context);vm.runInContext(source,context);
  for(let i=0;i<56;i++)G.testEffects.push({...skill});
  G.drawSkillEffects(canvas().ctx,'field');assert.equal(signatures.length,56);assert.equal(signatures.filter(s=>s.r>24).length,24);assert.equal(lights.length,6);
  signatures.length=0;lights.length=0;G.testEffects.forEach(e=>{e.r=650;e.kind='nova';});
  G.drawSkillEffects(canvas().ctx,'field');assert.equal(signatures.length,56);assert.equal(signatures.filter(s=>s.r>24).length,4);
  G.reduced=true;signatures.length=0;G.drawSkillEffects(canvas().ctx,'field');assert.equal(signatures.filter(s=>s.r>24).length,2);
});
