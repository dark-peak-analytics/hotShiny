import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinyace', async (page) => {
  await expect(page.locator('#o_ed')).toHaveText('ed=x <- 1');
});
