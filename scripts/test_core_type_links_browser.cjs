/* Cross-repository test against actual generated sites, never a Core stub.
 * CORE_DOC_URL can select a served Phase 1 artifact before Core is published.
 * Without it this tests the published Core API browser. */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const geometry = process.env.DOC_URL || 'http://127.0.0.1:18762/';
const published = 'https://zackboll.github.io/opencv_core_ada/';
const core = process.env.CORE_DOC_URL;
const evidence = process.env.DOC_EVIDENCE || '/tmp/core-geometry-xlink';
fs.mkdirSync(evidence, {recursive: true});
(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROME || '/usr/bin/google-chrome', headless: true});
  try {
    for (const width of [1280, 390]) {
      const context = await browser.newContext({viewport: {width, height: 900}});
      await context.route('**/favicon.ico', route => route.fulfill({status: 204}));
      if (core) await context.route(published + '**', async route => {
        const url = route.request().url().replace(published, core);
        const response = await context.request.get(url);
        await route.fulfill({response});
      });
      const page = await context.newPage();
      page.setDefaultTimeout(15000);
      page.setDefaultNavigationTimeout(15000);
      const errors = [];
      const events = [];
      let phase = 'initial';
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => {
        if (m.type() === 'error') errors.push(m.text());
        if (m.text().startsWith('XLINK ')) events.push({phase, data: JSON.parse(m.text().slice(6))});
      });
      if (process.env.DOC_TRACE) await context.addInitScript(() => {
        const snapshot = event => console.info('XLINK ' + JSON.stringify({
          event, url: location.href, state: history.state,
          restoration: history.scrollRestoration, scrollY, height: innerHeight,
          target: document.querySelector(':target')?.id,
          rect: document.querySelector(':target')?.getBoundingClientRect().toJSON()
        }));
        for (const name of ['DOMContentLoaded', 'load', 'pageshow', 'popstate', 'hashchange'])
          addEventListener(name, event => {
            snapshot(name + (event.persisted ? ':persisted' : ''));
            requestAnimationFrame(() => snapshot(name + ':animation-frame'));
          });
      });
      const expectSymbol = async (symbol) => {
        try {
          const frame = page.frameLocator('iframe[name="document-content"]');
          const simple = symbol.slice(symbol.lastIndexOf('.') + 1);
          await frame.locator('h4:target', {hasText: new RegExp(`^${simple}$`)}).waitFor();
          assert.equal(new URL(page.url()).searchParams.get('symbol'), symbol);
          assert.match(await frame.locator('h4:target + pre').textContent(),
            new RegExp(`^type ${simple}\\b`));
          await page.frame({name: 'document-content'}).waitForFunction(() => {
            const r = document.querySelector('h4:target')?.getBoundingClientRect();
            if (!r) return false;
            return r.top >= 0 && r.top < innerHeight;
          });
          assert.equal(page.frames().length, 2, 'Core must not nest inside Geometry');
        } catch (error) {
          const frames = [];
          for (const frame of page.frames()) frames.push(await frame.evaluate(() => ({
            url: location.href, state: history.state, length: history.length,
            restoration: history.scrollRestoration, scrollX, scrollY,
            width: innerWidth, height: innerHeight,
            target: document.querySelector(':target')?.id,
            rect: document.querySelector(':target')?.getBoundingClientRect().toJSON()
          })));
          const name = path.join(evidence, `${width}-${symbol}-${phase}`);
          fs.writeFileSync(name + '.json', JSON.stringify({phase, frames, errors, events}, null, 2));
          await page.screenshot({path: name + '.png'});
          console.error(JSON.stringify({phase, frames, errors}, null, 2));
          throw error;
        }
      };
      // The current Geometry API does not reference OpenCV.Size. Its exact
      // link identity is covered by the linker fixture and direct Core test.
      for (const symbol of ['OpenCV.Rect', 'OpenCV.Angle_Unit', 'OpenCV.Core.Mat']) {
        console.log(`Checking ${width}px ${symbol}`);
        await page.goto(new URL('api/index.html?package=OpenCV.Geometry', geometry).href);
        const frame = page.frameLocator('iframe[name="document-content"]');
        const link = frame.locator(`a.type-reference[data-type="${symbol.toLowerCase()}"]`).first();
        await link.waitFor();
        assert.equal(await link.getAttribute('href'), published + 'api/index.html?symbol=' + symbol);
        assert.equal(await link.getAttribute('target'), '_top');
        phase = 'cross-origin-click';
        await link.click();
        await expectSymbol(symbol);
        phase = 'reload';
        await page.reload();
        await expectSymbol(symbol);
        const bookmark = page.url();
        await page.getByRole('link', {name: 'OpenCV.Core.Sparse', exact: true}).click();
        await page.frameLocator('iframe').locator('h1', {hasText: /^OpenCV.Core.Sparse$/}).waitFor();
        phase = 'back-to-symbol';
        await page.goBack();
        await expectSymbol(symbol);
        await page.goBack();
        await page.waitForURL(url => url.origin === new URL(geometry).origin);
        await frame.locator(`a[data-type="${symbol.toLowerCase()}"]`).first().waitFor();
        phase = 'cross-origin-forward';
        await page.goForward();
        await expectSymbol(symbol);
        await page.screenshot({path: path.join(evidence, `${width}-${symbol}-forward.png`)});
        const fresh = await context.newPage();
        try {
          await fresh.goto(bookmark);
          const simple = symbol.slice(symbol.lastIndexOf('.') + 1);
          await fresh.frameLocator('iframe').locator('h4:target', {hasText: new RegExp(`^${simple}$`)}).waitFor();
          await fresh.frame({name: 'document-content'}).waitForFunction(() => {
            const r = document.querySelector('h4:target')?.getBoundingClientRect();
            return r && r.top >= 0 && r.top < innerHeight;
          });
        } finally { await fresh.close(); }
      }
      await page.goto(published + 'api/index.html?symbol=OpenCV.Size');
      await expectSymbol('OpenCV.Size');
      await page.reload();
      await expectSymbol('OpenCV.Size');
      assert.deepEqual(errors, []);
      if (process.env.DOC_TRACE) fs.writeFileSync(path.join(evidence, `${width}-events.json`),
        JSON.stringify(events, null, 2));
      await context.close();
      console.log(`PASS ${width}px Geometry -> real Core declarations/reload/back/forward`);
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });