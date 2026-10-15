import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-bs4dash', async (page) => {
  await expect(page.locator('#dyn_box .card-title')).toHaveText('Dynamic box 0');
});
