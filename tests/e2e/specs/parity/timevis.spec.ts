import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-timevis', async (page) => {
  await expect(page.locator('#o_window')).toHaveText('window=2024-01-01');
  await expect(page.locator('#tl .vis-item.vis-range', { hasText: 'Beta' })).toBeVisible();
});
