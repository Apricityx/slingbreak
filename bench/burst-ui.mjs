#!/usr/bin/env node
// Browser integration regression: full shipping wrappers, manually controlled frames.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import {fileURLToPath} from 'node:url';
import {instrument,bootstrap} from './fx-instrument.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(import.meta.url),puppeteer=require(process.env.CHROME89_PUPPETEER||'puppeteer');
const out=path.join(root,'agent-tmp',process.env.CHROME_BIN?'burst-ui-modern':'burst-ui-chrome89');
fs.mkdirSync(out,{recursive:true});
const server=http.createServer((req,res)=>{
  const file=path.resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
  if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  try{let data=fs.readFileSync(file);if(file.endsWith('.js'))data=instrument(path.basename(file),data.toString());
    res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml','.json':'application/json'})[path.extname(file)]||'application/octet-stream');res.end(data);
  }catch{res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const profile=fs.mkdtempSync(path.join(out,'profile-'));let browser;
const report={checks:[],errors:[]};
try{
  browser=await puppeteer.launch({headless:true,executablePath:process.env.CHROME_BIN||undefined,userDataDir:profile,
    args:['--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--mute-audio']});
  report.version=await browser.version();if(!process.env.CHROME_BIN)assert.match(report.version,/Chrome\/89\./);
  const page=await browser.newPage();await page.setViewport({width:412,height:915,deviceScaleFactor:2});
  page.on('pageerror',e=>report.errors.push(String(e)));
  await page.evaluateOnNewDocument(bootstrap);
  await page.goto(`http://127.0.0.1:${server.address().port}/index.html`,{waitUntil:'load'});
  await page.addScriptTag({content:fs.readFileSync(path.join(root,'bench/fx-board.js'),'utf8')});
  const burst=await page.evaluate(()=>{
    const G=Game,B=window.__FXBoard;G.__audit.intro.finish();window.SlingBreakIntro.active=false;
    for(const d of document.querySelectorAll('dialog[open]'))d.close();
    const c=B.cases().find(c=>c.n===77&&c.rate===.22&&c.loadout==='chain');B.install(G,c,false);
    G.state.volume=0;G.ui();G.__audit.render();G.flushVisuals();
    const count={ui:0,achievement:0,combo:0},ui=G.ui,achievement=G.updateAchievementUI,animate=Element.prototype.animate;
    G.ui=(...args)=>{count.ui++;return ui(...args);};
    G.updateAchievementUI=(...args)=>{count.achievement++;return achievement(...args);};
    Element.prototype.animate=function(...args){if(this.id==='combo')count.combo++;return animate.apply(this,args);};
    G.shoot(0,100);G.__audit.render();count.ui=count.achievement=count.combo=0;
    const outcome=B.strike(G,G.arrows[0]),before={...count};G.__audit.render();const after={...count};
    const visible={kills:document.getElementById('combo-count').textContent,heat:document.getElementById('combo').dataset.heat,
      total:document.getElementById('total-destroyed').textContent,core:document.getElementById('core-label').textContent};
    G.__audit.render();const second={...count};Element.prototype.animate=animate;G.ui=ui;G.updateAchievementUI=achievement;
    return {before,after,second,outcome,visible};
  });
  assert.deepEqual(burst.before,{ui:0,achievement:0,combo:0});
  assert.deepEqual(burst.after,{ui:1,achievement:1,combo:1});assert.deepEqual(burst.second,burst.after);
  assert.equal(burst.visible.kills,'77');assert.equal(burst.visible.total,'77');assert.equal(burst.visible.heat,'3');assert.equal(burst.visible.core,'核心已显现');
  assert.equal(burst.outcome.destroyed,77);report.checks.push({name:'whole-board HUD / achievement / combo coalescing',...burst});
  await page.screenshot({path:path.join(out,'board-hud.png')});
  const bosses=await page.evaluate(()=>{
    const G=Game,results=[];
    for(const id of ['eye','forge','serpent','clock']){
      G.state.level=100;G.state.bossOverride={level:100,boss:id};G.state.milestone=null;G.state.skillChosenLevel=100;
      G.state.draft=null;G.generate(false);G.phase='ready';G.boardEntrance=null;G.boss().intro=true;G.__audit.render();
      const bar=document.querySelector('.boss-bar'),set=bar.setAttribute;let hud=0,pulses=0;
      bar.setAttribute=function(name,value){if(name==='aria-valuenow')hud++;return set.call(this,name,value);};
      const add=bar.classList.add.bind(bar.classList);bar.classList.add=(...names)=>{if(names.includes('is-hit'))pulses++;return add(...names);};
      const hp=G.boss().hp;
      for(let i=0;i<64;i++)G.bossApi.hurt(hp/6400,390,80,{quiet:true});
      const before={hud,pulses},damage=hp-G.boss().hp;G.flushVisuals();const after={hud,pulses};G.flushVisuals();
      const second={hud,pulses};bar.setAttribute=set;bar.classList.add=add;
      results.push({id,before,after,second,damage,label:bar.getAttribute('aria-valuetext')});
    }return results;
  });
  for(const b of bosses){assert.ok(b.damage>0);assert.deepEqual(b.before,{hud:0,pulses:0});assert.deepEqual(b.after,{hud:1,pulses:1});assert.deepEqual(b.second,b.after);}
  report.checks.push({name:'64 synchronous damage requests: each boss paints once',bosses});
  await page.screenshot({path:path.join(out,'boss-hud.png')});
  await page.evaluate(()=>{
    const G=Game;G.state.level=9;G.state.bossOverride=null;G.state.milestone=null;G.state.skills={blizzard:1};G.state.skillChosenLevel=9;
    G.state.draft=null;G.generate(false);G.phase='ready';G.boardEntrance=null;G.ui();G.__audit.render();
    for(const d of document.querySelectorAll('dialog[open]'))d.close();
    G.fx.clear();G.prepareSkillFx();
  });
  // The test deliberately freezes production rAF, including Puppeteer's default
  // polling mechanism. Poll by timer so the real idle callbacks can be observed.
  await page.waitForFunction(()=>Game.fx.stats().warmPending===0,{timeout:15000,polling:100});
  const warm=await page.evaluate(()=>Game.fx.stats());assert.ok(warm.entries>=17);assert.ok(warm.bytes<=warm.maxBytes);
  report.checks.push({name:'ready-only idle atlas prewarm',cache:warm});
  assert.deepEqual(report.errors,[]);fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}finally{await browser?.close();server.close();fs.rmSync(profile,{recursive:true,force:true});}
