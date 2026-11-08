/* Adapted from Imgproc's test_shared_production_browser.cjs and
 * probe_released_core_browser.cjs. Real HTTPS, no interception. */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const crypto = require('node:crypto');
const work = path.resolve(process.env.CORE_LINK_WORKSPACE);
const core = JSON.parse(fs.readFileSync(work + '/referenced-types.json'));
const rows = JSON.parse(fs.readFileSync(work + '/occurrences.json'));
const site = work + '/candidate/_site';
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
(async () => {
  const report = {requestInterception: false, profiles: [], failures: []};
  const server = http.createServer((req, res) => {
    const file = path.resolve(site, '.' + new URL(req.url, 'http://localhost').pathname);
    if (!file.startsWith(site + '/') || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404); res.end(); return;
    }
    res.setHeader('Content-Type', {'.html':'text/html', '.js':'text/javascript', '.css':'text/css'}[path.extname(file)] || 'application/json');
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}/api/`;
  const browser = await chromium.launch({executablePath: '/usr/bin/google-chrome', headless: true});
  try {
    for (const width of [1280, 390]) for (const colorScheme of ['light', 'dark']) for (const javaScriptEnabled of [true, false]) {
      const context = await browser.newContext({viewport:{width,height:900}, colorScheme, javaScriptEnabled});
      const page = await context.newPage();
      const errors = []; page.on('pageerror', e => errors.push(e.message));
      const result = {width,colorScheme,javaScriptEnabled,types:[],occurrences:0};
      for (const [identity, type] of Object.entries(core)) {
        const occurrence = rows.find(x => x.identity === identity);
        await page.goto(base + 'index.html');
        await page.locator('#compilation-units + ul a').filter({hasText:new RegExp('^' + occurrence.package.replaceAll('.', '\\.') + '$')}).click();
        const link = page.frameLocator('iframe[name="document-content"]').locator(`a[data-type="${identity}"]`).first();
        assert.equal(await link.getAttribute('target'), '_top');
        await link.focus(); await link.press('Enter'); await page.waitForURL(type.url);
        assert.equal(await page.locator('iframe').count(), 0);
        await page.locator('h4:target').waitFor({state:'visible'});
        assert.equal(await page.locator('h4:target').textContent(), type.identity.split('.').pop());
        assert.equal(await page.locator('h4:target + pre').textContent(), type.native_snippet);
        const response = await page.reload();
        assert.equal(response.status(), 200); assert.equal(response.request().redirectedFrom(), null);
        assert.equal(hash(await response.body()), type.hosted_page_sha256);
        await page.goBack(); await page.waitForURL(url => url.href.startsWith(base));
        await page.goForward(); await page.waitForURL(type.url);
        await page.locator('h4:target').waitFor({state:'visible'});
        const fresh = await context.newPage(); await fresh.goto(type.url);
        await fresh.locator('h4:target').waitFor({state:'visible'}); await fresh.close();
        // Existing incoming Core symbol-only bookmarks are independently retained.
        if (javaScriptEnabled) {
          await page.goto('https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=' + type.identity);
          const frame = page.frameLocator('iframe[name="document-content"]');
          await frame.locator('h4:target').waitFor({state:'visible'});
          assert.equal(await frame.locator('h4:target').textContent(), type.identity.split('.').pop());
          assert.equal(await frame.locator('h4:target + pre').textContent(), type.native_snippet);
        }
        result.types.push(identity);
      }
      // Activate all 104 generated external occurrences, not just representatives.
      const ordinals = new Map();
      for (const row of rows.filter(x => x.href.startsWith('https:'))) {
        await page.goto(base + row.native_page + '#' + row.native_anchor);
        const key = row.native_anchor + ':' + row.identity;
        const ordinal = ordinals.get(key) || 0;
        ordinals.set(key, ordinal + 1);
        const link = page.locator(`h4[id="${row.native_anchor}"] + pre a[data-type="${row.identity}"]`).nth(ordinal);
        assert.equal(await link.getAttribute('href'), core[row.identity].url);
        assert.equal(await link.getAttribute('target'), '_top');
        await link.click(); await page.waitForURL(core[row.identity].url);
        await page.locator('h4:target').waitFor({state:'visible'});
        assert.equal(await page.locator('h4:target + pre').textContent(), core[row.identity].native_snippet);
        result.occurrences++;
      }
      result.localOccurrences = 0;
      for (const nativePage of [...new Set(rows.map(x => x.native_page))]) {
        await page.goto(base + nativePage);
        const links = page.locator('pre a.type-reference:not([href^="https:"])');
        const count = await links.count();
        for (let index = 0; index < count; index++) {
          const link = links.nth(index);
          assert.equal(await link.getAttribute('target'), null);
          const url = new URL(await link.getAttribute('href'), base + nativePage);
          const identity = await link.getAttribute('data-type');
          await link.click();
          await page.waitForURL(url.href);
          assert.equal((await page.locator('h4:target').textContent()).toLowerCase(), identity.split('.').pop());
          result.localOccurrences++;
          // Restore the originating page after child-to-parent navigation.
          if (page.url().split('#')[0] !== base + nativePage) await page.goto(base + nativePage);
        }
      }
      assert.equal(result.localOccurrences, 182);
      await page.goto(base + 'index.html');
      const operations = page.locator('#operation-navigation a');
      const selections = await operations.evaluateAll(es => es.map(e => ({href:e.getAttribute('href'),label:e.textContent})));
      assert.equal(selections.length, 138);
      for (let index = 0; index < selections.length; index++) {
        await operations.nth(index).click();
        const frame = page.frameLocator('iframe[name="document-content"]');
        const anchor = selections[index].href.split('#')[1];
        await frame.locator(`h4[id="${anchor}"]:target`).waitFor({state:'visible'});
        assert.equal(await frame.locator('h4:target').textContent(), selections[index].label.replace(/ \([0-9]+\)$/, ''));
      }
      result.operationSelections = selections.length;
      assert.deepEqual(errors, []); report.profiles.push(result); await context.close();
    }
    report.status = 'pass';
  } catch (e) { report.status = 'fail'; report.failures.push(e.stack); process.exitCode = 1; }
  finally {
    await browser.close(); await new Promise(resolve => server.close(resolve));
    fs.writeFileSync(work + '/focused-browser.json', JSON.stringify(report,null,2) + '\n');
  }
})();