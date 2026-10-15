import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-plotly', async (page) => {
  await expect(page.locator('#static .scatterlayer .point')).toHaveCount(5);
  await expect(page.locator('#dyn .barlayer .point')).toHaveCount(4);
});
