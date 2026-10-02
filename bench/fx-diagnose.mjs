// Test-server-only lexical and module boundary timing hooks.
export function diagnoseSource(name,source){
  const methods={
    'game.js':['tick','clear','save','hit','shoot','addArrow','flushUi','flushVisuals'],
    'skills.js':['tick','clear','save','hit','shoot','activeSkills'],
    'achievements.js':['awardBrick','awardCore'],
    'skill-expansion.js':['tick','hit','projectileHit','onBrickDestroyed'],
    'skill-overdrive.js':['tick','hit','onBrickDestroyed'],
    'skill-effects.js':['hit','skillFX','drawSkillEffects'],
    'ui.js':['ui'], 'skills-ui.js':['ui','flushUi'],
    'achievements-ui.js':['updateAchievementUI','showAchievement'],
    'juice.js':['tick','clear','onBrickDestroyed'],
    'transitions.js':['tick','clear'], 'milestone.js':['tick','clear','save','ui']
  };
  const locals={
    'render.js':['render','drawParticles','drawRings','drawBolts','drawBoardCached'],
    'fx.js':['sprite','signature','radial'],
    'skill-signatures.js':['paint'],
    'skill-effects.js':['drawEffect','drawTrail','refresh'],
    'audio.js':['ensure'],
    'achievements-ui.js':['toClient','launchSpark','replay','animate'],
    'transitions.js':['stampClear','flyCoins'],
    'milestone.js':['syncHud']
  };
  const global=methods[name]||[],privateNames=locals[name]||[];
  if(!global.length&&!privateNames.length)return source;
  let code='\nif(window.__FXDiagnose){const D=window.__FXDiagnose;';
  for(const method of global)code+=`D.patch(window.Game,${JSON.stringify(method)},${JSON.stringify(name+'/'+method)});`;
  for(const local of privateNames){
    source=source.replace(new RegExp(`\\bconst ${local}\\s*=`),`let ${local}=`);
    code+=`${local}=D.wrap(${JSON.stringify(name+'/'+local)},${local});`;
  }
  code+='}\n';const at=source.lastIndexOf('})();');
  if(at<0)throw Error('Diagnosis hook has no closure: '+name);
  return source.slice(0,at)+code+source.slice(at);
}
