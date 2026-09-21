// Branded web loader regression (run after a Web export; see web/shell.html).
//   node scripts/debug/web_loader_test.cjs
// Serves build/web itself, then per viewport checks: the Overload loader is
// up from first paint (dark page, pulsing O, no stock Godot splash), real
// byte progress drives the bar (throttled first run), the loader clears
// once the engine starts, and the canvas still fills whatever viewport /
// iframe it is given (the adaptive sizing is not wrapped or letterboxed).
// PLAYWRIGHT_MODULE can point to an installed Playwright package.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || '../../debug_artifacts/browser-tools/node_modules/playwright');
const {spawn}=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');

const root=path.resolve(__dirname,'../..');
const port=Number(process.env.WEB_LOADER_PORT || 8147);
const base=`http://127.0.0.1:${port}`;
const out=process.env.WEB_TEST_OUTPUT || path.join(root,'debug_artifacts/web_loader');
fs.mkdirSync(out,{recursive:true});

// name, page viewport, optional fixed iframe size (null = direct page / responsive frame).
const CASES=[
 {name:'desktop_throttled', viewport:{width:1366,height:768}, dpr:1, frame:null, throttle:true},
 {name:'itch_fixed_540x960', viewport:{width:1280,height:1040}, dpr:1, frame:{w:540,h:960}},
 {name:'mobile_390x844', viewport:{width:390,height:844}, dpr:3, frame:null, mobile:true},
 {name:'itch_responsive_1280x720', viewport:{width:1280,height:720}, dpr:2, frame:'responsive'},
];

function embedHtml(frame) {
 const size=frame==='responsive' ? 'width:100%;height:calc(100% - 30px)' : `width:${frame.w}px;height:${frame.h}px`;
 return `<!doctype html><style>html,body{margin:0;height:100%;background:#2a2731}header{height:30px}`+
  `iframe{display:block;border:0;margin:0 auto;${size}}</style><header></header>`+
  `<iframe src="${base}/index.html" allowfullscreen scrolling="no"></iframe>`;
}

const failures=[];
function check(ok,msg){ if(!ok) failures.push(msg); console.log(`${ok?'  ok  ':'  FAIL'} ${msg}`); }

