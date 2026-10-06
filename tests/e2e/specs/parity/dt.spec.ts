import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-dt', async (page) => {
  await expect(page.locator('#client table.dataTable tbody tr')).toHaveCount(5);
  await expect(page.locator('#server table.dataTable tbody tr')).toHaveCount(5);
  await expect(page.locator('#edit table.dataTable tbody tr')).toHaveCount(4);
});
