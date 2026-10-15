import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

// Core fixtures. Ecosystem packages declare their own parity tests next to
// their behaviour specs (specs/parity/<package>.spec.ts).
parityTest('core-inputs');
parityTest('outputs', async (page) => {
  await expect(page.locator('#dyn_value')).toHaveText('dynamic: 3');
  // ion.rangeSlider re-measures its width on a 300ms poll; the page width
  // shifts once the scrollbar appears, so let the dynamic slider redraw.
  await page.waitForTimeout(400);
});
parityTest('reactivity', async (page) => {
  await expect(page.locator('#ticks')).toHaveText('ticking=TRUE');
});
parityTest('dynamic-ui');
parityTest('layouts');
parityTest('bslib');
