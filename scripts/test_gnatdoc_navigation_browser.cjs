/* Optional real-browser qualification of the Geometry package- and
 * operation-level API browser, adapted from opencv_imgproc_ada. Set
 * PLAYWRIGHT_MODULE to a separately installed Playwright module and serve
 * _site over HTTP; this is not a documentation runtime dependency.
 *
 *   python3 -m http.server 8073 --bind 127.0.0.1 --directory _site
 *   PLAYWRIGHT_MODULE=/path/to/node_modules/playwright DOC_URL=http://127.0.0.1:8073/ \
 *     node scripts/test_gnatdoc_navigation_browser.cjs
 */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const root = process.env.DOC_URL || 'http://127.0.0.1:8073/';
const base = root + 'api/index.html';
const evidence = process.env.DOC_EVIDENCE ||
  path.join(os.tmpdir(), 'geometry-doc-004-screenshots');
const chrome = process.env.CHROME || '/usr/bin/google-chrome';
fs.mkdirSync(evidence, {recursive: true});

const visible = page => page.locator('#api-browser li[data-op]:not([hidden]) > a');
const names = async page => (await visible(page).evaluateAll(
  links => links.map(a => a.parentElement.dataset.op)));

async function packageShown(page, name) {
  await page.frameLocator('iframe').locator('h1',
    {hasText: new RegExp('^' + name.replace(/\./g, '\\.') + '$')}).waitFor();
}

async function expectDeclaration(page, name, packageName) {
  const content = page.frame({name: 'document-content'});
  await content.waitForFunction(() => location.hash.length > 1);
  await content.waitForFunction(
    expected => document.querySelector(':target')?.textContent === expected, name);
  assert.equal(await content.evaluate(() => document.querySelector('h1').textContent),
               packageName);
  const current = page.locator('#api-browser a[aria-current="page"]');
  assert.equal(await current.count(), 1);
  assert.equal(await current.evaluate(a => a.parentElement.dataset.op), name);
  assert.equal(await current.evaluate(a => a.parentElement.dataset.package), packageName);
}

