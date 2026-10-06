import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinywidgets', async (page) => {
  await expect(page.locator('#o_vs')).toHaveText('character:red');
  await expect(page.locator('#vs .vscomp-toggle-button')).toBeVisible();
});
parityTest('eco-shinywidgets-modules', async (page) => {
  await expect(page.locator('#o_rows')).toHaveText('rows=5 makes=audi,bmw,fiat');
});
parityTest('eco-shinywidgets-more', async (page) => {
  await expect(page.locator('#o_kn')).toHaveText('integer:30');
});
