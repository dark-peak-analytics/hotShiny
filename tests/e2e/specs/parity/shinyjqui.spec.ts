import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-shinyjqui', async (page) => {
  await expect(page.locator('#o_size')).toHaveText('size=200x100');
});
