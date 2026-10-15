import { Page } from '@playwright/test';
import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-highcharter' });

const seriesCount = (page: Page) =>
  page.evaluate(() => {
    const H = (window as any).Highcharts;
    return H.charts.find((c: any) => c && c.renderTo.id === 'hc').series.length;
  });

test.describe('highcharter', () => {
  test('renders and point clicks reach the server', async ({ open }) => {
    const page = await open();
    const bars = page.locator('#hc .highcharts-series-group .highcharts-series-0 .highcharts-point');
    await expect(bars).toHaveCount(3);
    await expect(page.locator('#hc .highcharts-xaxis-labels')).toContainText('a');
    await expect(page.locator('#clicked')).toHaveText('clicked: none');
    await bars.nth(1).click();
    await expect(page.locator('#clicked')).toHaveText('clicked: first x=1 y=6');
    await bars.nth(2).click();
    await expect(page.locator('#clicked')).toHaveText('clicked: first x=2 y=2');
  });

  test('highchartProxy adds a series', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#hc .highcharts-series-group .highcharts-series-0 .highcharts-point')).toHaveCount(3);
    expect(await seriesCount(page)).toBe(1);
    await page.click('#add_series');
    await expect.poll(() => seriesCount(page)).toBe(2);
    await expect(page.locator('#hc .highcharts-series-group .highcharts-series-1 .highcharts-point')).toHaveCount(3);
    await expect(page.locator('#hc .highcharts-legend')).toContainText('second');
    await settle(page);
    await page.locator('#hc .highcharts-series-group .highcharts-series-1 .highcharts-point').nth(0).click();
    await expect(page.locator('#clicked')).toHaveText('clicked: second x=0 y=1');
  });
});
