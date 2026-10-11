#!/usr/bin/env node
/* Independent UI references: load the shipped page, not the native host shim. */
const fs=require('node:fs'),path=require('node:path'),{pathToFileURL}=require('node:url');
const puppeteer=require(process.env.CHROME89_PUPPETEER||'puppeteer');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'agent-tmp/godot/ui-reference');
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const browser=await puppeteer.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
  try{
    const version=await browser.version();if(!/Chrome\/89\./.test(version))throw new Error('UI references require actual Chromium 89: '+version);
    for(const theme of ['light','dark']){
      const page=await browser.newPage();await page.setViewport({width:412,height:915,deviceScaleFactor:1,isMobile:true,hasTouch:true});
      await page.evaluateOnNewDocument(theme=>{
        localStorage.clear();localStorage.setItem('slingbreak-theme',theme);
        let seed=9128;Math.random=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
      },theme);
      await page.goto(pathToFileURL(path.join(root,'game/index.html')).href+'?client=1');
      await page.waitForFunction(()=>window.Game&&document.querySelector('#skill-draft[open]'));
      await page.waitForTimeout(2000);
      await page.evaluate(()=>{Game.setPerformanceMode(true);document.querySelectorAll('dialog').forEach(d=>{if(d.id!=='skill-draft'&&d.open)d.close();});});
      await page.addStyleTag({content:'*,*::before,*::after{animation:none!important;transition:none!important}'});
      const capture=async(name,selector)=>{
        await page.waitForTimeout(180);
        await page.evaluate(()=>{document.getAnimations().forEach(a=>{try{a.finish();}catch{}});document.activeElement.blur();});
        await page.screenshot({path:path.join(out,name+'-'+theme+'.png')});
        const data=await page.evaluate(selector=>{
          const box=el=>{const r=el.getBoundingClientRect(),s=getComputedStyle(el);return{tag:el.tagName,id:el.id,classes:el.className,text:el.children.length?'':el.textContent,x:r.x,y:r.y,w:r.width,h:r.height,font:s.fontSize,line:s.lineHeight,color:s.color,padding:s.padding,gap:s.gap};};
          const host=document.querySelector(selector),data=[host,...host.querySelectorAll('*')].map(box);
          if(host.tagName==='DIALOG')data[0].backdrop=getComputedStyle(host,'::backdrop').backgroundColor;
          return data;
        },selector);
        fs.writeFileSync(path.join(out,name+'-'+theme+'.json'),JSON.stringify(data,null,2));
      };
      await capture('draft','#skill-draft');
      const state=await page.evaluate(()=>({options:Game.state.draft.options,catalog:Game.skillCatalog.map(s=>({id:s.id,name:s.name,icon:s.icon,tier:s.tier,color:Game.skillColor(s.id),description:s.describe(1)}))}));
      fs.writeFileSync(path.join(out,'fixture-'+theme+'.json'),JSON.stringify(state,null,2));
      await page.evaluate(()=>{Game.chooseSkill(Game.state.draft.options[0]);Game.boardEntrance=null;Game.phase='ready';Game.ui();});
      await page.waitForTimeout(100);
      await page.click('#shop-trigger');await capture('shop','#shop');
      await page.click('#close-shop');await page.click('#settings-toggle');await capture('settings','#settings');
      await page.click('#close-settings');
      await page.evaluate(()=>document.querySelector('#equipment').showModal());await capture('equipment','#equipment');
      await page.click('#open-skills');await capture('library','#skill-library');
      await page.evaluate(()=>{document.querySelector('#skill-library').close();document.querySelector('#equipment').close();document.querySelector('.skill-live .skill-queue-slot[data-skill]').click();});await capture('detail','#skill-detail');
      await page.evaluate(()=>document.querySelector('#skill-detail').close());
      await page.evaluate(()=>{Game.paused=true;document.querySelector('#overlay').hidden=false;});await capture('pause','#overlay');
      await page.evaluate(()=>{document.querySelector('#overlay').hidden=true;document.querySelector('#reset-dialog').showModal();});await capture('reset','#reset-dialog');
      await page.evaluate(()=>document.querySelector('#reset-dialog').close());
      await page.evaluate(()=>{
        Game.levelReport=()=>({level:1,total:1280,parts:[{label:'砖块收入',value:820,color:'#98b95a'},{label:'成就追补',value:180,color:'#b2934d'},{label:'核心奖金',value:240,color:'#7ba5a7'},{label:'技能奖金',value:40,color:'#b485a0'}],bestKills:12,bestMoney:520,record:true,shots:8,bricks:42,skills:[{name:'连击狂热',icon:'flame',count:4},{name:'雷神降临',icon:'zap-off',count:3}]});
        Game.paused=false;Game.phase='ready';Game.clear();Game.clearAt=Infinity;Game.tick=()=>{};
      });await capture('report','.clear-scene');
      await page.close();
    }
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
