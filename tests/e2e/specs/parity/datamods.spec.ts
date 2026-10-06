import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-datamods', async (page) => {
  await expect(page.locator('#import-confirm')).toBeVisible();
});
