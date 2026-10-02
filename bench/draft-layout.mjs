#!/usr/bin/env node
// Frame-by-frame draft/flight layout regression, using actual Chromium 89.
// CHROME89_PUPPETEER=/absolute/path/to/puppeteer node bench/draft-layout.mjs
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(import.meta.url),puppeteer=require(process.env.CHROME89_PUPPETEER||'puppeteer');
const record=process.argv.includes('--record'),modern=process.argv.includes('--compare-modern');
const out=path.join(root,'agent-tmp','draft-layout',`${modern?'modern':'chrome89'}-${record?'before':'after'}`);
fs.mkdirSync(out,{recursive:true});
const server=http.createServer((req,res)=>{
  const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const file=path.resolve(root,'.'+(name==='/'?'/index.html':name));
  if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  try{res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}
  catch{res.writeHead(404);res.end();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
let browser;
const report={cases:[],errors:[]};
try{
  browser=await puppeteer.launch({headless:true,executablePath:process.env.CHROME_BIN||undefined,
    userDataDir:fs.mkdtempSync(path.join(out,'profile-')),args:['--no-sandbox','--disable-gpu','--disable-dev-shm-usage']});
  report.version=await browser.version();if(!modern)assert.match(report.version,/Chrome\/89\./);
  for(const [width,height] of [[412,915],[360,800],[768,1024]])for(const long of [false,true]){
    const page=await browser.newPage();page.on('pageerror',error=>report.errors.push(String(error)));
    await page.setViewport({width,height,deviceScaleFactor:1});
    await page.evaluateOnNewDocument(()=>{
      let n=987654321;Math.random=()=>{n=(1664525*n+1013904223)>>>0;return n/4294967296;};
      localStorage.clear();localStorage.setItem('slingbreak-theme','light');
    });
    await page.goto(`http://127.0.0.1:${server.address().port}/?admin=1`,{waitUntil:'load'});
    await page.click('#intro-skip');await page.waitForSelector('#skill-draft[open]');await page.waitForTimeout(1300);
    await page.evaluate(long=>{
      const draft=document.getElementById('skill-draft');HTMLDialogElement.prototype.close.call(draft);
      Game.state.volume=0;Game.audio.sync();Game.state.level=60;
      const choices=Game.skillCatalog.filter(s=>!Game.skillRank(s.id)).sort((a,b)=>b.describe(1).length-a.describe(1).length).slice(0,3);
      if(long)for(const s of choices){const description=s.describe(1);s.describe=()=>description+' · 保留原技能效果，在较长的说明中仍能滚动查看，不因动画缩窄而重新换行。'.repeat(3);}
      Game.state.draft={level:60,options:choices.map(s=>s.id)};Game.state.skillChosenLevel=0;Game.phase='draft';Game.ui();
      const box=el=>{const s=getComputedStyle(el);return{width:parseFloat(s.width),height:parseFloat(s.height)};};
      const text=el=>{
        const range=document.createRange();range.selectNodeContents(el);
        return{...box(el),lines:range.getClientRects().length};
      };
      window.__draftLayout={entry:[],flight:[],source:null,done:false};
      const start=performance.now();
      const sample=()=>{
        const probe=window.__draftLayout;
        if(draft.open&&!draft.classList.contains('is-selecting'))probe.entry.push({at:performance.now()-start,
          width:draft.offsetWidth,height:draft.offsetHeight,clientWidth:draft.clientWidth,clientHeight:draft.clientHeight,
          scrollWidth:draft.scrollWidth,scrollHeight:draft.scrollHeight,scrollTop:draft.scrollTop,
          cards:[...draft.querySelectorAll('.skill-card')].map(box)});
        const flight=document.querySelector('.skill-flight');
        if(flight){const card=flight.querySelector('.skill-flight-card'),slot=flight.querySelector('.skill-flight-slot');
          probe.flight.push({at:performance.now()-start,outline:getComputedStyle(flight).outlineStyle,card:box(card),body:text(card.querySelector('.skill-card-body')),
            desc:text(card.querySelector('.skill-card-desc')),slot:text(slot.querySelector('b'))});}
        if(!probe.done)requestAnimationFrame(sample);
      };requestAnimationFrame(sample);
    },long);
    await page.waitForSelector('#skill-draft[open]');await page.waitForTimeout(1300);
    const source=await page.$eval('#draft-options .skill-card',card=>{
      const box=el=>{const s=getComputedStyle(el);return{width:parseFloat(s.width),height:parseFloat(s.height)};};
      const text=el=>{const range=document.createRange();range.selectNodeContents(el);return{...box(el),lines:range.getClientRects().length};};
      return{card:box(card),body:text(card.querySelector('.skill-card-body')),desc:text(card.querySelector('.skill-card-desc'))};
    });
    // Real over-height content must remain reachable even without a gutter.
    const scroll=await page.$eval('#skill-draft',el=>{const height=el.scrollHeight,client=el.clientHeight;el.scrollTop=height;const bottom=el.scrollTop;el.scrollTop=0;return{height,client,bottom};});
    await page.keyboard.press('1');await page.waitForSelector('.skill-flight[open]');
    await page.screenshot({path:path.join(out,`${width}x${height}-${long?'long':'normal'}-flight.png`)});
    await page.waitForFunction(()=>!document.querySelector('.skill-flight')&&Game.phase==='ready');
    const data=await page.evaluate(()=>{window.__draftLayout.done=true;return window.__draftLayout;});
    const span=(rows,key)=>Math.max(...rows.map(row=>row[key]))-Math.min(...rows.map(row=>row[key]));
    const summary={width,height,long,source,scroll,entryFrames:data.entry.length,flightFrames:data.flight.length,
      dialogWidthChange:span(data.entry,'width'),dialogHeightChange:span(data.entry,'height'),contentWidthChange:span(data.entry,'clientWidth'),
      scrollHeightChange:span(data.entry,'scrollHeight'),scrollWidthChange:span(data.entry,'scrollWidth'),
      bodyWidthChange:span(data.flight.map(f=>f.body),'width'),descLineChange:span(data.flight.map(f=>f.desc),'lines'),
      slotLineChange:span(data.flight.map(f=>f.slot),'lines'),firstFlight:data.flight[0]};
    report.cases.push(summary);
    fs.writeFileSync(path.join(out,`${width}x${height}-${long?'long':'normal'}-frames.json`),JSON.stringify(data,null,2));
    if(!record){
      assert.ok(data.entry.length>10&&data.flight.length>5,'observed both animation phases');
      assert.equal(summary.dialogWidthChange,0,'dialog width does not jump');
      assert.equal(summary.dialogHeightChange,0,'dialog height does not jump');
      assert.equal(summary.contentWidthChange,0,'no scrollbar gutter changes');
      assert.equal(summary.scrollHeightChange,0,'deal transforms do not enlarge vertical scroll range');
      assert.equal(summary.scrollWidthChange,0,'deal transforms do not enlarge horizontal scroll range');
      assert.equal(summary.bodyWidthChange,0,'flight text keeps its layout width');
      assert.equal(summary.descLineChange,0,'flight description line count stays fixed');
      assert.equal(summary.slotLineChange,0,'incoming slot line count stays fixed');
      assert.ok(data.flight.every(f=>f.outline==='none'),'decorative flight dialog never gains a native focus outline');
      assert.ok(Math.abs(summary.firstFlight.body.width-source.body.width)<.1,'ghost uses original untransformed text width');
      assert.equal(summary.firstFlight.desc.lines,source.desc.lines,'ghost retains original line breaks');
      if(long){assert.ok(scroll.height>scroll.client,'fixture requires real scrolling');assert.ok(scroll.bottom>0,'all long cards remain scrollable');}
    }
    await page.close();
  }
  assert.deepEqual(report.errors,[]);report.passed=true;
}catch(error){report.passed=false;report.failure=String(error);throw error;}
finally{
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
  await browser?.close();await new Promise(resolve=>server.close(resolve));console.log(JSON.stringify(report,null,2));
}
