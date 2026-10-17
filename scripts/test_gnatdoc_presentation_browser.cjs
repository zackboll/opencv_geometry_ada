/* Optional real-browser qualification of the themed, linked and highlighted
 * Geometry site, adapted from opencv_imgproc_ada. Set PLAYWRIGHT_MODULE to a
 * separately installed Playwright module and serve _site over HTTP; this is
 * not a documentation runtime dependency.
 *
 *   python3 -m http.server 8073 --bind 127.0.0.1 --directory _site
 *   PLAYWRIGHT_MODULE=/path/to/node_modules/playwright \
 *     DOC_URL=http://127.0.0.1:8073/ node scripts/test_gnatdoc_presentation_browser.cjs
 */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const root = process.env.DOC_URL || 'http://127.0.0.1:8073/';
const evidence = process.env.DOC_EVIDENCE ||
  path.join(os.tmpdir(), 'geometry-doc-003-screenshots');
const chrome = process.env.CHROME || '/usr/bin/google-chrome';
const core = 'https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=';
fs.mkdirSync(evidence, {recursive: true});

const background = {light: 'rgb(255, 255, 255)', dark: 'rgb(20, 27, 38)'};
const packages = [
  {name: 'OpenCV.Geometry', keywords: 150, core: 70},
  {name: 'OpenCV.Geometry.Subdiv2D', keywords: 60, core: 10},
];

async function noOverflow(target, label) {
  const sizes = await target.evaluate(() => ({
    scroll: document.documentElement.scrollWidth,
    client: document.documentElement.clientWidth}));
  assert.ok(sizes.scroll <= sizes.client + 1,
            `${label}: horizontal overflow ${sizes.scroll} > ${sizes.client}`);
}

async function openPackage(page, name) {
  await page.locator('#compilation-units + ul').getByRole('link', {name, exact: true}).click();
  const content = page.frame({name: 'document-content'});
  await page.frameLocator('iframe[name="document-content"]')
    .locator('h1', {hasText: new RegExp('^' + name.replace(/\./g, '\\.') + '$')})
    .waitFor();
  return content;
}

function snippetOf(content, heading) {
  return content.locator('h4', {hasText: new RegExp('^' + heading + '$')})
    .locator('xpath=following-sibling::pre[1]');
}

