import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-sortable', async (page) => {
  await expect(page.locator('#o_grp')).toHaveText('grp=left:one+two+three;right:');
});
