import { Page } from '@playwright/test';
import { test, expect } from '../../helpers/fixtures';

async function pickCyl(page: Page, value: string) {
  await page.locator('#cyl + .selectize-control .selectize-input').click();
  await page.locator(`#cyl + .selectize-control .option[data-value="${value}"]`).click();
}

test.use({ fixture: 'eco-gt' });

test.describe('gt', () => {
  test('render_gt renders the table with header, labels and formatting', async ({ open }) => {
    const page = await open();
    const table = page.locator('#table table.gt_table');
    await expect(table).toBeVisible();
    await expect(page.locator('#table .gt_title')).toHaveText('Motor Trend cars');
    await expect(page.locator('#table .gt_subtitle')).toHaveText('cyl: all');
    await expect(page.locator('#table th.gt_col_heading')).toContainText(['Miles/gallon', 'cyl', 'Horsepower', 'wt']);
    await expect(page.locator('#table tbody tr')).toHaveCount(5);
    await expect(page.locator('#table tbody tr').first().locator('th')).toHaveText('Mazda RX4');
    await expect(page.locator('#table tbody tr').first().locator('td').nth(3)).toHaveText('2.62');
    await expect(page.locator('#table .gt_sourcenote')).toHaveText('Source: mtcars');
    await expect(page.locator('#shown')).toHaveText('rows shown=5');
  });

  test('the table re-renders from inputs', async ({ open }) => {
    const page = await open();
    await pickCyl(page, '6');
    await expect(page.locator('#table .gt_subtitle')).toHaveText('cyl: 6');
    await expect(page.locator('#table tbody tr')).toHaveCount(5);
    await expect(page.locator('#table tbody tr th')).toHaveText(['Mazda RX4', 'Mazda RX4 Wag', 'Hornet 4 Drive', 'Valiant', 'Merc 280']);
    await pickCyl(page, '8');
    await expect(page.locator('#table tbody tr')).toHaveCount(5);
    await page.locator('#rows').evaluate((el) => {
      const $ = (window as any).jQuery;
      $(el).data('ionRangeSlider').update({ from: 2 });
    });
    await expect(page.locator('#table tbody tr')).toHaveCount(2);
    await expect(page.locator('#shown')).toHaveText('rows shown=2');
  });

  test('tab_style highlight toggles', async ({ open }) => {
    const page = await open();
    const heavy = page.locator('#table tbody tr').nth(3).locator('td').first();
    await expect(heavy).not.toHaveCSS('background-color', 'rgb(255, 228, 181)');
    await page.check('#highlight');
    await expect(heavy).toHaveCSS('background-color', 'rgb(255, 228, 181)');
    const light = page.locator('#table tbody tr').first().locator('td').first();
    await expect(light).not.toHaveCSS('background-color', 'rgb(255, 228, 181)');
  });

  test('as_raw_html inside renderUI', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#static_gt table')).toBeVisible();
    await expect(page.locator('#static_gt tbody tr')).toHaveCount(2);
    await expect(page.locator('#static_gt tbody td').nth(1)).toHaveText('x');
  });
});
