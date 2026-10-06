import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinydashboard', async (page) => {
  await expect(page.locator('#count_box .small-box h3')).toHaveText('0');
  await expect(page.locator('#dyn_menu')).toContainText('Dynamic');
});
