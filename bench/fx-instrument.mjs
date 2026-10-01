// Test-server-only hooks. Shipping files on disk are never rewritten.
export function instrument(name, source) {
  const append = code => {
    const at = source.lastIndexOf('})();');
    if (at < 0) throw new Error(`Missing closure in ${name}`);
    return source.slice(0, at) + code + '\n' + source.slice(at);
  };
  if (name === 'render.js') return append('Game.__audit.render = render;');
  if (name === 'skill-effects.js') return append('G.__audit.skills = {profiles,effects,cooldowns,drawEffect,drawTrail};');
  if (name === 'juice.js') return append('G.__audit.juice = {drawOverdrive,drawTallies,tallies};');
  if (name === 'skill-expansion.js') return append('G.__audit.expansion = {get signals(){return signals;},get saws(){return saws;},reset:resetTransient};');
  if (name === 'skill-overdrive.js') return append('G.__audit.overdrive = {get signals(){return signals;},get fields(){return fields;},reset};');
  if (name === 'intro.js') return append('Game.__audit.intro = {finish,paint:()=>{finished=false;draw(start+1400);finished=true;}};');
  if (name === 'transitions.js') return append('G.__audit.transitions={flyCoins};');
  if (name === 'achievements-ui.js') return append('G.__audit.achievement={launchSpark,flyPayout};');
  const bossHooks = {
    'boss-eye.js': `G.__audit.bosses.eye={
      reset:()=>{wells=[];beams=[];snaps=[];shards=[];move=null;},
      get wells(){return wells;},get beams(){return beams;},get fragments(){return shards;},get snaps(){return snaps;},
      well:(ctx,w)=>drawWell(ctx,R(),w),beam:(ctx,b)=>drawBeam(ctx,R(),b),
      shards:ctx=>drawShards(ctx,R()),chains:ctx=>drawChains(ctx,R()),back:drawBack,field:drawField,front:drawFront};`,
    'boss-forge.js': `G.__audit.bosses.forge={reset:clearFx,
      get meteors(){return meteors;},get embers(){return embers;},
      back:drawBack,field:drawField,front:drawFront};`,
    'boss-clock.js': `G.__audit.bosses.clock={reset:()=>{shards=[];},get fragments(){return shards;},
      shards:ctx=>drawShards(ctx,R()),back:drawBack,field:drawField,front:drawFront};`,
    'boss-serpent.js': `G.__audit.bosses.serpent={
      reset:()=>{fx=[];sparks=[];portals=[];ghosts=[];dust=[];debris=[];snakes=[];eclipse=null;},
      get fx(){return fx;},get sparks(){return sparks;},get dust(){return dust;},
      get ghosts(){return ghosts;},get portals(){return portals;},get snakes(){return snakes;},get debris(){return debris;},
      eclipse:()=>{eclipse={start:G.time-1,end:G.time+6,hits:0};},
      drawFx,drawEclipse:ctx=>drawEclipse(ctx,R()),eyeTrails:ctx=>drawEyeTrails(ctx,R()),back:drawBack,field:drawField,front:drawFront};`
  };
  if (bossHooks[name]) {
    const marker = name === 'boss-serpent.js' || name === 'boss-clock.js' ? '    const def={' : '    return {\n      id:';
    if (!source.includes(marker)) throw new Error(`Boss hook anchor changed: ${name}`);
    return source.replace(marker, bossHooks[name] + '\n' + marker);
  }
  return source;
}

export const bootstrap = `(() => {
  window.__nativeRAF = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = () => 0;
  // Game creates its object after this bootstrap: attach hooks without changing it.
  let game;
  Object.defineProperty(window,'Game',{configurable:true,get:()=>game,set:value=>{
    game=value; game.__audit={bosses:{}};
  }});
  let seed=12345;
  Math.random=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
})();`;
