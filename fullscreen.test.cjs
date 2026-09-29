const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const source=fs.readFileSync(__dirname+'/fullscreen.js','utf8');

// A minimal header: one toggle button wrapping one [data-lucide] node, plus the
// fullscreen document API the module touches.
function boot({withButton=true}={}){
  const calls=[],listeners={},buttonAttrs=new Map();
  let iconName='maximize';
  const icon={getAttribute:key=>key==='data-lucide'?iconName:null,
    setAttribute:(key,value)=>{if(key==='data-lucide')iconName=value;}};
  const button={title:'',
    getAttribute:key=>buttonAttrs.has(key)?buttonAttrs.get(key):null,
    setAttribute:(key,value)=>buttonAttrs.set(key,String(value)),
    querySelector:selector=>selector==='[data-lucide]'?icon:null,
    addEventListener:(name,callback)=>{listeners['button:'+name]=callback;}};
  const document={documentElement:{requestFullscreen(){calls.push('request');return Promise.resolve();}},
    fullscreenElement:null,
    exitFullscreen(){calls.push('exit');return Promise.resolve();},
    getElementById:id=>withButton&&id==='fullscreen-toggle'?button:null,
    addEventListener:(name,callback)=>{listeners[name]=callback;}};
  const window={lucide:{createIcons:()=>calls.push('icons')}};
  vm.runInNewContext(source,{document,window,Promise});
  return {button,buttonAttrs,calls,listeners,document,iconName:()=>iconName};
}

test('the header button starts in the enter-fullscreen state',()=>{
  const {button,buttonAttrs,calls,iconName}=boot();
  assert.equal(buttonAttrs.get('aria-label'),'进入全屏');
  assert.equal(buttonAttrs.get('aria-pressed'),'false');
  assert.equal(button.title,'进入全屏');
  assert.equal(iconName(),'maximize');
  assert.deepEqual(calls,[],'no fullscreen request or icon rebuild on load');
});

test('clicking requests fullscreen and the icon follows the state change',()=>{
  const {buttonAttrs,calls,listeners,document,iconName}=boot();
  listeners['button:click']();
  assert.deepEqual(calls,['request'],'click builds no icons until the mode actually changes');
  document.fullscreenElement={};
  listeners.fullscreenchange();
  assert.equal(iconName(),'minimize');
  assert.equal(buttonAttrs.get('aria-label'),'退出全屏');
  assert.equal(buttonAttrs.get('aria-pressed'),'true');
  assert.ok(calls.includes('icons'),'the swapped lucide icon is re-rendered');
});

test('clicking again exits fullscreen',()=>{
  const {buttonAttrs,calls,listeners,document,iconName}=boot();
  document.fullscreenElement={};
  listeners.fullscreenchange();
  listeners['button:click']();
  assert.ok(calls.includes('exit')&&!calls.includes('request'),'an active session exits');
  document.fullscreenElement=null;
  listeners.fullscreenchange();
  assert.equal(iconName(),'maximize');
  assert.equal(buttonAttrs.get('aria-pressed'),'false');
});

test('the module is inert when the header button is absent',()=>{
  assert.doesNotThrow(()=>boot({withButton:false}));
});
