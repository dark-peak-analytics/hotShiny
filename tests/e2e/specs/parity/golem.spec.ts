import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-golem', async (page) => {
  await expect(page.locator('#server_opts')).not.toBeEmpty();
  await expect(page.locator('body')).toHaveAttribute('data-golem-script', 'loaded');
});