(async () => {
  const browser = await chromium.launch({executablePath: chrome, headless: true});
  try {
    for (const width of [1280, 390]) for (const colorScheme of ['light', 'dark']) {
      const label = `${width}-${colorScheme}`;
      const context = await browser.newContext({viewport: {width, height: 900}, colorScheme});
      await context.route('**/favicon.ico', route => route.fulfill({status: 204}));
      await context.route(/^https:\/\/zackboll\.github\.io\//, route => route.fulfill({
        status: 200, contentType: 'text/html', body: '<title>Core stub</title>'}));
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

      await page.goto(root + 'index.html');
      await noOverflow(page, `${label} landing`);
      assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement)
        .backgroundColor), background[colorScheme]);
      await page.getByRole('link', {name: /Generated Ada API reference/}).waitFor();
      await page.screenshot({path: `${evidence}/landing-${label}.png`, fullPage: true});

      for (const spec of packages) {
        await page.goto(root + 'api/index.html');
        const content = await openPackage(page, spec.name);
        await noOverflow(content, `${label} ${spec.name}`);
        assert.equal(await content.evaluate(() => getComputedStyle(document.documentElement)
          .backgroundColor), background[colorScheme]);
        assert.ok(await content.locator('.ada-keyword').count() >= spec.keywords,
                  `${spec.name}: highlighting`);
        // Every Core link carries its exact qualified declaration identity.
        const external = await content.locator('a.type-reference[target="_top"]')
          .evaluateAll(links => links.map(a => ({href: a.getAttribute('href'), identity: a.dataset.type})));
        assert.ok(external.length >= spec.core, `${spec.name}: ${external.length} Core links`);
        for (const {href, identity} of external) {
          assert.ok(href.startsWith(core), href);
          assert.equal(href.slice(core.length).toLowerCase(), identity);
        }
        // Long declarations scroll inside their own block.
        const snippetOverflow = await content.locator('pre.ada-code-snippet').evaluateAll(
          pres => pres.map(p => getComputedStyle(p).overflowX));
        assert.ok(snippetOverflow.every(value => value === 'auto'));
      }

      // An internal type link lands on its native declaration anchor.
      await page.goto(root + 'api/index.html');
      let content = await openPackage(page, 'OpenCV.Geometry');
      const hull = snippetOf(content, 'Convex_Hull').first();
      await hull.scrollIntoViewIfNeeded();
      const local = hull.locator('a.type-reference[href^="#"]').first();
      const localName = await local.textContent();
      const anchor = (await local.getAttribute('href')).slice(1);
      await local.click();
      await content.waitForFunction(id => location.hash === '#' + id, anchor);
      assert.equal(await content.evaluate(() => document.querySelector(':target').textContent),
                   localName);
      await page.screenshot({path: `${evidence}/api-geometry-${label}.png`});

      // Keyboard focus is visible on links inside the documentation frame.
      await content.locator('a.type-reference').first().focus();
      await page.keyboard.press('Tab');
      await page.keyboard.press('Shift+Tab');
      assert.equal(await content.evaluate(() => document.activeElement.className),
                   'type-reference');
      assert.notEqual(await content.evaluate(() =>
        getComputedStyle(document.activeElement).outlineStyle), 'none');

      // A Subdiv2D link to a parent type opens the OpenCV.Geometry page at the
      // native declaration anchor, inside the documentation frame.
      await page.goto(root + 'api/index.html');
      content = await openPackage(page, 'OpenCV.Geometry.Subdiv2D');
      const facet = snippetOf(content, 'Facet_Points').first();
      await facet.scrollIntoViewIfNeeded();
      const cross = facet.locator(
        'a.type-reference[data-type="opencv.geometry.float32_point_array"]').first();
      const crossHref = await cross.getAttribute('href');
      assert.match(crossHref, /^[0-9a-f]{64}\.html#[0-9a-f]+$/);
      await cross.click();
      await content.waitForFunction(() => location.hash.length > 1);
      assert.equal(await content.evaluate(() => document.querySelector('h1').textContent),
                   'OpenCV.Geometry');
      assert.equal(await content.evaluate(() => document.querySelector(':target').textContent),
                   'Float32_Point_Array');
      await page.screenshot({path: `${evidence}/api-subdiv2d-cross-${label}.png`});

      // A Core link replaces the whole window rather than nesting frames.
      await page.goto(root + 'api/index.html');
      content = await openPackage(page, 'OpenCV.Geometry');
      const coreLink = snippetOf(content, 'Get_Rotation_Matrix_2D')
        .locator('a.type-reference[data-type="opencv.core.mat"]').first();
      await Promise.all([page.waitForURL(/opencv_core_ada/), coreLink.click()]);
      assert.equal(new URL(page.url()).searchParams.get('symbol'), 'OpenCV.Core.Mat');
      assert.deepEqual(errors, []);
      await context.close();
    }
    // Native navigation does not need JavaScript.
    const disabled = await browser.newContext({javaScriptEnabled: false});
    const page = await disabled.newPage();
    for (const spec of packages) {
      await page.goto(root + 'api/index.html');
      await page.locator('#compilation-units + ul')
        .getByRole('link', {name: spec.name, exact: true}).click();
      await page.frameLocator('iframe').locator('h1',
        {hasText: new RegExp('^' + spec.name.replace(/\./g, '\\.') + '$')}).waitFor();
    }
    await disabled.close();
    console.log(`Presentation browser qualification passed; screenshots in ${evidence}`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
