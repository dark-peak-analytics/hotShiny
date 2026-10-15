import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';
import { settle } from '../../helpers/fixtures';

parityTest('eco-visnetwork', async (page) => {
  await page.waitForFunction(() => (document.getElementById('graphnet') as any)?.chart?.body?.data?.nodes?.length === 4);
  // visNetwork sends net_selected / net_initialized after drawing, which
  // recalculates #selected once more; wait for that round trip.
  await page.waitForFunction(() => (window as any).Shiny.shinyapp.$inputValues['net_initialized'] !== undefined);
  await settle(page);
  await expect(page.locator('#selected')).not.toHaveClass(/recalculating/);
});
