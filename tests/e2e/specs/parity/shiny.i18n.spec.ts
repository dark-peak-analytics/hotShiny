import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shiny.i18n', async (page) => {
  // session start can take longer than settle()'s quiet window
  await expect(page.locator('#server_text')).toHaveText('Server says: Hello');
  await expect(page.locator('#dyn')).toHaveText('Goodbye');
});
