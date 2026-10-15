import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-rhandsontable', async (page) => {
  await expect(page.locator('#hot .ht_master tbody td').first()).toHaveText('a');
});