(async () => {
  const browser = await chromium.launch({executablePath: chrome, headless: true});
  try {
    for (const width of [1280, 390]) for (const colorScheme of ['light', 'dark']) {
      const label = `${width}-${colorScheme}`;
      const context = await browser.newContext({viewport: {width, height: 900}, colorScheme});
      await context.route('**/favicon.ico', route => route.fulfill({status: 204}));
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

      // Default: the first package page loads; every declaration is listed once.
      await page.goto(base);
      await packageShown(page, 'OpenCV.Geometry');
      assert.equal(await page.locator('#api-browser li[data-op]').count(), 130);
      assert.equal(await page.locator('#api-browser section[data-package]').count(), 2);
      assert.equal(await page.locator('#api-browser details').count(), 12);
      assert.notEqual(await page.evaluate(() => document.activeElement.id), 'api-search');
      const search = page.getByLabel('Search packages, operations and types');

      // Case-insensitive identifier, word, package and category searches.
      for (const [query, expected] of [
        ['cOnVeX_hUlL', 'Convex_Hull'], ['voronoi', 'Voronoi_Facets'],
        ['subdiv2d insert', 'Insert'], ['fit ellipse', 'Fit_Ellipse'],
        ['perspective', 'Get_Perspective_Transform'], ['nearest', 'Find_Nearest'],
        ['moments', 'Compute_Moments'], ['intersection', 'Intersect_Convex_Polygons'],
        ['native capability', 'Is_Natively_Supported']]) {
        await search.fill(query);
        const found = await names(page);
        assert.ok(found.includes(expected), `${query}: ${expected} missing`);
        for (const entry of await page.locator('#api-browser li[data-op]:not([hidden])')
                 .evaluateAll(items => items.map(li => li.dataset.search))) {
          for (const word of query.toLowerCase().split(/\s+/)) assert.ok(entry.includes(word));
        }
        assert.match(await page.locator('#api-results').textContent(), /matching declaration/);
      }
      // A search confined to one package hides the other package section.
      await search.fill('voronoi_facets');
      assert.equal(await page.locator('#api-browser section[data-package="OpenCV.Geometry"]')
        .isHidden(), true);
      // Overloads are distinguished.
      await search.fill('convex_hull_indices');
      const overloads = await page.locator(
        '#api-browser li[data-op="Convex_Hull_Indices"] .entry-detail').allTextContents();
      assert.deepEqual(overloads.map(s => s.trim()),
                       ['function, overload 1 of 2', 'function, overload 2 of 2']);
      await search.fill('NOT_A_GEOMETRY_NAME');
      assert.equal(await page.locator('#api-results').textContent(), 'No matching declarations.');
      assert.equal(await visible(page).count(), 0);
      await page.getByRole('button', {name: 'Clear', exact: true}).click();
      assert.equal(await visible(page).count(), 130);
      assert.equal(await page.evaluate(() => document.activeElement.id), 'api-search');

      // Selection navigates the frame to the native anchor and is bookmarkable,
      // across both package pages.
      await search.fill('convex_hull_indices');
      await page.locator('#api-browser li[data-op="Convex_Hull_Indices"][data-overload="2"] > a')
        .click();
      await expectDeclaration(page, 'Convex_Hull_Indices', 'OpenCV.Geometry');
      const url = new URL(page.url());
      assert.equal(url.searchParams.get('package'), 'OpenCV.Geometry');
      assert.equal(url.searchParams.get('op'), 'Convex_Hull_Indices');
      assert.equal(url.searchParams.get('overload'), '2');
      const bookmark = page.url();
      await search.fill('voronoi_facets');
      await page.locator('#api-browser li[data-op="Voronoi_Facets"][data-overload="1"] > a')
        .click();
      await expectDeclaration(page, 'Voronoi_Facets', 'OpenCV.Geometry.Subdiv2D');
      await page.goBack();
      await expectDeclaration(page, 'Convex_Hull_Indices', 'OpenCV.Geometry');
      assert.equal(page.url(), bookmark);
      await page.goForward();
      await expectDeclaration(page, 'Voronoi_Facets', 'OpenCV.Geometry.Subdiv2D');
      await page.reload();
      await expectDeclaration(page, 'Voronoi_Facets', 'OpenCV.Geometry.Subdiv2D');

      // A package link selects and bookmarks the package page itself.
      await page.locator('#compilation-units + ul a', {hasText: /Subdiv2D$/}).click();
      await packageShown(page, 'OpenCV.Geometry.Subdiv2D');
      assert.equal(new URL(page.url()).search, '?package=OpenCV.Geometry.Subdiv2D');
      assert.equal(await page.locator('#compilation-units + ul a[aria-current="page"]').count(), 1);
      assert.equal(await page.locator('#api-browser a[aria-current="page"]').count(), 0);

      // Fresh context from copied bookmarks, with case-insensitive lookup.
      const fresh = await browser.newContext({viewport: {width, height: 900}, colorScheme});
      const copy = await fresh.newPage();
      await copy.goto(base + '?package=opencv.geometry&op=convex_hull_INDICES&overload=2');
      await expectDeclaration(copy, 'Convex_Hull_Indices', 'OpenCV.Geometry');
      assert.equal(new URL(copy.url()).searchParams.get('op'), 'Convex_Hull_Indices');
      assert.equal(new URL(copy.url()).searchParams.get('package'), 'OpenCV.Geometry');
      await copy.goto(base + '?package=OPENCV.GEOMETRY.SUBDIV2D');
      await packageShown(copy, 'OpenCV.Geometry.Subdiv2D');
      assert.equal(new URL(copy.url()).search, '?package=OpenCV.Geometry.Subdiv2D');
      // Unknown requests, and a real name under the wrong package, select
      // nothing and are removed from the URL.
      for (const request of ['?op=../../etc/passwd', '?package=OpenCV.Geometry&op=Find_Nearest',
                             '?package=https://example.com/']) {
        await copy.goto(base + request);
        await packageShown(copy, 'OpenCV.Geometry');
        assert.equal(new URL(copy.url()).search, '', request);
        assert.equal(await copy.locator('a[aria-current="page"]').count(), 0, request);
      }
      await fresh.close();

      // Keyboard: search, then Tab through Clear, the package heading, the
      // opened category and its entry; Enter selects it.
      await page.goto(base);
      await search.focus();
      await page.keyboard.type('Find_Nearest');
      await page.keyboard.press('Tab');
      assert.equal(await page.evaluate(() => document.activeElement.id), 'api-clear');
      await page.keyboard.press('Tab');
      assert.equal(await page.evaluate(() => document.activeElement.closest('h3') !== null &&
        document.activeElement.textContent), 'OpenCV.Geometry.Subdiv2D');
      await page.keyboard.press('Tab');
      assert.equal(await page.evaluate(() => document.activeElement.tagName), 'SUMMARY');
      await page.keyboard.press('Tab');
      assert.equal(await page.evaluate(() => document.activeElement.closest('li')?.dataset.op),
                   'Find_Nearest');
      assert.notEqual(await page.evaluate(() =>
        getComputedStyle(document.activeElement).outlineStyle), 'none');
      await page.keyboard.press('Enter');
      await expectDeclaration(page, 'Find_Nearest', 'OpenCV.Geometry.Subdiv2D');

      const overflow = await page.evaluate(() =>
        document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
      assert.equal(overflow, false);
      await search.fill('transform');
      await page.screenshot({path: `${evidence}/browser-${label}.png`});
      assert.deepEqual(errors, []);
      await context.close();
    }

    // Without JavaScript the categorized links still navigate the frame.
    const disabled = await browser.newContext({javaScriptEnabled: false});
    const page = await disabled.newPage();
    await page.goto(base);
    assert.equal(await page.locator('#api-search-controls').isHidden(), true);
    await page.locator('#api-browser details[data-category="subdivision-voronoi"] > summary')
      .click();
    await page.locator('#api-browser li[data-op="Voronoi_Facets"] > a').first().click();
    await page.frameLocator('iframe').locator('h4:target', {hasText: 'Voronoi_Facets'}).waitFor();
    await page.locator('#api-browser details[data-category="transforms"] > summary').click();
    await page.locator('#api-browser li[data-op="Transform_Points"] > a').first().click();
    await page.frameLocator('iframe').locator('h4:target', {hasText: 'Transform_Points'})
      .waitFor();
    await page.screenshot({path: `${evidence}/browser-no-javascript.png`});
    await disabled.close();
    console.log(`Navigation browser qualification passed; screenshots in ${evidence}`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
