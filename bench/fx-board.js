/* Test-only whole-board bursts; loaded by fx-run.mjs, never by index.html. */
(() => {
  'use strict';
  const types=['bomb','lightning','frost','prism','gold'];
  function random(seed){let s=seed>>>0;return()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296;};}
  function fixture(n,rate,seed=843427,hp=1){
    if(![77,240].includes(n)||![0,.22,.5].includes(rate))throw Error('Unsupported board fixture');
    const cols=n===77?7:12,rows=n/cols,dx=n===77?96:60,dy=n===77?60:34;
    const bricks=Array.from({length:n},(_,i)=>({x:n===77?102+i%cols*dx:60+i%cols*dx,
      y:170+Math.floor(i/cols)*dy,w:n===77?84:54,h:n===77?44:28,hp,max:hp,type:'normal',frozen:false}));
    const rng=random(seed),order=Array.from({length:n},(_,i)=>i);
    for(let i=n-1;i>0;i--){const j=Math.floor(rng()*(i+1));[order[i],order[j]]=[order[j],order[i]];}
    const quota=Math.floor(n*rate),counts={normal:n-quota,bomb:0,lightning:0,frost:0,prism:0,gold:0};
    for(let i=0;i<quota;i++){const type=types[i%types.length];bricks[order[i]].type=type;counts[type]++;}
    return {bricks,counts,quota,actualRate:quota/n,cols,rows,seed};
  }
  function cases(){const list=[];
    for(const n of [77,240])for(const rate of [0,.22,.5])for(const loadout of ['plain','chain'])list.push({
      group:'board-burst',id:`${loadout}:special-${Math.round(rate*100)}`,n,rate,loadout,seed:843427,
      skills:loadout==='chain'?['cascade','storm','blizzard','prism']:[],synthetic:true,
      scope:n===77?'Full 7 × 11 grid without normal gaps/barriers':'240-brick restore ceiling, dense 12 × 20 grid'
    });return list;
  }
  // One isolated skill per case so a slow result can be attributed to a single
  // skill instead of a four-slot mix. Every case uses the same fixed dense board
  // and special-brick quota; the no-skill case is the comparison baseline.
  function skillCases(){
    const catalog=window.Game?.skillCatalog||[];
    const n=window.__FX_OPTIONS__?.boardCount||240;
    const rate=window.__FX_OPTIONS__?.skillRate??.22;
    const list=[{id:'warmup',name:'预热',tier:'none',family:'none',warmup:true,skills:[]},
      {id:'none',name:'无技能',tier:'none',family:'none',skills:[]}];
    for(const skill of catalog)list.push({id:skill.id,name:skill.name,tier:skill.tier,
      family:skill.family,skills:[skill.id]});
    return list.map(c=>({group:'skill-burst',id:c.id,name:c.name,tier:c.tier,family:c.family,
      n,rate,loadout:'single',seed:843427,level:50,shotPhase:11,warmup:!!c.warmup,skills:c.skills,synthetic:true,
      scope:n===77?'77-brick full grid; one isolated skill':'240-brick restore ceiling, dense 12 × 20 grid; one isolated skill'}));
  }
  function install(G,c,reduced){
    // Reset through production wrappers, including skill jobs and achievement UI.
    const level=c.level||9;
    G.reset();G.time=100;G.state.level=level;G.state.bossOverride=null;G.state.milestone=null;
    G.state.up.slots=3;G.state.skills=Object.fromEntries(c.skills.map(id=>[id,1]));
    G.state.skillScopeVersion=3;G.state.skillGateVersion=G.skillGateVersion;G.state.skillChosenLevel=level;
    G.state.skillRuntime=null;G.state.draft=null;G.state.performanceMode=reduced;G.reduced=reduced;
    const f=fixture(c.n,c.rate,c.seed,G.baseHp());
    G.state.board={layoutVersion:G.layoutVersion,balanceVersion:G.balanceVersion,level,initial:c.n,
      killed:0,levelMoney:0,bricks:f.bricks,obstacles:[],core:false};
    G.generate(true);G.phase='ready';G.paused=false;G.boardEntrance=null;G.holdDraft=false;
    // Make every-third/every-fourth-shot effects reachable with the single shot
    // this fixture fires. The 12th shot satisfies all current periodic skills.
    if(c.shotPhase&&G.state.skillRuntime)G.state.skillRuntime.shots=c.shotPhase;
    if(G.bricks.length!==c.n)throw Error('Production board restore rejected fixture');
    return f;
  }
  function strike(G,source){
    const board=[...G.bricks],coins=G.state.coins,total=G.state.total,killed=G.killed,time=G.time;
    const originalDamage=source.damage;let directCalls=0;
    // Artificial simultaneous lethal sweep; normal recursive hit/projectile hooks
    // still decide every special, reward, achievement, delayed job and shard.
    source.damage=1e9;
    try{G.withArrow(source,()=>{for(const b of board)if(G.bricks.includes(b)){
      directCalls++;if(G.projectileHit)G.projectileHit(b,source);else G.hit(b,source.damage);
    }});}finally{source.damage=originalDamage;}
    const outcome={destroyed:G.killed-killed,remaining:G.bricks.length,totalDelta:G.state.total-total,
      coinDelta:G.state.coins-coins,shotMoney:G.shotMoney,levelMoney:G.levelMoney,directCalls,
      recursiveKills:board.length-directCalls,simulationAdvanced:G.time-time,coreSpawned:!!G.core};
    if(outcome.remaining||outcome.destroyed!==board.length||outcome.totalDelta!==board.length||outcome.simulationAdvanced!==0)
      throw Error('Whole-board burst did not destroy every brick exactly once in one simulation instant');
    if(outcome.coinDelta!==outcome.shotMoney||outcome.coinDelta!==outcome.levelMoney||outcome.coinDelta<=0)
      throw Error('Whole-board rewards were lost or counted twice');
    return outcome;
  }
  window.__FXBoard={fixture,cases,skillCases,install,strike,random};
})();