(async()=>{
 const server=spawn('python',['-m','http.server',String(port),'--bind','127.0.0.1','--directory',path.join(root,'build/web')],{stdio:'ignore'});
 await new Promise(r=>setTimeout(r,800));
 const browser=await chromium.launch({channel:process.env.WEB_TEST_CHANNEL || 'chrome',headless:true});
 try {
  for(const c of CASES) {
   console.log(`-- ${c.name}`);
   const context=await browser.newContext({viewport:c.viewport,deviceScaleFactor:c.dpr,isMobile:!!c.mobile,hasTouch:!!c.mobile});
   const page=await context.newPage();
   // Every run downloads uncached at a capped rate so the loader is really
   // observed before the engine starts (a cached local load can beat the
   // first check). ~16 MB/s on the watched run: the ~100 MB engine + pack
   // takes several seconds; ~50 MB/s elsewhere.
   const cdp=await context.newCDPSession(page);
   await cdp.send('Network.enable');
   await cdp.send('Network.emulateNetworkConditions',{offline:false,latency:20,downloadThroughput:c.throttle?16e6:50e6,uploadThroughput:4e6});
   await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
   if(c.frame) await page.route('**/_embed',route=>route.fulfill({contentType:'text/html',body:embedHtml(c.frame)}));
   await page.goto(c.frame ? base+'/_embed' : base+'/index.html',{waitUntil:'commit'});
   let frame=page.mainFrame();
   if(c.frame) {
    await page.waitForSelector('iframe');
    frame=await (await page.$('iframe')).contentFrame();
   }
   await frame.waitForSelector('#op-loader',{state:'attached',timeout:15000});
   // First paint: dark page, loader up, no stock splash / progress element.
   const first=await frame.evaluate(()=>{
    const cs=getComputedStyle;
    return {html:cs(document.documentElement).backgroundColor, body:cs(document.body).backgroundColor,
     loaderBg:cs(document.getElementById('op-loader')).backgroundColor,
     loaderVisible:cs(document.getElementById('op-loader')).opacity==='1',
     stock:!!document.querySelector('#status-splash,#status-progress,progress'),
     title:document.getElementById('op-title').textContent+' '+document.getElementById('op-sub').textContent,
     status:document.getElementById('op-status').textContent};
   });
   const dark='rgb(7, 9, 11)';
   check(first.html===dark && first.body===dark && first.loaderBg===dark, `page is ${dark} from first paint (html ${first.html}, body ${first.body})`);
   check(first.loaderVisible, 'branded loader visible before the engine starts');
   check(!first.stock, 'no stock Godot splash image / progress element');
   check(first.title==='OVERLOAD PROTOCOL' && first.status==='INITIALIZING OPERATION...', `copy: "${first.title}" / "${first.status}"`);
   await frame.waitForFunction(()=>document.fonts.status==='loaded',null,{timeout:10000}).catch(()=>{});
   await page.screenshot({path:path.join(out,`loader_${c.name}.png`)});
   // Pulse: the O's core layer animates between ~0.35 and 1.0. Sampled on the
   // slow run, where the loader is guaranteed to outlive 2 s of samples.
   if(c.throttle) {
   const pulse=await frame.evaluate(async()=>{
    const core=document.getElementById('op-core'); const s=[];
    for(let i=0;i<10;i++){ s.push(+getComputedStyle(core).opacity); await new Promise(r=>setTimeout(r,220)); }
    return {min:Math.min(...s),max:Math.max(...s),anim:getComputedStyle(core).animationName,
     ring:getComputedStyle(document.getElementById('op-ring')).backgroundImage.startsWith('url("data:image/png'),
     font:document.fonts.check('20px m5x7-loader')};
   });
   check(pulse.anim==='op-pulse' && pulse.max-pulse.min>0.3, `O core pulses (opacity ${pulse.min.toFixed(2)}..${pulse.max.toFixed(2)})`);
   check(pulse.ring, 'O ring art is the inlined game asset');
   check(pulse.font, 'loader text uses the game font (m5x7 subset)');
   }
   // Watch until the loader is removed; record real progress.
   const t0=Date.now(); const widths=new Set(); let state='visible';
   while(Date.now()-t0<120000) {
    const s=await frame.evaluate(()=>{const l=document.getElementById('op-loader');
     if(!l) return {state:'removed'};
     const bar=document.getElementById('op-bar');
     return {state:l.classList.contains('op-done')?'fading':'visible', bar:bar.style.visibility==='visible'?document.getElementById('op-bar-fill').style.width:null};
    });
    state=s.state; if(s.bar) widths.add(s.bar);
    if(state==='removed') break;
    await page.waitForTimeout(100);
   }
   const secs=((Date.now()-t0)/1000).toFixed(1);
   check(state==='removed', `loader cleared after engine start (${secs}s)`);
   if(c.throttle) {
    const pcts=[...widths].map(parseFloat).sort((a,b)=>a-b);
    check(pcts.length>=3 && pcts[0]<50 && pcts[pcts.length-1]>=99, `progress bar tracks real bytes (${pcts.length} steps, ${pcts[0]}% .. ${pcts[pcts.length-1]}%)`);
   }
   // Canvas fills the viewport / iframe it was given (adaptive resize intact).
   await page.waitForTimeout(1500);
   const geo=await frame.evaluate(()=>{const cv=document.getElementById('canvas');const r=cv.getBoundingClientRect();
    return {cw:r.width,ch:r.height,iw:innerWidth,ih:innerHeight,bw:cv.width,bh:cv.height,dpr:devicePixelRatio};});
   check(Math.abs(geo.cw-geo.iw)<=1 && Math.abs(geo.ch-geo.ih)<=1,
    `canvas fills its viewport: ${geo.cw}x${geo.ch} css in ${geo.iw}x${geo.ih} (backing ${geo.bw}x${geo.bh} @${geo.dpr}x)`);
   if(c.frame && c.frame!=='responsive') check(geo.iw===c.frame.w && geo.ih===c.frame.h, `iframe viewport is exactly ${c.frame.w}x${c.frame.h}`);
   await page.screenshot({path:path.join(out,`game_${c.name}.png`)});
   await context.close();
  }
 } finally {
  await browser.close();
  server.kill();
 }
 console.log(failures.length ? `\nFAIL: ${failures.length} check(s)\n - ${failures.join('\n - ')}` : '\nPASS: web loader');
 process.exit(failures.length ? 1 : 0);
})().catch(e=>{console.error(e);process.exit(1);});
