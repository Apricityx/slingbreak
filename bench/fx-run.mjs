#!/usr/bin/env node
import {spawn,execFileSync} from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {instrument,bootstrap} from './fx-instrument.mjs';
import {diagnoseSource} from './fx-diagnose.mjs';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const args=Object.fromEntries(process.argv.slice(2).map(a=>a.replace(/^--/,'').split('=')));
const SOURCE_ROOT=path.resolve(args['source-root']||ROOT);
const options={dpr:Number(args.dpr||2),reduced:args.reduced==='1',sample:Number(args.sample||100),filter:args.filter||'',raf:args.raf==='1',dom:args.dom==='1',animated:args.animated==='1',capture:args.capture==='1',
   boardSeconds:Number(args['board-seconds']||6),boardRepeats:Number(args['board-repeats']||1),
   diagnose:args.diagnose==='1',boardCount:args['board-count']?Number(args['board-count']):null};
if(options.boardCount!==null&&![77,240].includes(options.boardCount))throw Error('board-count must be 77 or 240');
if(!Number.isFinite(options.boardSeconds)||options.boardSeconds<6||!Number.isInteger(options.boardRepeats)||options.boardRepeats<1)throw Error('board-seconds must be >= 6; board-repeats must be a positive integer');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
class CDP{
  constructor(url){this.ws=new WebSocket(url);this.n=0;this.pending=new Map();this.listeners=[];
    this.ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=this.pending.get(m.id);this.pending.delete(m.id);m.error?p.reject(Error(m.error.message)):p.resolve(m.result);}else this.listeners.forEach(f=>f(m));};}
  ready(){return new Promise((r,j)=>{this.ws.onopen=r;this.ws.onerror=j;});}
  send(method,params={},sessionId){return new Promise((resolve,reject)=>{const id=++this.n;this.pending.set(id,{resolve,reject});this.ws.send(JSON.stringify({id,method,params,sessionId}));});}
}
function chromePath(){
  if(args.chrome||process.env.CHROME_PATH)return args.chrome||process.env.CHROME_PATH;
  for(const p of ['/usr/bin/chromium','/usr/bin/google-chrome'])if(fs.existsSync(p))return p;
  const cache=path.join(os.homedir(),'.cache/ms-playwright');
  for(const dir of fs.readdirSync(cache))for(const sub of ['chrome-linux64/chrome','chrome-linux/chrome']){const p=path.join(cache,dir,sub);if(fs.existsSync(p))return p;}
  throw Error('Chrome not found');
}
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml','.json':'application/json'};
const server=http.createServer((req,res)=>{
  const pathname=new URL(req.url,'http://localhost').pathname,file=path.resolve(SOURCE_ROOT,'.'+decodeURIComponent(pathname));
  if(!file.startsWith(SOURCE_ROOT+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(err,data)=>{if(err){res.writeHead(404).end();return;}
     try{if(path.extname(file)==='.js'){let text=data.toString();if(options.diagnose)text=diagnoseSource(path.basename(file),text);data=instrument(path.basename(file),text);}}
    catch(e){res.writeHead(500).end(String(e));return;}
    res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store'}).end(data);
  });
});
let child,cdp,profile;
const traceEvents=[];let finishTrace;
const traceComplete=new Promise(resolve=>{finishTrace=resolve;});
const hostBefore={load:os.loadavg(),cpuStat:fs.existsSync('/sys/fs/cgroup/cpu.stat')?fs.readFileSync('/sys/fs/cgroup/cpu.stat','utf8'):null};
try{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
   const temp=path.join(ROOT,'agent-tmp');fs.mkdirSync(temp,{recursive:true});
  profile=fs.mkdtempSync(path.join(temp,'sling-fx-'));
  const binary=chromePath();
   child=spawn(binary,['--headless','--no-sandbox','--disable-dev-shm-usage','--disable-frame-rate-limit','--disable-gpu-vsync',
    '--disable-background-timer-throttling','--disable-renderer-backgrounding','--mute-audio','--no-first-run',
    '--disable-gpu',`--user-data-dir=${profile}`,'--remote-debugging-port=0','about:blank'],{stdio:['ignore','ignore','pipe']});
  const url=await new Promise((resolve,reject)=>{let s='';const t=setTimeout(()=>reject(Error('Chrome startup timeout')),20000);
    child.stderr.on('data',d=>{s+=d;const m=s.match(/DevTools listening on (ws:\/\/\S+)/);if(m){clearTimeout(t);resolve(m[1]);}});
    child.on('exit',c=>{clearTimeout(t);reject(Error('Chrome exit '+c));});});
  cdp=new CDP(url);await cdp.ready();
  const {targetId}=await cdp.send('Target.createTarget',{url:'about:blank'});
  const {sessionId}=await cdp.send('Target.attachToTarget',{targetId,flatten:true});
  const errors=[];
  cdp.listeners.push(m=>{if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);
    if(m.method==='Tracing.dataCollected')for(const event of m.params.value)traceEvents.push(event);
    if(m.method==='Tracing.tracingComplete')finishTrace();
    if(m.method==='Runtime.consoleAPICalled'){const text=m.params.args.map(a=>a.value||a.description||'').join(' ');if(text.startsWith('[fx]'))console.log(text);}});
  await cdp.send('Runtime.enable',{},sessionId);await cdp.send('Page.enable',{},sessionId);
  await cdp.send('Emulation.setDeviceMetricsOverride',{width:412,height:915,deviceScaleFactor:options.dpr,mobile:false},sessionId);
   await cdp.send('Page.addScriptToEvaluateOnNewDocument',{source:bootstrap+(options.diagnose?'\n'+fs.readFileSync(path.join(ROOT,'bench/fx-diagnose.js'),'utf8'):'')},sessionId);
  await cdp.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/index.html`},sessionId);
  const evalJS=async expression=>{const r=await cdp.send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true},sessionId);
    if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description||r.exceptionDetails.text);return r.result.value;};
  for(let i=0;i<100;i++){if(await evalJS('!!window.Game?.__audit?.bosses?.serpent'))break;await sleep(100);}
  if(args['cpu-profile']==='1'){await cdp.send('Profiler.enable',{},sessionId);await cdp.send('Profiler.start',{},sessionId);}
  if(args.trace==='1')await cdp.send('Tracing.start',{categories:'devtools.timeline,v8,blink.user_timing,disabled-by-default-devtools.timeline',options:'record-as-much-as-possible',transferMode:'ReportEvents'});
  await evalJS(`window.__FX_OPTIONS__=${JSON.stringify(options)}; ${fs.readFileSync(path.join(ROOT,'bench/fx-board.js'),'utf8')}\nvoid ${fs.readFileSync(path.join(ROOT,'bench/fx-page.js'),'utf8')}`);
  let result;const deadline=Date.now()+Number(args.timeout||900)*1000;
  while(Date.now()<deadline){result=await evalJS('window.__FX_BENCH__?.done ? window.__FX_BENCH__ : null');if(result)break;await sleep(1000);}
  if(!result)throw Error('Benchmark timeout');
  result.pageErrors=errors;
  result.environment={date:new Date().toISOString(),platform:process.platform,cpu:os.cpus()[0].model,
    cpuCount:os.cpus().length,chrome:binary,gpu:'disabled (software raster)',gitHead:execFileSync('git',['rev-parse','HEAD'],{cwd:ROOT,encoding:'utf8'}).trim(),
     note:SOURCE_ROOT===ROOT?'Current working tree, including uncommitted changes; isolated temporary Chrome profile.':'Saved source snapshot; current benchmark hooks/driver; isolated temporary Chrome profile.'};
  const dir=path.resolve(ROOT,args.out||'bench/results/fx-audit');fs.mkdirSync(dir,{recursive:true});
  if(args['cpu-profile']==='1'){const {profile:cpu}=await cdp.send('Profiler.stop',{},sessionId);fs.writeFileSync(path.join(dir,'cpu-profile.cpuprofile'),JSON.stringify(cpu));}
  if(args.trace==='1'){await cdp.send('Tracing.end');await traceComplete;fs.writeFileSync(path.join(dir,'trace.json'),JSON.stringify({traceEvents}));}
  result.environment.host={before:hostBefore,after:{load:os.loadavg(),cpuStat:fs.existsSync('/sys/fs/cgroup/cpu.stat')?fs.readFileSync('/sys/fs/cgroup/cpu.stat','utf8'):null}};
  result.environment.sourceRoot=SOURCE_ROOT;
  for(const image of result.captures||[]){
    const dest=path.join(dir,image.name+'.png');fs.writeFileSync(dest,Buffer.from(image.data.split(',')[1],'base64'));delete image.data;
  }
  const dest=path.join(dir,`fx-dpr${options.dpr}-${options.reduced?'reduced':'normal'}${options.raf?'-raf':''}${options.dom?'-dom':''}${options.animated?'-animated':''}${options.filter?'-filtered':''}.json`);
  fs.writeFileSync(dest,JSON.stringify(result,null,2)+'\n');
  console.log('[fx] saved',path.relative(ROOT,dest),JSON.stringify(result.coverage));
  if(result.errors.length||errors.length){console.error(JSON.stringify({errors:result.errors,pageErrors:errors},null,2));process.exitCode=1;}
}catch(e){console.error(e.stack);process.exitCode=1;}
finally{cdp?.ws.close();child?.kill('SIGKILL');server.close();if(profile)fs.rmSync(profile,{recursive:true,force:true});}
