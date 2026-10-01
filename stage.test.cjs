const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const source=fs.readFileSync(__dirname+'/stage.js','utf8');

// Boots stage.js against a minimal DOM and returns window.SlingStage.
function boot({width=412,height=915,inset=[0,0,0,0]}={}){
  const props={},listeners={},classes=new Set();
  const probe={style:{},setAttribute(){}};
  const window={innerWidth:width,innerHeight:height,
    addEventListener:(t,f)=>{(listeners[t]||=[]).push(f);},
    dispatchEvent:e=>{(listeners[e.type]||[]).forEach(f=>f(e));}};
  const context={window,innerWidth:width,innerHeight:height,Event:class{constructor(type){this.type=type;}},
    addEventListener:window.addEventListener,
    getComputedStyle:()=>({paddingTop:inset[0]+'px',paddingRight:inset[1]+'px',paddingBottom:inset[2]+'px',paddingLeft:inset[3]+'px'}),
    document:{documentElement:{classes,classList:{toggle:(c,on)=>{on?classes.add(c):classes.delete(c);}},style:{setProperty:(k,v)=>{props[k]=v;}}},createElement:()=>probe,body:{append(){}}}};
  vm.runInNewContext(source,context);
  return {stage:window.SlingStage,props,listeners,window,context,classes};
}

const VIEWPORTS=[[412,915],[360,800],[360,640],[390,844],[1920,969],[1366,657],[844,390],[768,1024]];

test('the stage keeps its design size and aspect on every viewport',()=>{
  for(const [w,h] of VIEWPORTS){
    const {stage,classes}=boot({width:w,height:h});
    assert.equal(stage.width,412);assert.equal(stage.height,915);
    const sw=412*stage.k,sh=915*stage.k;
    assert.ok(sw<=w+1e-6&&sh<=h+1e-6,`${w}x${h} fits`);
    // Centred: letterbox bars are balanced to within the rounding pixel.
    assert.ok(Math.abs(stage.x-(w-sw)/2)<=.5&&Math.abs(stage.y-(h-sh)/2)<=.5,`${w}x${h} centred`);
    assert.equal(classes.has('stage-framed'),stage.framed);
    if(stage.framed){
      // Framed stages leave room for the bezel on every side.
      assert.ok(Math.min(stage.x,stage.y,w-stage.x-sw,h-stage.y-sh)>=Math.min(14,Math.min(w,h)*.025)-.5,`${w}x${h} keeps a frame margin`);
    }else{
      assert.ok(Math.abs(sw-w)<1e-6||Math.abs(sh-h)<1e-6,`${w}x${h} full-bleed touches an edge`);
    }
  }
});

test('near-exact fits stay full-bleed; real letterboxes are framed',()=>{
  const framed=(w,h)=>boot({width:w,height:h}).stage.framed;
  assert.equal(framed(412,915),false);assert.equal(framed(360,800),false);assert.equal(framed(393,873),false);
  for(const [w,h] of [[1920,969],[1366,657],[844,390],[768,1024],[360,640]])assert.equal(framed(w,h),true,`${w}x${h}`);
});

test('common 9:20 Android viewports fill the screen with no bars',()=>{
  for(const [w,h] of [[412,915],[360,800]]){
    const {stage}=boot({width:w,height:h});
    assert.equal(stage.x,0);assert.equal(stage.y,0);
    assert.ok(Math.abs(stage.k-w/412)<1e-9);
  }
});

test('safe-area insets shrink the fit box and offset the stage',()=>{
  const {stage}=boot({width:390,height:844,inset:[47,0,34,0]});
  // 390×763 safe box leaves ~46px of slack, so the stage is framed; the margin
  // is capped at 2.5% of the short side (9.75px) on a phone this narrow.
  const m=390*.025;
  assert.equal(stage.framed,true);
  assert.ok(Math.abs(stage.k-Math.min((390-2*m)/412,(844-81-2*m)/915))<1e-9);
  assert.ok(stage.y>=47,'stays below the notch');
  assert.ok(stage.y+915*stage.k<=844-34+.5,'stays above the home indicator');
});

test('publishes CSS variables and converts client ↔ stage coordinates',()=>{
  const {stage,props}=boot({width:1920,height:969});
  assert.equal(Number(props['--stage-k']),stage.k);
  assert.equal(props['--stage-x'],stage.x+'px');
  const c=stage.toClient(100,200),back=stage.toStage(c.x,c.y);
  assert.ok(Math.abs(back.x-100)<1e-9&&Math.abs(back.y-200)<1e-9);
});

test('a resize refits the stage and announces stagechange',()=>{
  const {stage,listeners,window,context}=boot({width:412,height:915});
  let heard=0;window.addEventListener('stagechange',()=>heard++);
  listeners.resize.forEach(f=>f());
  assert.equal(heard,0,'an unchanged viewport does not refit');
  context.innerWidth=824;context.innerHeight=1830;
  listeners.resize.forEach(f=>f());
  assert.equal(heard,1);assert.equal(stage.k,2);
});
