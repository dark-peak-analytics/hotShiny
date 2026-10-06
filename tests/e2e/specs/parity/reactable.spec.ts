import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-reactable', async (page) => {
  await expect(page.locator('#tbl .rt-tbody .rt-tr-group')).toHaveCount(5);
  await expect(page.locator('#page')).toHaveText('page: 1');
});
