import { parityTest } from '../../helpers/parity';
import { waitForIdle } from '../../helpers/fixtures';

parityTest('eco-shinybusy', async (page) => {
  // nanobar keeps one finished (zero-height) bar per busy/idle cycle; how many
  // cycles startup takes is timing-dependent even within plain shiny. Wait
  // until no bar is running for a while, then drop the finished ones.
  const finished = () => page.waitForFunction(() => {
    const bars = Array.from(document.querySelectorAll('.nanobar .bar')) as HTMLElement[];
    return bars.slice(0, -1).every((b) => b.style.height === '0px');
  });
  const count = () => page.locator('.nanobar .bar').count();
  for (let n = -1; n !== (await count()); ) {
    n = await count();
    await waitForIdle(page);
    await finished();
    await page.waitForTimeout(750);
  }
  await page.evaluate(() => {
    document.querySelectorAll('.nanobar .bar[style*="height: 0px"]').forEach((el) => el.remove());
  });
});
