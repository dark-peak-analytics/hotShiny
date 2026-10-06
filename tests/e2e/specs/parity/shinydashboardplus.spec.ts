import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinydashboardplus', async (page) => {
  await expect(page.locator('#dyn_box .widget-user-username')).toHaveText('User 0');
});
