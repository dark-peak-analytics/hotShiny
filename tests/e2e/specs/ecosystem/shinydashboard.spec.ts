import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinydashboard' });

test.describe('shinydashboard', () => {
  test('renderValueBox / renderInfoBox / renderMenu follow server state', async ({ open }) => {
    const page = await open();
    const count = page.locator('#count_box');
    await expect(count.locator('.small-box h3')).toHaveText('0');
    await expect(count.locator('.small-box')).toHaveClass(/bg-aqua/);
    await expect(page.locator('#info_box .info-box-number')).toHaveText('0');
    await expect(page.locator('#info_box .info-box')).toHaveClass(/bg-/);
    await expect(page.getByText('Static box')).toBeVisible();
    for (let i = 0; i < 3; i++) await page.click('#inc');
    await expect(count.locator('.small-box h3')).toHaveText('3');
    await expect(count.locator('.small-box')).toHaveClass(/bg-red/);
    await expect(page.locator('#info_box .info-box-number')).toHaveText('6');
    await page.locator('#messages .dropdown-toggle').click();
    await expect(page.locator('#messages .dropdown-menu')).toContainText('You clicked 3 times');
  });

  test('sidebar menu switches tab items, updateTabItems() from the server', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#state')).toHaveText('tab=overview collapsed=FALSE');
    await expect(page.locator('#shiny-tab-overview')).toBeVisible();
    await page.locator('.sidebar-menu a[data-value="details"]').click();
    await expect(page.locator('#state')).toHaveText(/^tab=details /);
    await expect(page.getByRole('heading', { name: 'Details tab' })).toBeVisible();
    await expect(page.locator('#details_txt')).toHaveText('details for 0');
    await expect(page.locator('#shiny-tab-overview')).toBeHidden();
    await page.locator('.sidebar-menu a[data-value="overview"]').click();
    await expect(page.locator('#state')).toHaveText(/^tab=overview /);
    await page.click('#goto_details');
    await expect(page.locator('#state')).toHaveText(/^tab=details /);
    await expect(page.getByRole('heading', { name: 'Details tab' })).toBeVisible();
    await expect(page.locator('.sidebar-menu li.active a[data-value="details"]')).toHaveCount(1);
  });

  test('dynamic sidebar menu (renderMenu) gains an item that opens its tab', async ({ open }) => {
    const page = await open();
    const dyn = page.locator('#dyn_menu');
    await expect(dyn.getByText('Dynamic')).toBeVisible();
    await expect(dyn.getByText('Extra')).toHaveCount(0);
    await page.click('#add_item');
    await expect(dyn.getByText('Extra')).toBeVisible();
    await dyn.getByText('Extra').click();
    await expect(page.getByText('Reached the dynamic tab')).toBeVisible();
    await expect(page.locator('#shiny-tab-overview')).toBeHidden();
  });

  test('box collapses and sidebar toggle reports sidebarCollapsed', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#box_body')).toBeVisible();
    await page.locator('#main_box').locator('xpath=..').locator('[data-widget="collapse"]').click();
    await expect(page.locator('#box_body')).toBeHidden();
    await page.locator('#main_box').locator('xpath=..').locator('[data-widget="collapse"]').click();
    await expect(page.locator('#box_body')).toBeVisible();
    await page.locator('.sidebar-toggle').click();
    await expect(page.locator('#state')).toHaveText(/collapsed=TRUE$/);
    await expect(page.locator('body')).toHaveClass(/sidebar-collapse/);
    await page.locator('.sidebar-toggle').click();
    await expect(page.locator('#state')).toHaveText(/collapsed=FALSE$/);
  });
});
