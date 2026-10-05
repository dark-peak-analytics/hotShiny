import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

// Core fixtures. Ecosystem packages declare their own parity tests next to
// their behaviour specs (specs/parity/<package>.spec.ts).
parityTest('core-inputs');
parityTest('outputs');
parityTest('reactivity', async (page) => {
  await expect(page.locator('#ticks')).toHaveText('ticking=TRUE');
});
parityTest('dynamic-ui');
parityTest('layouts');
parityTest('bslib');
