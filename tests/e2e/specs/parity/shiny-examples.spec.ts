import { expect, Page } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

// shiny's own example apps, rendered by shiny and by hotShiny. They declare
// "DisplayMode: Showcase", so these also cover showcase mode (code listing,
// README, and the server-driven highlighting of the code that ran).

const plotReady = (id: string) => async (page: Page) => {
  await expect(page.locator(`#${id} img`)).toHaveAttribute('src', /^data:image\/png;base64,/);
};
const tableReady = (id: string) => async (page: Page) => {
  await expect(page.locator(`#${id} table`)).toBeVisible();
};

parityTest('ex-01_hello', plotReady('distPlot'));
parityTest('ex-02_text', tableReady('view'));
parityTest('ex-03_reactivity', tableReady('view'));
parityTest('ex-04_mpg', plotReady('mpgPlot'));
parityTest('ex-05_sliders', tableReady('values'));
// rnorm() at session start: same seed, so both runtimes must draw the same sample.
parityTest('ex-06_tabsets', plotReady('plot'), { seed: 1 });
parityTest('ex-07_widgets', tableReady('view'));
parityTest('ex-09_upload');
parityTest('ex-10_download', tableReady('table'));
parityTest('ex-11_timer', async (page) => {
  const out = page.locator('#currentTime');
  const stamp = /\d{4}-\d\d-\d\d \d\d:\d\d:\d\d(\.\d+)?$/;
  await expect(out).toHaveText(new RegExp('^The current time is ' + stamp.source));
  // Freeze the clock: stop applying server messages (the socket stays open,
  // so the page is not shown as disconnected), then replace the timestamp,
  // whose format was just checked, with a fixed one.
  await page.evaluate(() => {
    (window as any).Shiny.shinyapp.$socket.onmessage = () => {};
  });
  await out.evaluate((el, src) => {
    el.textContent = el.textContent!.replace(new RegExp(src), '2000-01-01 00:00:00');
  }, stamp.source);
});
