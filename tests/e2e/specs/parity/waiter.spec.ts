import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-waiter', async (page) => {
  await expect(page.locator('#plot img')).toBeVisible();
});
