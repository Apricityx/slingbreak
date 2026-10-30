#!/usr/bin/env node
/* Exercise the exported Godot canvas, with no reference-game script injected. */
const fs=require('node:fs'),path=require('node:path');
const puppeteer=require(process.env.CHROME89_PUPPETEER||'puppeteer');
const root=path.resolve(__dirname,'../..');
const out=process.env.GODOT_WEB_CHECK_OUT?path.resolve(process.env.GODOT_WEB_CHECK_OUT):path.join(root,'agent-tmp/godot/web-native-check');
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const browser=await puppeteer.launch({headless:true,executablePath:process.env.CHROME_BIN||undefined,args:['--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  try{
    const page=await browser.newPage(),errors=[],requests=[],consoleLines=[],pending=new Set();
    page.on('pageerror',e=>errors.push(String(e)));
    page.on('console',m=>{
      const line=m.text();
      if(consoleLines.length<200)consoleLines.push(line);
      if(/SCRIPT ERROR:|ERROR:|GL ERROR|shader failed to compile|CompileError:|RuntimeError:|Aborted\(/.test(line)&&!errors.includes(line))errors.push(line);
    });
    page.on('request',r=>{if(!r.url().startsWith('data:')){requests.push(r.url());pending.add(r.url());}});
    page.on('requestfinished',r=>pending.delete(r.url()));
    page.on('requestfailed',request=>{pending.delete(request.url());errors.push('REQUEST '+request.url()+' '+String(request.failure()?.errorText||''));});
    await page.setViewport({width:412,height:915,deviceScaleFactor:1});
    const webgl=await page.evaluate(()=>{
      const canvas=document.createElement('canvas'),gl=canvas.getContext('webgl2');
      if(!gl)return {available:false};
      const capabilities={available:true,version:gl.getParameter(gl.VERSION),
        fragmentUniformVectors:gl.getParameter(gl.MAX_FRAGMENT_UNIFORM_VECTORS),
        uniformBlockSize:gl.getParameter(gl.MAX_UNIFORM_BLOCK_SIZE)};
      const release=gl.getExtension('WEBGL_lose_context');if(release)release.loseContext();
      return capabilities;
    });
    const captures=[];
    async function capture(name){
      const png=await page.screenshot({path:path.join(out,name+'.png')});
      const colours=await page.evaluate(async data=>{
        const image=new Image();
        await new Promise((resolve,reject)=>{image.onload=resolve;image.onerror=reject;image.src=data;});
        const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;
        const context=canvas.getContext('2d');context.drawImage(image,0,0);
        const pixels=context.getImageData(0,0,canvas.width,canvas.height).data,colours=new Set();
        for(let at=0;at<pixels.length;at+=4)colours.add((pixels[at]<<16)|(pixels[at+1]<<8)|pixels[at+2]);
        return colours.size;
      },'data:image/png;base64,'+Buffer.from(png).toString('base64'));
      captures.push({name,colours});
      if(colours<100)errors.push('Blank or incomplete Godot capture: '+name+' ('+colours+' colours)');
    }
    try{
      // Godot fetches WASM/PCK after document load; network idle is not engine readiness.
      await page.goto(process.argv[2]||'http://127.0.0.1:8083/',{waitUntil:'load',timeout:120000});
      const deadline=Date.now()+90000;
      while(await page.$('#status')){
        if(errors.length)throw new Error(errors.join('\n'));
        if(Date.now()>deadline)throw new Error('Godot startup timed out');
        await new Promise(resolve=>setTimeout(resolve,250));
      }
    }catch(e){
      const notice=await page.evaluate(()=>document.body.innerText);
      await page.screenshot({path:path.join(out,'startup-failure.png')});
      fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({browser:await browser.version(),webgl,errors,requests,pending:[...pending],consoleLines,notice},null,2)+'\n');
      throw new Error(notice+'\n'+errors.join('\n')+'\n'+String(e));
    }
    await new Promise(resolve=>setTimeout(resolve,4000));
    await capture('draft');
    // Selection includes flight, curtain and staggered brick entrance. Wait
    // until they settle before exercising input; entering boards reject shots.
    await page.keyboard.press('1');await new Promise(resolve=>setTimeout(resolve,5000));
    await capture('board');
    await page.mouse.move(206,742);await page.mouse.down();
    await page.mouse.move(226,790,{steps:8});await new Promise(resolve=>setTimeout(resolve,250));
    await capture('aiming');
    await page.mouse.up();await new Promise(resolve=>setTimeout(resolve,200));
    await capture('shooting');
    await page.keyboard.press('Space');await new Promise(resolve=>setTimeout(resolve,2000));
    await page.keyboard.press('Escape');await new Promise(resolve=>setTimeout(resolve,600));
    await capture('pause');
    const report={browser:await browser.version(),webgl,errors,requests,consoleLines,captures,screenshots:captures.map(item=>item.name),scope:'Export startup, pointer aim/release, keyboard exercise and non-blank screenshots; native GUI gate asserts semantic input results'};
    fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
    if(errors.length)throw new Error(errors.join('\n'));
    if(requests.some(url=>/game\/|libsling_runtime|generated\//.test(url)))throw new Error('Obsolete runtime requested');
    console.log('Exported Godot Web startup/input smoke passed: '+report.browser);
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
