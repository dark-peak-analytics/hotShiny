import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinydashboardplus' });

test.describe('shinydashboardPlus', () => {
  test('dynamic userBox re-renders with server state', async ({ open }) => {
    const page = await open();
    const dyn = page.locator('#dyn_box');
    await expect(dyn.locator('.widget-user-username')).toHaveText('User 0');
    await expect(dyn.locator('.widget-user-header')).toHaveClass(/bg-green/);
    await page.click('#inc');
    await page.click('#inc');
    await expect(dyn.locator('.widget-user-username')).toHaveText('User 2');
    await expect(dyn.locator('.widget-user-header')).toHaveClass(/bg-red/);
    await expect(page.locator('#dyn_body')).toHaveText('rendered for 2');
  });

  test('box collapse/close from the client and updateBox() from the server', async ({ open }) => {
    const page = await open();
    const box = page.locator('#mybox');
    await expect(page.locator('#state')).toHaveText(/ collapsed=FALSE visible=TRUE /);
    await box.locator('[data-widget="collapse"]').click();
    await expect(page.locator('#mybox_body')).toBeHidden();
    await expect(box).toHaveClass(/collapsed-box/);
    // The box binding reports clicks after a fixed 550ms timer that races the
    // 500ms collapse animation (in shiny too), so read the input back through
    // updateBox(), whose change event has no animation to race.
    await page.click('#retitle');
    await expect(box.locator('.box-title')).toHaveText('Renamed box');
    await expect(page.locator('#state')).toHaveText(/ collapsed=TRUE /);
    await page.click('#toggle_box');
    await expect(page.locator('#mybox_body')).toBeVisible();
    await expect(box).not.toHaveClass(/collapsed-box/);
    await box.locator('[data-widget="remove"]').click();
    await expect(box).toBeHidden();
    await page.click('#restore_box');
    await expect(box).toBeVisible();
    await expect(page.locator('#state')).toHaveText(/ collapsed=FALSE visible=TRUE /);
  });

  test('sidebar menu and updateTabItems() switch tabs', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#state')).toHaveText(/^tab=home /);
    await page.locator('.sidebar-menu a[data-value="other"]').click();
    await expect(page.getByRole('heading', { name: 'Other tab' })).toBeVisible();
    await expect(page.locator('#state')).toHaveText(/^tab=other /);
    await page.locator('.sidebar-menu a[data-value="home"]').click();
    await expect(page.locator('#state')).toHaveText(/^tab=home /);
    await page.click('#goto_other');
    await expect(page.getByRole('heading', { name: 'Other tab' })).toBeVisible();
    await expect(page.locator('.sidebar-menu li.active a[data-value="other"]')).toHaveCount(1);
  });

  test('controlbar opens from the header and from updateControlbar()', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#state')).toHaveText(/ cb=FALSE$/);
    await page.locator('[data-toggle="control-sidebar"]').click();
    await expect(page.locator('#state')).toHaveText(/ cb=TRUE$/);
    await expect(page.locator('aside.control-sidebar')).toHaveClass(/control-sidebar-open/);
    await page.locator('[data-toggle="control-sidebar"]').click();
    await expect(page.locator('#state')).toHaveText(/ cb=FALSE$/);
    await page.click('#toggle_cb');
    await expect(page.locator('#state')).toHaveText(/ cb=TRUE$/);
    await expect(page.locator('aside.control-sidebar')).toHaveClass(/control-sidebar-open/);
  });
});
