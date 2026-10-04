#!/usr/bin/env node
// Use a real Chromium 89, not a modern engine with a forged User-Agent.
// CHROME89_PUPPETEER=/absolute/path/to/puppeteer node bench/chrome89.mjs
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(import.meta.url);
const puppeteer=require(process.env.CHROME89_PUPPETEER||'puppeteer');
const modern=process.argv.includes('--compare-modern');
const out=path.join(root,'agent-tmp',modern?'modern-compat':'chrome89-compat');
fs.mkdirSync(out,{recursive:true});
const server=http.createServer((req,res)=>{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const file=path.resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
  if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  try{
    res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.woff2':'font/woff2','.json':'application/json'})[path.extname(file)]||'application/octet-stream');
    res.end(fs.readFileSync(file));
  }catch{res.writeHead(404);res.end();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base=`http://127.0.0.1:${server.address().port}`;
let browser;
const report={checks:[],errors:[]};
try{
  browser=await puppeteer.launch({headless:true,executablePath:process.env.CHROME_BIN||undefined,
    userDataDir:fs.mkdtempSync(path.join(out,'profile-')),args:['--no-sandbox','--disable-dev-shm-usage','--disable-gpu']});
  report.version=await browser.version();
  if(!modern)assert.match(report.version,/Chrome\/89\./,'The compatibility gate requires Chromium 89');
  const page=await browser.newPage();
  page.setDefaultTimeout(15000);
  await page.setViewport({width:412,height:915,deviceScaleFactor:1});
  page.on('pageerror',error=>report.errors.push(String(error)));
  page.on('console',message=>{if(message.type()==='error')report.errors.push(message.text());});
  await page.evaluateOnNewDocument(()=>{
    window.__compat={paints:0,animations:[],invalid:[],rejections:[]};
    window.addEventListener('unhandledrejection',event=>window.__compat.rejections.push(String(event.reason)));
    for(const method of ['fill','fillRect','stroke','drawImage']){
      const original=CanvasRenderingContext2D.prototype[method];
      CanvasRenderingContext2D.prototype[method]=function(...args){window.__compat.paints++;return original.apply(this,args);};
    }
    const animate=Element.prototype.animate;
    Element.prototype.animate=function(frames,options){
      if(Array.isArray(frames))for(const frame of frames)for(const [key,value] of Object.entries(frame)){
        if(['offset','easing','composite'].includes(key))continue;
        const css=key.replace(/[A-Z]/g,c=>'-'+c.toLowerCase());
        if(!CSS.supports(css,String(value)))window.__compat.invalid.push({key,value});
      }
      window.__compat.animations.push({className:this.className,frames});
      return animate.call(this,frames,options);
    };
  });
  const capture=async name=>{await page.screenshot({path:path.join(out,name+'.png')});};
  const check=async name=>{
    const probe=await page.evaluate(()=>({invalid:window.__compat.invalid,rejections:window.__compat.rejections,paints:window.__compat.paints}));
    assert.deepEqual(probe.invalid,[],name+': all animated declarations supported');
    assert.deepEqual(probe.rejections,[],name+': no unhandled promise rejections');
    assert.deepEqual(report.errors,[],name+': no page errors');
    assert.ok(probe.paints>0,name+': actual Canvas drawing');
    report.checks.push({name,paints:probe.paints});
  };
  // Parse all shipped scripts, including optional browser benchmark drivers.
  await page.goto(base,{waitUntil:'load'});
  const scripts=fs.readdirSync(root).filter(name=>name.endsWith('.js'));
  scripts.push('bench/fx-page.js','vendor/matter.min.js','vendor/lucide-subset.js');
  for(const file of scripts)await page.evaluate(text=>{new Function(text);},fs.readFileSync(path.join(root,file),'utf8'));
  report.checks.push({name:'all shipped JavaScript parses'});
  await page.waitForSelector('#game-intro[open]');
  await capture('intro');
  await page.click('#intro-skip');
  await page.waitForSelector('#skill-draft[open]');
  await page.waitForTimeout(1500);
  const art=await page.$eval('#skill-draft .skill-card',card=>({card:card.getBoundingClientRect().height,art:card.querySelector('.skill-card-art').getBoundingClientRect().height}));
  assert.ok(Math.abs(art.card-art.art-2)<2,'art column stretches to the complete card, including pre-LayoutNG button grids');
  await capture('draft-light');
  await check('opening and draft');
  // Verify all blend tokens numerically, including dark/light + each boss palette.
  const blends=await page.evaluate(()=>{
    const sheet=[...document.styleSheets].find(s=>s.href?.endsWith('/color-blends.css'));
    const rules=[...sheet.cssRules].filter(rule=>rule.style);
    const results=[];
    const C=window.SlingColors;
    const sample=document.createElement('span');
    const colour=(host,value)=>{
      sample.style.color='';sample.style.color=value;host.append(sample);
      const computed=getComputedStyle(sample).color.match(/[\d.]+/g).map(Number);
      return computed.length===3?[...computed,1]:computed;
    };
    for(const theme of ['light','dark']){
      window.SlingTheme.set(theme);
      for(const boss of ['eye','forge','serpent','clock'])for(const rule of rules){
        const host=document.createElement('div');
        const selector=rule.selectorText.split(',')[0];
        if(selector===':root')host.className='blend-root';
        else if(selector.startsWith('#'))host.id=selector.slice(1);
        else host.className=selector.split('.').filter(Boolean).join(' ');
        host.dataset.boss=boss;
        for(const name of ['skill-color','preview-color','pick-color','skill-detail-color','achievement-accent','hero-accent','mark-accent'])C.set(host,'--'+name,'#439be8');
        document.body.append(host);
        for(const name of [...rule.style].filter(name=>name.startsWith('--mix-'))){
          const [,a,p,b]=name.match(/^--mix-(.+)-(\d+)-(.+)$/),weight=Number(p)/100;
          const source=colour(host,`var(--${a},var(--accent-ink))`);
          const target=b==='alpha'?[0,0,0,0]:colour(host,/^[0-9a-f]{6}$/.test(b)?'#'+b:`var(--${b})`);
          const expected=b==='alpha'?[...source.slice(0,3),weight]:source.slice(0,3).map((n,i)=>n*weight+target[i]*(1-weight)).concat(1);
          const actual=colour(host,`var(${name})`);
          if(actual.some((n,i)=>Math.abs(n-expected[i])>(i===3?.005:1)))throw Error(`${theme}/${boss}/${name}: ${actual} != ${expected}`);
          results.push({theme,boss,name,actual});
        }
        host.remove();
      }
    }
    window.SlingTheme.set('light');
    return results;
  });
  report.checks.push({name:'sRGB colour parity',samples:blends.length});
  // First pick: exercise the real keyboard handler and modal top-layer flight.
  const cardRect=()=>page.$eval('#draft-options .skill-card',el=>{const r=el.getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height};});
  const beforeHover=await cardRect();
  await page.hover('#draft-options .skill-card');
  await page.waitForTimeout(300);
  assert.equal(await page.$eval('#draft-options .skill-card',el=>getComputedStyle(el).transform),'none','hover does not move the draft card');
  assert.deepEqual(await cardRect(),beforeHover,'hover preserves the draft card position and size');
  assert.ok(await page.$eval('#draft-options .skill-emblem',el=>new DOMMatrix(getComputedStyle(el).transform).a>1.04),'hover emblem retains its scale');
  await capture('draft-hover');
  report.checks.push({name:'stationary draft hover retains emblem feedback'});
  await page.keyboard.press('1');
  await page.waitForTimeout(140);
  assert.notEqual(await page.$eval('.skill-card.is-picked',el=>getComputedStyle(el).transform),'none','commit lift is not overridden by hover CSS');
  await page.waitForSelector('dialog.skill-flight[open]');
  const flight=await page.$eval('.skill-flight',el=>({tag:el.tagName,backdrop:getComputedStyle(el,'::backdrop').backgroundColor,
    rect:{width:el.getBoundingClientRect().width,height:el.getBoundingClientRect().height},transform:getComputedStyle(el.firstElementChild).transform}));
  assert.equal(flight.tag,'DIALOG');assert.equal(flight.backdrop,'rgba(0, 0, 0, 0)');
  assert.ok(flight.rect.width>0&&flight.rect.height>0);assert.notEqual(flight.transform,'none');
  await capture('pick-flight');
  await page.waitForFunction(()=>Game.phase==='ready'&&!document.querySelector('.skill-flight'));
  await capture('board-light');
  assert.equal(await page.evaluate(()=>document.activeElement.id),'game');
  await check('pick flight, focus restoration and board entrance');
  // Theme classes and custom checkbox / volume fill replace :has + accent-color.
  await page.click('#settings-toggle');
  await page.waitForTimeout(600);
  await page.$eval('input[name="theme"][value="dark"]',el=>el.click());
  await page.waitForTimeout(500);
  assert.equal(await page.$eval('.theme-option.is-selected input',el=>el.value),'dark');
  await page.$eval('#sound-volume',el=>{el.value='37';el.dispatchEvent(new Event('input',{bubbles:true}));});
  assert.equal(await page.$eval('#sound-volume',el=>getComputedStyle(el).getPropertyValue('--volume-fill').trim()),'37%');
  await capture('settings-dark');
  await page.click('#close-settings');
  await page.waitForFunction(()=>!document.getElementById('settings').open);
  await capture('board-dark');
  await check('theme, settings and sound slider');
  // Exercise actual native Web Audio on the old engine via a trusted pointer.
  await page.evaluate(()=>{Game.lockInput(0);});
  await page.click('#game');
  await page.waitForFunction(()=>Game.audio.diagnosticSnapshot().state==='running');
  const audio=await page.evaluate(()=>{Game.sound('break',1,390);return Game.audio.diagnosticSnapshot();});
  assert.equal(audio.backend,'web-audio');assert.ok(audio.activeSources>0);
  report.checks.push({name:'Web Audio schedules real sources',sampleRate:audio.sampleRate});
  // A full queue pick must drop the outgoing token without hanging the top layer.
  await page.evaluate(()=>{
    Game.state.volume=0;Game.audio.sync();Game.state.up.slots=3;
    Game.state.skills={titan:1,trident:1,ice:1,echo:1};
    Game.phase='ready';Game.state.level=60;Game.state.board=null;Game.state.draft=null;Game.state.skillChosenLevel=0;Game.generate();Game.ui();
  });
  await page.waitForSelector('#skill-draft[open]');
  await page.waitForTimeout(1500);
  assert.equal(await page.evaluate(()=>Game.activeSkills().length),4,'full queue fixture');
  await capture('draft-dark-full');
  await page.keyboard.press('2');
  await page.waitForSelector('dialog.skill-flight-drop[open]');
  await capture('queue-drop');
  await page.waitForFunction(()=>Game.phase==='ready'&&!document.querySelector('.skill-flight,.skill-flight-drop'));
  await check('full queue replacement');
  // All four boss scripts, overlays and roundRect fallback execute on Chrome 89.
  for(const boss of ['eye','forge','serpent','clock']){
    await page.goto(base+'/?boss='+boss,{waitUntil:'load'});
    await page.waitForFunction(id=>Game.boss?.()?.boss===id,{},boss);
    if(await page.$('#skill-draft[open]')){
      await page.waitForTimeout(1500);await page.keyboard.press('1');
    }
    await page.waitForFunction(()=>Game.phase==='ready');
    await page.waitForTimeout(1500);
    await capture('boss-'+boss);
    await check('boss '+boss);
  }
  await page.goto(base+'/?launcher=1',{waitUntil:'load'});
  await page.waitForTimeout(1500);
  await capture('launcher');
  await check('launcher mode');
  // Local Android assets use file:// rather than an HTTP origin.
  if(!modern){
    await page.goto('file://'+path.join(root,'index.html')+'?launcher=1',{waitUntil:'load'});
    await page.waitForTimeout(1500);
    await check('file asset entry');
  }
  // Reduced motion must keep immediate selection and repaint, not run flights.
  await page.emulateMediaFeatures([{name:'prefers-reduced-motion',value:'reduce'}]);
  await page.goto(base+'/?admin=1',{waitUntil:'load'});
  await page.waitForSelector('#skill-draft[open]');
  await page.keyboard.press('3');
  await page.waitForFunction(()=>Game.phase==='ready');
  assert.equal(await page.$('.skill-flight'),null);
  await check('reduced motion');
  // Layouts remain the same fixed stage, including letterboxes and safe fits.
  for(const [width,height] of [[360,800],[768,1024],[1440,900]]){
    await page.setViewport({width,height,deviceScaleFactor:1});
    await page.waitForTimeout(200);
    const rect=await page.$eval('#stage',el=>{const r=el.getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height};});
    assert.ok(rect.x>=-1&&rect.y>=-1&&rect.x+rect.width<=width+1&&rect.y+rect.height<=height+1);
    await capture('layout-'+width+'x'+height);
  }
  report.checks.push({name:'mobile, tablet and desktop stage fits'});
  report.passed=true;
}catch(error){report.passed=false;report.failure=String(error);throw error;}
finally{
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
  await browser?.close();await new Promise(resolve=>server.close(resolve));
  console.log(JSON.stringify(report,null,2));
}
