import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-fresh', async (page) => {
  await expect(page.locator('#txt')).toHaveText('go=0 tab=One');
});
