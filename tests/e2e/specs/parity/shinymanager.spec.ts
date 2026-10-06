import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

// The login page shinymanager shows before authentication.
parityTest('eco-shinymanager', async (page) => {
  await expect(page.locator('#auth-user_id')).toBeVisible();
});
