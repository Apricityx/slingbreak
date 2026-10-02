#!/usr/bin/env node
// Sampled CPU attribution, deliberately separate from unprofiled performance timings.
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
export function summarize(profile){
  const nodes=new Map(profile.nodes.map(n=>[n.id,n])),parents=new Map();
  for(const n of profile.nodes)for(const child of n.children||[])parents.set(child,n.id);
  const totals=new Map(),burst=new Map();let sampledUs=0,burstUs=0,burstSamples=0;
  const label=n=>`${n.callFrame.functionName||'(anonymous)'} ${n.callFrame.url.split('/').pop()||'(eval/native)'}:${n.callFrame.lineNumber+1}`;
  for(let i=0;i<(profile.samples||[]).length;i++){
    const id=profile.samples[i],node=nodes.get(id),us=profile.timeDeltas[i];if(!node||!Number.isFinite(us)||us<0)continue;
    sampledUs+=us;const key=label(node);totals.set(key,(totals.get(key)||0)+us);
    let ancestor=id,isBurst=false;
    while(ancestor!=null){const n=nodes.get(ancestor);if(!n)break;
      if(n.callFrame.functionName==='strike'&&!n.callFrame.url){isBurst=true;break;}ancestor=parents.get(ancestor);
    }
    if(isBurst){burstUs+=us;burstSamples++;burst.set(key,(burst.get(key)||0)+us);}
  }
  const sorted=map=>[...map].sort((a,b)=>b[1]-a[1]).map(([location,us])=>({location,selfMs:us/1000}));
  return {sampledMs:sampledUs/1000,burstMs:burstUs/1000,burstSamples,burst:sorted(burst),overall:sorted(totals)};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  if(!process.argv[2])throw Error('Usage: node bench/fx-profile.mjs file.cpuprofile');
  console.log(JSON.stringify(summarize(JSON.parse(fs.readFileSync(process.argv[2],'utf8'))),null,2));
}
