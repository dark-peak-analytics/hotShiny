import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-gt', async (page) => {
  await expect(page.locator('#table table.gt_table')).toBeVisible();
  await expect(page.locator('#static_gt table')).toBeVisible();
});
