#!/usr/bin/env node
/* Capture the actual 412x915 browser design metrics and reference frames. */
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const root=path.resolve(__dirname,'../..');
const puppeteer=require(process.env.CHROME89_PUPPETEER||'puppeteer');
const out=path.join(root,'agent-tmp/godot/reference');
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const server=http.createServer((req,res)=>{
    const file=path.resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
    if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
    try{res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.writeHead(404);res.end();}
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  let browser;
  try{
    browser=await puppeteer.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--disable-gpu']});
    const page=await browser.newPage();await page.setViewport({width:412,height:915,deviceScaleFactor:1});
    await page.goto(`http://127.0.0.1:${server.address().port}/game/index.html`,{waitUntil:'load'});
    await page.click('#intro-skip');await page.waitForSelector('#skill-draft[open]');
    await page.screenshot({path:path.join(out,'draft.png')});
    await page.click('#draft-options button');
    await page.waitForTimeout(2200);
    await page.screenshot({path:path.join(out,'board.png')});
    const metrics=await page.evaluate(()=>{
      const result={};
      for(const id of ['stage','game','arena','earnings-top','earnings','core-progress','shop-trigger']){
        const node=document.getElementById(id),r=node.getBoundingClientRect(),s=getComputedStyle(node);
        result[id]={x:r.x,y:r.y,width:r.width,height:r.height,font:s.font,color:s.color,background:s.backgroundColor};
      }
      result.world={W:Game.W,H:Game.H,origin:Game.origin,view:Game.view};
      result.fonts=[...document.fonts].map(f=>({family:f.family,status:f.status}));
      return result;
    });
    fs.writeFileSync(path.join(out,'metrics.json'),JSON.stringify(metrics,null,2)+'\n');console.log(JSON.stringify(metrics,null,2));
  }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
