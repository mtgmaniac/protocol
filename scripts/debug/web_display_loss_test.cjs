// Web display recovery regression (run after a Web export; see web/shell.html
// "LOST DISPLAY" and docs/audits/APP_SWITCH_FREEZE_2026-10-06.md).
//   node scripts/debug/web_display_loss_test.cjs
// Serves the export itself (WEB_BUILD_DIR, default build/web), forces the WebGL
// context loss a phone causes on an app switch (WEBGL_lose_context), and checks:
//   menu      the overlay covers the game with its copy, the engine's alert()
//             never fires, the page reloads by itself, the game clears the flag
//   loop      a second loss right after that reload is NOT reloaded again: the
//             RELOAD button appears instead, and tapping it reloads
//   hidden    a loss while the page is hidden waits; it reloads on return
//   run       with a run parked in a battle: after the reload the game goes
//             back into the battle by itself, through CONTINUE's own path (the
//             resume guard's marker is written, then cleared by the clean load)
// It needs a browser and an export, so it runs beside web_loader_test.cjs,
// outside verify_gate.py. The static half is the `web display recovery` gate;
// the game's half is in the `resume guard` gate (legs auto, auto_blocked).
// PLAYWRIGHT_MODULE can point to an installed Playwright package.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || '../../debug_artifacts/browser-tools/node_modules/playwright');
const {spawn}=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');

const root=path.resolve(__dirname,'../..');
const buildDir=path.resolve(root,process.env.WEB_BUILD_DIR || 'build/web');
const port=Number(process.env.WEB_DISPLAY_PORT || 8149);
const base=`http://127.0.0.1:${port}`;
const out=process.env.WEB_TEST_OUTPUT || path.join(root,'debug_artifacts/web_display_loss');
fs.mkdirSync(out,{recursive:true});

const RESUME_KEY='op_resume_after_reload';
const RELOADED_AT_KEY='op_display_reloaded_at';
// Menu and squad buttons at a 450x1000 viewport (fractions of the viewport).
const TAP={begin:[0.5,0.542], skipTutorial:[0.5,0.573], deploy:[0.5,0.928]};

const failures=[];
function check(ok,msg){ if(!ok) failures.push(msg); console.log(`${ok?'  ok  ':'  FAIL'} ${msg}`); }

async function boot(page) {
 await page.waitForFunction(()=>window.__opGameStarted===true,null,{timeout:120000});
 await page.waitForTimeout(4500);  // logo ignition; the menu buttons arrive after it
}
async function tap(page,[fx,fy]) {
 const v=page.viewportSize();
 await page.mouse.click(Math.round(v.width*fx),Math.round(v.height*fy));
}
function loseDisplay(page) {
 return page.evaluate(()=>{
  const gl=document.getElementById('canvas').getContext('webgl2');
  gl.getExtension('WEBGL_lose_context').loseContext();
 });
}
function overlay(page) {
 return page.evaluate(()=>{
  const el=document.getElementById('op-lost');
  const button=document.getElementById('op-lost-reload');
  const r=el.getBoundingClientRect();
  return {shown:getComputedStyle(el).display!=='none', covers:r.width>=innerWidth && r.height>=innerHeight,
   onTop:document.elementFromPoint(innerWidth/2,innerHeight*0.8)!==document.getElementById('canvas'),
   title:document.getElementById('op-lost-title').textContent, line:document.getElementById('op-lost-line').textContent,
   button:getComputedStyle(button).display!=='none' ? button.textContent : null};
 });
}
function stored(page,suffix) {
 return page.evaluate((s)=>{
  for(const k of Object.keys(localStorage)) {
   if(k.endsWith(s)) { try { return JSON.parse(localStorage.getItem(k)); } catch(e) { return null; } }
  }
  return null;
 },suffix);
}
// Resolves true when the page reloads within `ms` (a fresh document has no boot mark).
async function reloadsWithin(page,ms) {
 await page.evaluate(()=>{ window.__bootMark=true; });
 const t0=Date.now();
 while(Date.now()-t0<ms) {
  await page.waitForTimeout(150);
  const mark=await page.evaluate(()=>window.__bootMark===true).catch(()=>null);
  if(mark===false) return true;
 }
 return false;
}

