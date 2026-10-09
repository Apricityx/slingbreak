const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const read=file=>fs.readFileSync(path.join(ROOT,file),'utf8');
const scripts=html=>[...html.matchAll(/<script src="([^"]+)"/g)].map(match=>match[1]);
const styles=html=>[...html.matchAll(/<link rel="stylesheet" href="([^"]+)"/g)].map(match=>match[1]);
const files=(dir,extension)=>fs.readdirSync(path.join(ROOT,dir),{withFileTypes:true}).flatMap(entry=>{
  const file=dir+'/'+entry.name;
  return entry.isDirectory()?files(file,extension):entry.name.endsWith(extension)?[file]:[];
});
function before(list,dependency,consumer){
  assert.ok(list.includes(dependency),'missing dependency: '+dependency);
  assert.ok(list.includes(consumer),'missing consumer: '+consumer);
  assert.ok(list.indexOf(dependency)<list.indexOf(consumer),dependency+' must load before '+consumer);
}

test('game and benchmark entries resolve every local resource relative to their own URL',()=>{
  for(const entry of ['game/index.html','bench/particles.html']){
    const html=read(entry),base=new URL(entry,'https://example.test/nested/slingbreak/');
    for(const match of html.matchAll(/\b(?:src|href)="([^"]+)"/g)){
      const reference=match[1];
      if(/^(?:https?:|data:|#)/.test(reference))continue;
      const file=path.resolve(ROOT,path.dirname(entry),reference);
      assert.ok(file.startsWith(ROOT+path.sep),entry+': resource must remain in the project');
      assert.ok(fs.statSync(file).isFile(),entry+': missing '+reference);
      assert.ok(new URL(reference,base).pathname.startsWith('/nested/slingbreak/'),entry+': deployment must not assume the origin root');
    }
  }
});

test('the game entry loads every source and stylesheet exactly once',()=>{
  const html=read('game/index.html'),js=scripts(html).filter(file=>file.startsWith('src/')),css=styles(html);
  assert.equal(js.length,new Set(js).size);
  assert.equal(css.length,new Set(css).size);
  assert.deepEqual(js.slice().sort().map(file=>'game/'+file),files('game/src','.js').sort());
  assert.deepEqual(css.slice().sort().map(file=>'game/'+file),files('game/styles','.css').sort());
});

test('module prerequisites and function-wrapper ordering stay explicit',()=>{
  const js=scripts(read('game/index.html'));
  const chain=['src/theme/palette.js','src/theme/colors.js','src/ui/stage.js','src/ui/launcher-mode.js',
    'vendor/matter.min.js','vendor/lucide-subset.js','src/core/game.js','src/effects/fx.js',
    'src/audio/audio-diagnostics.js','src/audio/audio-recipes.js','src/audio/audio-native.js','src/audio/audio.js',
    'src/skills/skills.js','src/core/achievements.js','src/effects/skill-signatures.js',
    'src/skills/skill-expansion.js','src/skills/skill-overdrive.js','src/effects/skill-effects.js',
    'src/render/render.js','src/ui/ui.js','src/ui/skills-ui.js','src/ui/achievements-ui.js',
    'src/effects/intro.js','src/effects/transitions.js','src/effects/juice.js','src/ui/skill-reroll.js',
    'src/bosses/boss-eye.js','src/bosses/boss-forge.js','src/bosses/boss-serpent.js','src/bosses/boss-clock.js',
    'src/bosses/milestone.js','src/bosses/boss-music.js','src/ui/home-screen.js','src/ui/fullscreen.js',
    'src/ui/settings.js','src/ui/admin.js'];
  for(let i=1;i<chain.length;i++)before(js,chain[i-1],chain[i]);
  const css=styles(read('game/index.html'));
  before(css,'styles/tokens.css','styles/color-blends.css');
  before(css,'styles/color-blends.css','styles/style.css');
  before(css,'styles/skills.css','styles/draft.css');
});

test('the particle benchmark loads the current renderer dependencies and uses its relocated entry',()=>{
  const js=scripts(read('bench/particles.html'));
  assert.deepEqual(js,['../game/vendor/matter.min.js','../game/src/theme/palette.js','../game/src/core/game.js','../game/src/render/render.js','particles.js']);
  assert.match(read('bench/run.mjs'),/\/bench\/particles\.html\?/);
  assert.doesNotMatch(read('bench/run.mjs'),/\/bench\.html/);
});

test('game scripts, styles and Node tests no longer spill into the project root',()=>{
  assert.deepEqual(fs.readdirSync(ROOT).filter(name=>/\.(?:js|css)$|\.test\.cjs$/.test(name)),[]);
  assert.equal(fs.existsSync(path.join(ROOT,'bench.html')),false);
  assert.equal(fs.existsSync(path.join(ROOT,'bench.js')),false);
  // All browser runtime resources live inside game/; the root keeps only tooling.
  for(const name of ['index.html','manifest.json','src','styles','vendor','icons'])
    assert.equal(fs.existsSync(path.join(ROOT,name)),false,name+' must move into game/');
  for(const name of ['index.html','manifest.json','src','styles','vendor','icons'])
    assert.ok(fs.existsSync(path.join(ROOT,'game',name)),'game/'+name+' must exist');
});
