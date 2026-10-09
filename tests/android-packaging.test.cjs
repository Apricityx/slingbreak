const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const read=file=>fs.readFileSync(path.join(ROOT,file),'utf8');

test('Android bundles the browser source by whitelist without a second game copy',()=>{
  const gradle=read('android/app/build.gradle');
  for(const resource of ['index.html','manifest.json','src/**/*.js','styles/*.css','icons/**','vendor/matter.min.js','vendor/lucide-subset.js']) {
    assert.ok(gradle.includes("'"+resource+"'"),resource);
  }
  assert.match(gradle,/from\(rootProject\.file\('\.\.\/game'\)\)/);
  assert.match(gradle,/tasks\.named\('preBuild'\).*dependsOn syncGameAssets/);
  assert.match(gradle,/generated\/game-assets\/game/);
  assert.equal(fs.existsSync(path.join(ROOT,'android/app/src/main/assets/game')),false);
  assert.doesNotMatch(gradle,/include ['"](?:\*\*\/\*|bench\/|agent-tmp\/|tests\/)/);
});

test('Android keeps a fixed local origin and release-only native update privileges',()=>{
  const activity=read('android/app/src/main/java/io/github/apricityx/slingbreak/MainActivity.java');
  const local=read('android/app/src/main/java/io/github/apricityx/slingbreak/LocalGame.java');
  assert.match(local,/https:\/\/appassets\.androidplatform\.net/);
  assert.match(local,/\/assets\/game\/index\.html/);
  assert.match(activity,/GAME \+ "\?client=1"/);
  assert.match(local,/slingbreak:\/\/check-update/);
  assert.match(activity,/requestCheck\(\)/);
  assert.match(activity,/request\.isForMainFrame\(\), request\.hasGesture\(\), request\.isRedirect\(\)/);
  assert.match(local,/mainFrame && gesture && !redirect && document\(source\)/);
  assert.doesNotMatch(activity,/离线 Gecko/);
  assert.match(activity,/root\.addView\(view, new FrameLayout\.LayoutParams\(-1, -1\)\)/);
  assert.match(activity,/view\.getX5WebViewExtension\(\) == null/);
  assert.doesNotMatch(activity,/toolbar|setPadding\(|setOnApplyWindowInsetsListener|TextView/);
  assert.match(activity,/LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS/);
  assert.match(activity,/LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES/);
  assert.match(activity,/BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE/);
  assert.match(activity,/hide\(WindowInsetsCompat\.Type\.systemBars\(\)\)/);
  assert.match(activity,/setWebContentsDebuggingEnabled\(BuildConfig\.DEBUG\)/);
  assert.doesNotMatch(activity,/loadUri\([^)]*launcher=1/);
  assert.doesNotMatch(activity,/isolatedProcessEnabled\(false\)|appZygoteProcessEnabled\(false\)/);
  assert.match(activity,/addJavascriptInterface\(audio, "SlingNativeAudio"\)/);
  const audio=read('android/app/src/main/java/io/github/apricityx/slingbreak/NativeAudio.java');
  assert.match(audio,/documentActive && token == session/);
  assert.doesNotMatch(audio,/@JavascriptInterface[^\n]*(?:File|URL|install|download)/);
  const manifest=read('android/app/src/main/AndroidManifest.xml');
  assert.match(manifest,/usesCleartextTraffic="false"/);
  assert.match(manifest,/REQUEST_INSTALL_PACKAGES/);
  assert.doesNotMatch(manifest,/MANAGE_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|READ_EXTERNAL_STORAGE/);
  assert.match(read('android/app/src/main/res/xml/update_paths.xml'),/path="updates\/"/);
});

test('X5 replaces Gecko with a pinned arm64-only offline runtime and verified API36 patch',()=>{
  const gradle=read('android/app/build.gradle');
  assert.doesNotMatch(gradle,/org\.mozilla|geckoVersion/);
  assert.match(gradle,/com\.tencent\.tbs:tbssdk:44286/);
  assert.match(gradle,/include 'arm64-v8a'/);
  assert.doesNotMatch(gradle,/include 'arm64-v8a',/);
  const script=read('android/tools/prepare-x5.py');
  assert.match(script,/SHA-256 mismatch/);
  assert.match(script,/if-eq p1, v0, :cond_8d/);
  assert.match(script,/if-eq p1, v0, :cond_ba/);
  const core=read('android/app/src/main/java/io/github/apricityx/slingbreak/X5Core.java');
  assert.match(core,/Build\.VERSION\.SDK_INT == 36/);
  assert.match(core,/ORIGINAL\.equals\(current\)/);
  assert.match(core,/setReadOnly\(\)/);
  const verifier=read('android/app/src/main/java/io/github/apricityx/slingbreak/update/ApkVerifier.java');
  assert.match(verifier,/RuntimeArchive\.supports/);
  assert.doesNotMatch(verifier,/libxul/);
});

test('Android signing secrets and build output stay ignored; no debug-key release fallback',()=>{
  const ignore=read('.gitignore');
  for(const entry of ['/android/signing.properties','/android/keystore/','/android/**/build/'])assert.ok(ignore.includes(entry));
  const gradle=read('android/app/build.gradle');
  assert.match(gradle,/Release signing missing/);
  assert.doesNotMatch(gradle,/signingConfig signingConfigs\.debug/);
});