(async()=>{
 const server=spawn('python',['-m','http.server',String(port),'--bind','127.0.0.1','--directory',buildDir],{stdio:'ignore'});
 await new Promise(r=>setTimeout(r,800));
 const browser=await chromium.launch({channel:process.env.WEB_TEST_CHANNEL || 'chrome',headless:true});
 try {
  const context=await browser.newContext({viewport:{width:450,height:1000},deviceScaleFactor:2});
  const page=await context.newPage();
  let dialogs=0;
  page.on('dialog',d=>{ dialogs++; d.dismiss().catch(()=>{}); });
  await page.goto(base+'/index.html');
  await boot(page);

  console.log('-- menu: lost display reloads by itself');
  check(!(await overlay(page)).shown, 'no overlay while the display is fine');
  await loseDisplay(page);
  await page.waitForTimeout(250);
  let o=await overlay(page);
  check(o.shown && o.covers && o.onTop, 'the overlay covers the game, so taps cannot reach it');
  check(o.title==='DISPLAY LOST' && o.line==='Reloading to bring it back.' && o.button===null, `copy: "${o.title}" / "${o.line}", no button`);
  await page.screenshot({path:path.join(out,'overlay_auto.png')});
  check(await reloadsWithin(page,5000), 'the page reloads by itself');
  check(dialogs===0, `the engine's alert() never fires (${dialogs} dialog(s))`);
  await boot(page);
  const flag=await page.evaluate((k)=>sessionStorage.getItem(k),RESUME_KEY);
  check(flag===null, 'the game used up the reload flag');
  check(!(await overlay(page)).shown, 'no overlay after the reload');

  console.log('-- loop: a second loss right after our reload offers RELOAD');
  await loseDisplay(page);
  await page.waitForTimeout(250);
  o=await overlay(page);
  check(o.shown && o.line==='Tap RELOAD to bring it back.' && o.button==='RELOAD', `copy: "${o.line}" with a ${o.button} button`);
  await page.screenshot({path:path.join(out,'overlay_manual.png')});
  check(!(await reloadsWithin(page,3000)), 'it does not reload by itself a second time');
  await page.evaluate(()=>{ window.__bootMark=true; });
  await page.click('#op-lost-reload');
  await page.waitForFunction(()=>window.__bootMark!==true,null,{timeout:10000}).then(()=>check(true,'tapping RELOAD reloads'),()=>check(false,'tapping RELOAD reloads'));
  await boot(page);

  console.log('-- hidden: a loss in the background waits for the player');
  await page.evaluate((k)=>{
   sessionStorage.removeItem(k);
   window.__vis='hidden';
   Object.defineProperty(document,'visibilityState',{configurable:true,get:()=>window.__vis});
  },RELOADED_AT_KEY);
  await loseDisplay(page);
  await page.waitForTimeout(250);
  check((await overlay(page)).shown, 'the overlay is up while hidden');
  check(!(await reloadsWithin(page,2500)), 'no reload while the page is hidden');
  await page.evaluate(()=>{ window.__bootMark=true; window.__vis='visible'; document.dispatchEvent(new Event('visibilitychange')); });
  await page.waitForFunction(()=>window.__bootMark!==true,null,{timeout:10000}).then(()=>check(true,'it reloads once the page is visible again'),()=>check(false,'it reloads once the page is visible again'));
  await boot(page);

  console.log('-- run: the game goes back into the battle by itself');
  await page.evaluate((k)=>sessionStorage.removeItem(k),RELOADED_AT_KEY);
  await tap(page,TAP.begin);
  await page.waitForTimeout(3500);
  await tap(page,TAP.skipTutorial);
  await page.waitForTimeout(3500);
  await tap(page,TAP.deploy);
  let run=null;
  for(let i=0;i<40 && !(run && run.screen==='battle');i++) { await page.waitForTimeout(250); run=await stored(page,':run.json'); }
  check(!!run && run.screen==='battle', 'fixture: a run is parked in its first battle');
  await page.waitForTimeout(2500);
  const seqBefore=run ? run.save_seq : -1;
  await loseDisplay(page);
  await page.waitForTimeout(250);
  check((await overlay(page)).shown, 'the overlay is up in the battle');
  check(await reloadsWithin(page,5000), 'the page reloads by itself');
  await page.waitForFunction(()=>window.__opGameStarted===true,null,{timeout:120000});
  // No tap from here on. The marker is CONTINUE's own footprint.
  let sawMarker=false, cleared=false, guard=null;
  for(let i=0;i<120 && !(sawMarker && cleared);i++) {
   await page.waitForTimeout(250);
   guard=await stored(page,'resume_guard.json');
   if(guard && guard.active===true && guard.screen==='battle') sawMarker=true;
   if(sawMarker && guard && guard.active===false) cleared=true;
  }
  check(sawMarker, 'the game resumed by itself through CONTINUE\'s path (resume marker written for the battle)');
  check(cleared, 'the battle loaded cleanly (resume marker cleared)');
  run=await stored(page,':run.json');
  check(!!run && run.screen==='battle' && run.save_seq>seqBefore, `the battle is running again (save ${seqBefore} -> ${run ? run.save_seq : '?'})`);
  check(dialogs===0, `no alert() at any point (${dialogs} dialog(s))`);
  await page.waitForTimeout(1500);
  await page.screenshot({path:path.join(out,'resumed_battle.png')});
  await context.close();
 } finally {
  await browser.close();
  server.kill();
 }
 console.log(failures.length ? `\nFAIL: ${failures.length} check(s)\n - ${failures.join('\n - ')}` : '\nPASS: web display loss');
 process.exit(failures.length ? 1 : 0);
})().catch(e=>{console.error(e);process.exit(1);});
