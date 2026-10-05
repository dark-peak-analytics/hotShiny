import { test, expect, Page } from '@playwright/test';
import { startApp, RunningApp } from '../../helpers/server';
import { waitForIdle } from '../../helpers/fixtures';
import { normalizedDom, diffScreenshots } from '../../helpers/parity';

// Each fixture is rendered by plain shiny (reference) and by hotShiny; the live
// DOM after shiny.js has initialised, the loaded dependencies, and the pixels
// must match.
const FIXTURES: Record<string, (page: Page) => Promise<void>> = {
  'core-inputs': async () => {},
  outputs: async () => {},
  reactivity: async (page) => {
    await expect(page.locator('#ticks')).toHaveText('ticking=TRUE');
  },
  'dynamic-ui': async () => {},
  layouts: async () => {},
  bslib: async () => {},
};

const MAX_PIXEL_DIFF = 0.002;

for (const [fixture, ready] of Object.entries(FIXTURES)) {
  test.describe(`parity: ${fixture}`, () => {
    let ref: RunningApp;
    let hot: RunningApp;

    test.beforeAll(async () => {
      [ref, hot] = await Promise.all([
        startApp({ runtime: 'shiny', fixture }),
        startApp({ runtime: 'hotshiny', fixture }),
      ]);
    });
    test.afterAll(async () => {
      await Promise.all([ref?.stop(), hot?.stop()]);
    });

    async function load(page: Page, app: RunningApp) {
      await page.goto(app.url);
      await waitForIdle(page);
      await ready(page);
      await waitForIdle(page);
      // Freeze animations/carets so screenshots are deterministic.
      await page.addStyleTag({ content: '*,*::before,*::after{transition:none!important;animation:none!important;caret-color:transparent!important}' });
    }

    test('DOM, dependencies and pixels match shiny', async ({ browser }, testInfo) => {
      const refPage = await (await browser.newContext()).newPage();
      const hotPage = await (await browser.newContext()).newPage();
      await Promise.all([load(refPage, ref), load(hotPage, hot)]);

      const [refDom, hotDom] = await Promise.all([normalizedDom(refPage), normalizedDom(hotPage)]);
      expect.soft(hotDom.head, 'loaded <script>/<link> dependencies').toEqual(refDom.head);
      expect.soft(hotDom.body, 'normalised <body> markup').toBe(refDom.body);

      const [refShot, hotShot] = await Promise.all([
        refPage.screenshot({ fullPage: true }),
        hotPage.screenshot({ fullPage: true }),
      ]);
      const { ratio, diffPng } = diffScreenshots(refShot, hotShot);
      if (ratio > 0) {
        await testInfo.attach('shiny.png', { body: refShot, contentType: 'image/png' });
        await testInfo.attach('hotshiny.png', { body: hotShot, contentType: 'image/png' });
        await testInfo.attach('diff.png', { body: diffPng, contentType: 'image/png' });
      }
      expect.soft(ratio, 'fraction of differing pixels').toBeLessThanOrEqual(MAX_PIXEL_DIFF);
    });
  });
}
