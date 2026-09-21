// Run after a Web export. Uses real mouse input; __tut only reports geometry.
// The canvas is the whole iframe (Adaptive resize, canvas_items + expand): the
// design height is always 2400 and the design WIDTH follows the iframe aspect.
// PLAYWRIGHT_MODULE can point to an installed Playwright package.
// WEB_TEST_URL defaults to a locally served build/web directory.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || '../../debug_artifacts/browser-tools/node_modules/playwright');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const base=process.env.WEB_TEST_URL || 'http://127.0.0.1:8142';
const out=process.env.WEB_TEST_OUTPUT || 'debug_artifacts/desktop_web';
fs.mkdirSync(out,{recursive:true});
const embed=`<!doctype html><style>html,body{margin:0;height:100%;overflow:hidden;background:#24232b;color:white}header{height:32px}iframe{display:block;border:0;width:100%;height:calc(100% - 32px)}iframe:fullscreen{height:100%;width:100%}</style><header><button onclick="document.querySelector('iframe').requestFullscreen()">Fullscreen</button> Local embed test</header><iframe src="${base}/index.html" allowfullscreen></iframe>`;
let browser, activePage;
const failures=[]; const log=[];
(async()=>{
 browser=await chromium.launch({channel:process.env.WEB_TEST_CHANNEL || 'chrome',headless:true});
 for(const dpr of [1,2]) {
  const context=await browser.newContext({viewport:{width:1366,height:768},deviceScaleFactor:dpr});
  const page=await context.newPage();
  activePage=page;
  page.on('console',m=>{const s=m.text();log.push(s);if(/SCRIPT ERROR:|ERROR:/.test(s)) failures.push(s);});
  page.on('pageerror',e=>failures.push(e.message));
  await page.route('**/_desktop_embed',route=>route.fulfill({contentType:'text/html',body:embed}));
  await page.goto(base+'/_desktop_embed');
  const frame=page.frames().find(f=>f!==page.mainFrame());
  await frame.waitForFunction(()=>window.Engine, null, {timeout:30000});
  await page.waitForTimeout(11000);
  async function clickPoint(x,y,hold=0,drift=0) {
   const box=await frame.locator('canvas').boundingBox();
   const designW=2400*box.width/box.height;
   const px=box.x+x/designW*box.width, py=box.y+y/2400*box.height;
   await page.mouse.move(px,py); await page.mouse.down();
   if(drift) await page.mouse.move(px+drift,py,{steps:4});
   await page.waitForTimeout(hold || 45); await page.mouse.up();
   await page.waitForTimeout(160);
  }
  const click=async r=>{assert(r?.[2]>0 && r?.[3]>0,'target has a rectangle');await clickPoint(r[0]+r[2]/2,r[1]+r[3]/2);};
  const state=async()=>frame.evaluate(()=>{window.__tut_refresh?.();return window.__tut;});
  const centreX=async()=>{const b=await frame.locator('canvas').boundingBox();return 1200*b.width/b.height;};
  await clickPoint(await centreX(),1304); // BEGIN on a fresh profile
  await page.waitForTimeout(900); // Let the prompt's containers finish layout.
  await clickPoint(await centreX(),1244); // RUN TUTORIAL
  await frame.waitForFunction(()=>window.__tut?.title==='WELCOME', null, {timeout:30000});
  await page.waitForTimeout(700);
  for(const [width,height] of [[432,992],[512,992],[560,992],[1366,768],[1920,1080],[1280,450]]) {
   await page.setViewportSize({width,height}); await page.waitForTimeout(350);
   const fit=await frame.evaluate(()=>{const r=document.querySelector('canvas').getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height,vw:innerWidth,vh:innerHeight,sw:document.documentElement.scrollWidth,sh:document.documentElement.scrollHeight};});
   assert(Math.abs(fit.w-fit.vw)<=1 && Math.abs(fit.h-fit.vh)<=1,'canvas fills the iframe (no page-side width cap)');
   assert(fit.sw<=fit.vw && fit.sh<=fit.vh,'game document has no scrolling');
   const t=await state(); const vp=t.viewport;
   assert.equal(vp[3],2400,'design height stays 2400');
   assert(Math.abs(vp[2]-2400*fit.w/fit.h)<=2,`design width follows the iframe aspect (${vp[2]})`);
   assert(t.coach[0]>=0 && t.coach[1]>=0 && t.coach[0]+t.coach[2]<=vp[2]+1 && t.coach[1]+t.coach[3]<=vp[3]+1,'coach stays on screen');
   console.log(`[DESKTOP_WEB] ${width}x${height} DPR ${dpr}: canvas ${fit.w}x${fit.h}, design ${vp[2]}x${vp[3]}`);
  }
  await page.setViewportSize({width:1366,height:768}); await page.waitForTimeout(300);
  await page.screenshot({path:`${out}/operation_dpr${dpr}.png`});
  // Enter/leave the actual Fullscreen API while a gated instruction is active.
  while((await state()).advance==='tap') await click((await state()).coach);
  await page.locator('button').click();
  await page.waitForFunction(()=>!!document.fullscreenElement);
  await page.waitForTimeout(400);
  assert.equal((await state()).advance,'roll_pressed');
  await page.evaluate(()=>document.exitFullscreen()); await page.waitForTimeout(400);
  await click((await state()).roll_button);
  await frame.waitForFunction(()=>window.__tut?.advance==='inspected', null, {timeout:20000});
  // A genuine held mouse gesture with 10 CSS px drift, including high DPI.
  let t=await state(); const portrait=t.cards.combat;
  await clickPoint(portrait[0]+portrait[2]/2,portrait[1]+portrait[3]*0.35,600,10);
  assert((await state()).inspection_open,'scaled long press opens inspection');
  await clickPoint(20,1200);
  await page.waitForTimeout(400);
  assert.notEqual((await state()).advance,'inspected','closing inspection advances');
  if(dpr===2) { await context.close(); continue; }
  let usedAssist=false, sawNudge=false, finished=false;
  const deadline=Date.now()+150000;
  while(Date.now()<deadline) {
   t=await state();
   if(t.advance==='tap_finish') {finished=true; await page.screenshot({path:`${out}/battle_complete.png`}); await click(t.coach);break;}
   if(t.advance==='tap') {await click(t.coach);continue;}
   if(t.advance==='rolled') {await page.waitForTimeout(500);continue;}
   if(t.advance==='nudged') {
    // Trigger help using two refused clicks, then resize with the offer up.
    await click(t.cards.engineer); await click(t.cards.engineer);
    await frame.waitForFunction(()=>{window.__tut_refresh();return window.__tut.assist;},null,{timeout:25000});
    await page.setViewportSize({width:1440,height:900});await page.waitForTimeout(400);
    t=await state(); assert(t.assist,'assist survives resize');
    await page.screenshot({path:`${out}/nudge_assist.png`});
    await click(t.coach);await page.waitForTimeout(400);
    assert.equal((await state()).advance,'assigned','assist actually performs Nudge');
    usedAssist=true;sawNudge=true;continue;
   }
   if(t.advance==='assigned') {
    await click(t.cards[t.hero]); t=await state();
    await click(t.target_hero ? t.cards[t.target_hero] : t.enemies[0]);continue;
   }
   if(t.advance==='roll_pressed' || (t.advance==='turn_resolved' && t.phase==='ready_to_end')) {await click(t.roll_button);continue;}
   if(t.free) {
    if(t.phase==='await_roll' && t.roll_button[2]>0) await click(t.roll_button);
    else if(t.pending?.length) {
     const hero=Object.keys(t.state_ids).find(k=>t.state_ids[k]===t.pending[0]);
     await click(t.cards[hero]);t=await state();await click(hero==='medic'?t.cards.combat:t.enemies[0]);
    } else if(t.phase==='ready_to_end') await click(t.roll_button);
   }
   await page.waitForTimeout(350);
  }
  assert(finished && usedAssist && sawNudge,'real-input core tutorial reaches victory including assistance');
  console.log('[DESKTOP_WEB] core tutorial completed through actual mouse input');
  await context.close();
 }
 assert.deepEqual(failures,[],'no runtime browser/script errors');
 fs.writeFileSync(`${out}/console.log`,log.join('\n'));
 console.log('[DESKTOP_WEB] PASS — desktop sizes, DPR, iframe, fullscreen, resize, inspection and tutorial');
})().catch(async e=>{console.error(e);process.exitCode=1;if(activePage&&!activePage.isClosed())await activePage.screenshot({path:`${out}/failure.png`});}).finally(async()=>{fs.writeFileSync(`${out}/console.log`,log.join('\n'));await browser?.close();});
