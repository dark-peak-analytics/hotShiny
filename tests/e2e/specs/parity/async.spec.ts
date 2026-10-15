import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-async', async (page) => {
  await expect(page.locator('#task_status')).toHaveText('status=initial');
});
