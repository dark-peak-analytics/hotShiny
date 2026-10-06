import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-logger', async (page) => {
  await expect(page.locator('#log')).toContainText('Default Shiny inputs initialized');
});
