const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
async function boot(file){
  const {instrument}=await import('./bench/fx-instrument.mjs');
  const animations=[],elements=new Map(),noop=()=>{};
  function el(){
    const node={children:[],isConnected:true,textContent:'',dataset:{},style:{setProperty:noop},classList:{add:noop,remove:noop,toggle:noop},setAttribute:noop,addEventListener:noop,after:noop,
      getBoundingClientRect:()=>({left:100,top:100,right:300,bottom:140,width:200,height:40}),
      querySelector:()=>el(),querySelectorAll:()=>[],append(child){this.children.push(child);child.parent=this;},
      remove(){this.isConnected=false;if(this.parent)this.parent.children.splice(this.parent.children.indexOf(this),1);},
      animate(){let resolve,reject;const finished=new Promise((a,b)=>{resolve=a;reject=b;});const animation={finished,cancel:()=>reject(Error('cancelled')),finish:resolve};animations.push(animation);return animation;}
    };return node;
  }
  const body=el(),G={__audit:{},state:{coins:123},reduced:false,ui:noop,reset:noop,shoot:noop,tick:noop,clear:noop,generate:noop,toast:noop,fmt:String,view:{scale:1}};
  const context={Game:G,window:{Game:G},document:{body,hidden:false,createElement:el,getElementById:id=>{if(!elements.has(id))elements.set(id,el());return elements.get(id);},querySelector:()=>el(),querySelectorAll:()=>[],addEventListener:noop},
    matchMedia:()=>({matches:false}),performance:{now:()=>0},innerHeight:1000,innerWidth:500,requestAnimationFrame:noop,cancelAnimationFrame:noop,
    MutationObserver:class{observe(){}},HTMLDialogElement:class{close(){}},setTimeout:noop,lucide:{createIcons:noop}};
  vm.createContext(context);vm.runInContext(instrument(file,fs.readFileSync(__dirname+'/'+file,'utf8')),context);
  const flush=async()=>{await Promise.resolve();await Promise.resolve();};
  return {G,body,animations,flush,document:context.document};
}
test('coin flights cap live nodes, clean up cancellation and never touch the wallet',async()=>{
  const {G,body,animations,flush}=await boot('transitions.js');
  for(let i=0;i<16;i++)G.__audit.transitions.flyCoins(100000);
  assert.equal(body.children.length,24);assert.equal(G.state.coins,123);
  for(const a of animations)a.cancel();await flush();assert.equal(body.children.length,0);
  G.__audit.transitions.flyCoins(100000);assert.equal(body.children.length,14);
  G.reduced=true;G.__audit.transitions.flyCoins(100000);assert.equal(body.children.length,14);
});
test('achievement sparks and payout chips share bounded budgets that recover after cancellation',async()=>{
  const {G,body,animations,flush,document}=await boot('achievements-ui.js');
  for(let i=0;i<100;i++){G.__audit.achievement.launchSpark({x:200,y:600},'#ffaa33',{});G.__audit.achievement.flyPayout(1000);}
  assert.equal(body.children.filter(n=>n.className==='achievement-spark').length,6);
  assert.equal(body.children.filter(n=>n.className==='achievement-payout-chip').length,3);
  for(const a of animations)a.cancel();await flush();assert.equal(body.children.length,0);
  G.__audit.achievement.launchSpark({x:200,y:600},'#ffaa33',{});G.__audit.achievement.flyPayout(1000);assert.equal(body.children.length,2);
  document.hidden=true;G.__audit.achievement.flyPayout(1000);assert.equal(body.children.length,2);assert.equal(G.state.coins,123);
});
test('achievement replay is coalesced per element and class when the game has a frame visual queue',async()=>{
  const {G,body}=await boot('achievements-ui.js');const queued=[];G.deferVisual=(key,paint)=>queued.push({key,paint});
  const node=body,replay=G.__audit.achievement.replay;
  replay(node,'is-hit');replay(node,'is-hit');replay(node,'is-other');
  assert.equal(queued.length,1);queued.forEach(item=>item.paint());assert.ok(queued.every(item=>item.key.indexOf('achievement-replay:')===0));
});
