// Optional browser verification. Use an installed Playwright module, e.g.
// PLAYWRIGHT_MODULE=/path/to/playwright/index.mjs node scripts/verify-site.mjs
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.SURBOX_SITE_URL || 'http://127.0.0.1:8327';
const out = path.resolve('artifacts/publishing', process.env.SURBOX_TEST_LABEL || 'local');
await fs.mkdir(out, { recursive: true });
const browser = await chromium.launch({ headless: true, executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const checks=[]; const errors=[];
try {
  const page=await browser.newPage();
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error') errors.push(m.text())});
  const response=await page.goto(base,{waitUntil:'networkidle'});
  assert.equal(response.status(),200); checks.push('Public page loads without login');
  await assert.doesNotReject(()=>page.getByRole('heading',{name:'A little air. A living sound.'}).waitFor());
  checks.push('Native instrument headline present');
  assert.match(await page.locator('body').innerText(),/download page, not a browser instrument/);checks.push('Native-vs-browser limitation explicit');
  assert.match(await page.locator('body').innerText(),/2020 M1 MacBook Air does not expose that sensor/);checks.push('Unsupported physical lid hardware disclosed');
  for(const width of [1440,768,390,320]) {
    await page.setViewportSize({width,height:900});
    const dims=await page.evaluate(()=>({viewport:innerWidth,content:document.documentElement.scrollWidth}));
    assert.ok(dims.content<=dims.viewport,`Overflow at ${width}`);
    checks.push(`No horizontal overflow at ${width}px`);
    const image=page.locator('.instrument img'); assert.ok(await image.evaluate(i=>i.complete && i.naturalWidth>0));
    await page.locator('.platform-previews').scrollIntoViewIfNeeded();
    await page.waitForFunction(()=>Array.from(document.querySelectorAll('.platform-previews img')).every(i=>i.complete&&i.naturalWidth>0));
    await page.evaluate(()=>window.scrollTo(0,0));
    await page.screenshot({path:path.join(out,`site-${width}.png`),fullPage:true});
  }
  await page.getByText('Why might macOS show a security warning?',{exact:true}).click();
  assert.ok(await page.getByText(/not a Developer ID-signed or notarized release/).isVisible()); checks.push('Interactive installation disclosure works');
  await page.getByText('How do I start playing?',{exact:true}).click();
  assert.ok(await page.locator('kbd').isVisible()); checks.push('Keyboard controls disclosure works');
  const localLinks=await page.locator('a[href]').evaluateAll(links=>links.map(l=>l.getAttribute('href')).filter(h=>h && !h.startsWith('http') && !h.startsWith('#')));
  for(const href of new Set(localLinks)) { const r=await page.request.head(new URL(href,base).href);assert.equal(r.status(),200,href); }
  checks.push('All local docs and Mac/Windows/Android/source downloads return 200');
  const sums=await (await page.request.get(new URL('downloads/SHA256SUMS.txt',base).href)).text();
  for (const filename of ['SurBox-macOS-arm64.zip','SurBox-source.zip','SurBox-Windows-x64.zip','SurBox-Android.apk']) assert.ok(sums.split('\n').some(line=>line.endsWith('  '+filename)&&/^[a-f0-9]{64}  /.test(line)),filename);
  checks.push('All four download checksums published');
  assert.equal(await page.locator('.platform-card').count(),3);checks.push('Three distinct native platform choices visible');
  for(const [platform,ua] of [
    ['windows','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36'],
    ['android','Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 Chrome/130.0.0.0 Mobile Safari/537.36'],
    ['mac','Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36'],
    ['ios','Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1']
  ]) {
    const context=await browser.newContext({userAgent:ua,viewport:{width:390,height:844}});const candidate=await context.newPage();await candidate.goto(base,{waitUntil:'networkidle'});
    if(platform==='ios'){assert.match(await candidate.locator('#platform-hint').innerText(),/no iOS build yet/);assert.equal(await candidate.locator('.recommended').count(),0);}
    else assert.equal(await candidate.locator('.recommended').getAttribute('data-platform'),platform);
    assert.equal(await candidate.locator('.platform-card a[download]').count(),3);
    checks.push(`${platform} browser recommendation is accurate and leaves all downloads available`);await context.close();
  }
  const noScript=await browser.newContext({javaScriptEnabled:false});const staticPage=await noScript.newPage();await staticPage.goto(base);
  assert.equal(await staticPage.locator('.platform-card a[download]').count(),3);checks.push('All platform downloads work without JavaScript');await noScript.close();
  await page.setViewportSize({width:1280,height:900}); await page.goto(base); await page.keyboard.press('Tab');
  assert.equal(await page.locator(':focus').textContent(),'Skip to content'); checks.push('Keyboard skip navigation works');
  assert.deepEqual(errors,[]); checks.push('No browser JavaScript, network or CSP console errors');
  const report=checks.map(c=>'PASS '+c).join('\n')+`\nRESULT ${checks.length} checks, failures=0\n`;
  await fs.writeFile(path.join(out,'results.txt'),report);console.log(report);
} finally { await browser.close(); }
