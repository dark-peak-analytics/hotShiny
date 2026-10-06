import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-bs4dash' });

test.describe('bs4Dash', () => {
  test('value box and dynamic box re-render with server state', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#vbox .inner')).toHaveText(/^\s*0\s*Clicks\s*$/);
    await expect(page.locator('#vbox .small-box')).toHaveClass(/bg-info/);
    await expect(page.locator('#dyn_box .card-title')).toHaveText('Dynamic box 0');
    await page.click('#inc');
    await page.click('#inc');
    await expect(page.locator('#vbox .inner')).toHaveText(/^\s*2\s*Clicks\s*$/);
    await expect(page.locator('#vbox .small-box')).toHaveClass(/bg-danger/);
    await expect(page.locator('#dyn_box .card-title')).toHaveText('Dynamic box 2');
    await expect(page.locator('#dyn_box')).toContainText('rendered for 2');
  });

  test('box collapse from the client and updateBox() from the server', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#state')).toHaveText(/collapsed=FALSE /);
    await expect(page.locator('#mybox_body')).toBeVisible();
    await page.locator('#mybox [data-card-widget="collapse"]').click();
    await expect(page.locator('#mybox_body')).toBeHidden();
    await expect(page.locator('#state')).toHaveText(/collapsed=TRUE /);
    await page.click('#toggle_box');
    await expect(page.locator('#mybox_body')).toBeVisible();
    await expect(page.locator('#state')).toHaveText(/collapsed=FALSE /);
    await page.click('#retitle');
    await expect(page.locator('#mybox .card-title')).toHaveText('Renamed box');
  });

  test('sidebar menu, updateTabItems() and tabBox switching', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#state')).toHaveText(/^tab=home card=Alpha /);
    await page.locator('#tabcard a[data-value="Beta"]').click();
    await expect(page.locator('#state')).toHaveText(/ card=Beta /);
    await expect(page.getByText('Beta content')).toBeVisible();
    await expect(page.getByText('Alpha content')).toBeHidden();
    await page.locator('.sidebar a[data-value="other"]').click();
    await expect(page.getByRole('heading', { name: 'Other tab' })).toBeVisible();
    await page.locator('.sidebar a[data-value="home"]').click();
    await expect(page.locator('#state')).toHaveText(/^tab=home /);
    await page.click('#goto_other');
    await expect(page.getByRole('heading', { name: 'Other tab' })).toBeVisible();
    await expect(page.locator('.sidebar a[data-value="other"]')).toHaveClass(/active/);
    await expect(page.locator('#shiny-tab-home')).toBeHidden();
  });

  test('dark mode switch toggles the skin and reports input$dark_mode', async ({ open }) => {
    const page = await open();
    await expect(page.locator('body')).not.toHaveClass(/dark-mode/);
    await page.locator('label[for="theme_switch"]').click();
    await expect(page.locator('body')).toHaveClass(/dark-mode/);
    await expect(page.locator('#state')).toHaveText(/ dark=TRUE$/);
    await page.locator('label[for="theme_switch"]').click();
    await expect(page.locator('body')).not.toHaveClass(/dark-mode/);
    await expect(page.locator('#state')).toHaveText(/ dark=FALSE$/);
  });
});
