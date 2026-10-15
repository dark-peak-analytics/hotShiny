import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-thematic', async (page) => {
  await expect(page.locator('#plot img')).toHaveAttribute('src', /^data:image\/png/);
  await expect(page.locator('#info')).toHaveText(/bg=#1D1F21/);
});
