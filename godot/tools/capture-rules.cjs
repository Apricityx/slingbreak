#!/usr/bin/env node
/* Independent numerical oracle: execute the reference rule modules directly.
 * No Godot source, host bridge or frozen skill data is used to calculate values.
 */
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),Matter=require(path.join(root,'game/vendor/matter.min.js'));
const files=['src/core/game.js','src/skills/skills.js','src/core/achievements.js','src/skills/skill-expansion.js','src/skills/skill-overdrive.js'];
const up={power:7,arrow:9,brick:6,draw:4,comboCap:3,slots:3,rerollCap:2};
function boot(ids=[]){
  const state={level:200,coins:1e12,total:0,best:0,comboRulesVersion:2,up:{...up},skills:Object.fromEntries(ids.map(id=>[id,1])),skillScopeVersion:3,skillGateVersion:1,skillChosenLevel:200,skillRuntime:{level:200,shots:7},sound:false,volume:0};
  let stored=JSON.stringify(state),seed=9128;
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const scope=vm.createContext({Matter,Math:math,console,window:{},URLSearchParams,location:{search:''},matchMedia:()=>({matches:true}),localStorage:{getItem:()=>stored,setItem:(k,v)=>stored=v},document:{getElementById:()=>({})}});
  for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,'game',file),'utf8'),scope);
  return scope.window.Game;
}
const baseline=boot(),cases=[[],...baseline.skillCatalog.map(s=>[s.id]),['titan','heavy','railgun','growing'],['mint','alchemist','bounty','specialist'],['bargain','treasury','resonance','rapid']];
const metrics=[];
for(const ids of cases){
  const G=boot(ids);
  const reward={};
  if(!ids.includes('jackpot'))for(const type of ['normal','gold','bomb'])for(const kills of [1,4,12])reward[type+':'+kills]=G.reward(type,kills);
  const costs=Object.fromEntries(['power','arrow','brick','draw','comboCap','slots','rerollCap'].map(k=>[k,G.cost(k)]));
  metrics.push({ids,damage:G.damage(),speed:G.speed(),penetration:G.penetration(),bonus:G.bonus(),hp:G.baseHp(),draw:G.drawInterval(),thresholdRatio:.6-.15*G.skillRank('resonance'),costs,reward});
}
const free=[];
const tick=1000/60;
const flights=[
  {name:'normal',gravityX:0,steps:Array(120).fill(tick)},
  {name:'timeslip',gravityX:0,steps:Array(120).fill(tick*.2)},
  {name:'timeslip-release',gravityX:0,steps:Array.from({length:120},(_,i)=>i<30||i>=90?tick:tick*.2)},
  {name:'forge-wind',gravityX:.22,steps:Array(120).fill(tick)},
  {name:'variable-step',gravityX:-.22,steps:Array.from({length:120},(_,i)=>tick*[1,.2,.5,1][i%4])},
];
for(const velocity of [[0,-24],[11,-29],[-8,-16]]){
 for(const flight of flights){
  const engine=Matter.Engine.create({gravity:{x:flight.gravityX,y:.48}});
  const body=Matter.Bodies.circle(390,970,3,{frictionAir:.0005,isSensor:true,collisionFilter:{mask:0},label:'arrow'});
  Matter.Body.setVelocity(body,{x:velocity[0],y:velocity[1]});Matter.Composite.add(engine.world,body);
  const points=[];
  for(let i=0;i<120;i++){
    Matter.Engine.update(engine,flight.steps[i]);points.push([body.position.x,body.position.y,body.velocity.x,body.velocity.y]);
  }
  free.push({name:flight.name,velocity,gravityX:flight.gravityX,steps:flight.steps,points});
 }
}
const output=path.join(root,'agent-tmp/godot/reference-rules.json');fs.mkdirSync(path.dirname(output),{recursive:true});
fs.writeFileSync(output,JSON.stringify({up,level:200,shots:7,metrics,free},null,2)+'\n');
console.log('Independent reference rules: '+metrics.length+' builds and '+free.reduce((sum,flight)=>sum+flight.points.length,0)+' Matter integration samples');
