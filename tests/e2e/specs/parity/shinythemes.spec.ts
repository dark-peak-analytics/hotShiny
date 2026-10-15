import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinythemes', async (page) => {
  await expect(page.locator('#tbl table')).toBeVisible();
});
