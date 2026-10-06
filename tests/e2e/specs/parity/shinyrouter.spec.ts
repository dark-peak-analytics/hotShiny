import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinyrouter', async (page) => {
  await expect(page.locator('#o_home')).toHaveText('home output');
});
