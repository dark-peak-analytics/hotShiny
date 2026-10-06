import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-dygraphs', async (page) => {
  await expect(page.locator('#window')).toHaveText('window: 1974-01 to 1979-12');
});
