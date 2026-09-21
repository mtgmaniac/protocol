const {chromium}=require('../../debug_artifacts/browser-tools/node_modules/playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({channel:process.env.WEB_TEST_CHANNEL||'chrome',headless:true});
 try {
 for(const dpr of [1,2]) {
 const page=await browser.newPage({viewport:{width:1440,height:900},deviceScaleFactor:dpr});
 const errors=[];page.on('console',m=>{if(/SCRIPT ERROR:|ERROR:/.test(m.text())) errors.push(m.text());});
 await page.goto('http://127.0.0.1:8142');await page.waitForTimeout(11000);
 const canvas=page.locator('canvas');const box=await canvas.boundingBox();
 const modalCorner={x:box.x+10,y:box.y+60,width:20,height:20};
 const baselineCorner=await page.screenshot({clip:modalCorner});
 const move=async(x,y)=>{await page.mouse.move(box.x+x*box.width/1080,box.y+y*box.height/2400);await page.waitForTimeout(150);};
 const click=async(x,y)=>{await move(x,y);await page.mouse.click(box.x+x*box.width/1080,box.y+y*box.height/2400);await page.waitForTimeout(400);};
 const cursor=()=>canvas.evaluate(el=>getComputedStyle(el).cursor);
 await move(500,500);const arrow=await cursor();
 await move(890,70);const hover=await cursor();
 assert.match(arrow,/url\(/);assert.match(hover,/url\(/);assert.notEqual(arrow,hover);
 assert.match(arrow,/2 2/);assert.match(hover,/2 2/);
 await click(890,70);await click(380,225);
 await page.screenshot({path:`debug_artifacts/ui_polish/web_units_dpr${dpr}.png`});
 await move(540,1500);const before=await canvas.screenshot();await page.mouse.wheel(0,540);await page.waitForTimeout(500);
 assert(!before.equals(await canvas.screenshot()),'wheel changes visible list');
 await page.keyboard.press('Escape');await page.waitForTimeout(250);
 await click(890,70); // Help reopens on Protocol
 await click(990,225); // small close button, tip hotspot
 assert(baselineCorner.equals(await page.screenshot({clip:modalCorner})),'small close button closes Help');
 await move(500,500);const closed=await canvas.screenshot();
 await page.keyboard.press('Escape');await page.waitForTimeout(200);
 await page.screenshot({path:`debug_artifacts/ui_polish/web_closed_dpr${dpr}.png`});
 assert.deepEqual(errors,[]);
 fs.writeFileSync(`debug_artifacts/ui_polish/cursor_dpr${dpr}.txt`,`${arrow}\n${hover}`);
 console.log(`[HELP_BROWSER] PASS DPR ${dpr}: cursor variants/hotspot, Help buttons, wheel, Escape`);
 await page.close();
 }
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
