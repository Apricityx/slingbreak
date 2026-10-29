// Pure aggregation for the per-skill whole-board burst benchmark. Kept apart
// from the CLI report so the ranking and validation rules can be unit-tested
// without launching Chrome.
export const SKILL_BURST_GROUP='skill-burst';
export const DEFAULT_BASELINE='none';

export function hotDrawMs(row){
  const values=(row.phases||[]).slice(0,2).map(phase=>phase?.costMs?.p95).filter(Number.isFinite);
  return values.length?Math.max(...values):0;
}

export function validateSkillBurstResult(data){
  if(!data||!Array.isArray(data.results))throw Error('Missing benchmark results');
  if((data.errors||[]).length||(data.pageErrors||[]).length)throw Error('Benchmark recorded page or harness errors');
  const rows=data.results.filter(row=>row.group===SKILL_BURST_GROUP);
  if(!rows.length)throw Error('No skill-burst cases in benchmark result');
  const ids=new Set();
  for(const row of rows){
    if(ids.has(row.id))throw Error('Duplicate skill-burst case: '+row.id);
    ids.add(row.id);
    if(!row.runs?.length)throw Error('Skill-burst case has no runs: '+row.id);
    for(const run of row.runs){
      const o=run.outcome||{};
      if(o.destroyed!==row.n||o.totalDelta!==row.n||o.remaining!==0||o.simulationAdvanced!==0)
        throw Error(`Skill-burst did not destroy the whole board in one instant: ${row.id}`);
      if(o.coinDelta!==o.shotMoney||o.coinDelta!==o.levelMoney||o.coinDelta<=0)
        throw Error(`Skill-burst rewards were lost or counted twice: ${row.id}`);
      if(Object.values(run.tail||{}).some(n=>n!==0))
        throw Error(`Skill-burst left transient objects alive: ${row.id}`);
    }
  }
  return rows;
}

export function summarizeSkillBurst(data,{baselineId=DEFAULT_BASELINE}={}){
  const rows=validateSkillBurstResult(data).filter(row=>!row.warmup);
  const baselineRow=rows.find(row=>row.id===baselineId);
  if(!baselineRow)throw Error(`Missing ${baselineId} baseline skill-burst case`);
  const baseline={
    id:baselineRow.id,burst:baselineRow.burstMs.median,first:baselineRow.firstDrawMs.median,
    event:baselineRow.eventMs.median,earlyP95:hotDrawMs(baselineRow)
  };
  const summaries=rows.map(row=>{
    const burst=row.burstMs.median,first=row.firstDrawMs.median,event=row.eventMs.median,earlyP95=hotDrawMs(row);
    return {
      id:row.id,name:row.name||row.id,tier:row.tier||'?',n:row.n,rate:row.rate,
      burst,first,event,eventMax:row.eventMs.max,earlyP95,
      updateMax:row.updateMs?.max??0,
      burstDelta:burst-baseline.burst,firstDelta:first-baseline.first,
      eventDelta:event-baseline.event,earlyDelta:earlyP95-baseline.earlyP95,
      eventPerBrick:event/row.n,
      peaks:row.peaks||{},costMedian:row.costMs?.median??0,
      repeats:row.runs.length,row
    };
  });
  return {baseline,rows:summaries};
}

// Rank helpers are shared by the report and its tests. A descending sort keeps
// the slowest skill first; ties fall back to the stable catalog order.
export function rankBy(rows,key){
  return rows.map((row,index)=>({row,index})).sort((a,b)=>b.row[key]-a.row[key]||a.index-b.index).map(entry=>entry.row);
}

export function problemSkills(rows,{baselineEvent,minEventDeltaMs=4,minDrawDeltaMs=6,minEarlyDeltaMs=8}={}){
  return rows.filter(row=>row.id!==DEFAULT_BASELINE&&(
    row.eventDelta>=minEventDeltaMs||row.firstDelta>=minDrawDeltaMs||row.earlyDelta>=minEarlyDeltaMs||
    (baselineEvent>0&&row.event>=baselineEvent*1.5)
  ));
}
