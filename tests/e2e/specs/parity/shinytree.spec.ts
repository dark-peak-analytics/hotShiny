import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinytree', async (page) => {
  await expect(page.locator('#tree .jstree-anchor', { hasText: 'Apple' })).toBeVisible();
});
