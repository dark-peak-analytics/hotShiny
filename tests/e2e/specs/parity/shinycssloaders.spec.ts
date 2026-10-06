import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinycssloaders', async (page) => {
  await expect(page.locator('#plot img')).toBeVisible();
  await expect(page.locator('#tbl table')).toBeVisible();
});
