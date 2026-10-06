import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-bslib-navbar', async (page) => {
  await expect(page.locator('#rows')).toHaveText('32');
});
