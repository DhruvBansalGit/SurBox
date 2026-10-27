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
    await page.screenshot({path:path.join(out,`site-${width}.png`),fullPage:true});
  }
  await page.getByText('Why might macOS show a security warning?',{exact:true}).click();
  assert.ok(await page.getByText(/not a Developer ID-signed or notarized release/).isVisible()); checks.push('Interactive installation disclosure works');
  await page.getByText('How do I start playing?',{exact:true}).click();
  assert.ok(await page.locator('kbd').isVisible()); checks.push('Keyboard controls disclosure works');
  const localLinks=await page.locator('a[href]').evaluateAll(links=>links.map(l=>l.getAttribute('href')).filter(h=>h && !h.startsWith('http') && !h.startsWith('#')));
  for(const href of new Set(localLinks)) { const r=await page.request.head(new URL(href,base).href);assert.equal(r.status(),200,href); }
  checks.push('All local navigation, docs and both ZIP downloads return 200');
  const sums=await (await page.request.get(new URL('downloads/SHA256SUMS.txt',base).href)).text();
  assert.match(sums,/[a-f0-9]{64}  SurBox-macOS-arm64\.zip/); assert.match(sums,/[a-f0-9]{64}  SurBox-source\.zip/);checks.push('Both download checksums published');
  await page.setViewportSize({width:1280,height:900}); await page.goto(base); await page.keyboard.press('Tab');
  assert.equal(await page.locator(':focus').textContent(),'Skip to content'); checks.push('Keyboard skip navigation works');
  assert.deepEqual(errors,[]); checks.push('No browser JavaScript, network or CSP console errors');
  const report=checks.map(c=>'PASS '+c).join('\n')+`\nRESULT ${checks.length} checks, failures=0\n`;
  await fs.writeFile(path.join(out,'results.txt'),report);console.log(report);
} finally { await browser.close(); }
