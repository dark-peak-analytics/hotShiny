import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-colourpicker', async (page) => {
  await expect(page.locator('#plot img')).toBeVisible();
});
