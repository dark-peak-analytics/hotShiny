import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-highcharter', async (page) => {
  await expect(page.locator('#hc .highcharts-series-group .highcharts-series-0 .highcharts-point')).toHaveCount(3);
});
