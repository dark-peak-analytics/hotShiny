import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-ggiraph', async (page) => {
  await expect(page.locator('#plot svg [data-id]')).toHaveCount(8);
});
