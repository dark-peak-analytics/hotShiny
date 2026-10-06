import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-bslib-navbar' });

test.describe('bslib page_navbar', () => {
  test('value boxes and card follow the shared sidebar input', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#rows')).toHaveText('32');
    await expect(page.locator('#cols')).toHaveText('11');
    await expect(page.locator('#state')).toHaveText('nav=summary sb=TRUE');
    await page.locator('#dataset + .selectize-control .selectize-input').click();
    await page.locator('#dataset + .selectize-control .option[data-value="iris"]').click();
    await expect(page.locator('#rows')).toHaveText('150');
    await expect(page.locator('#cols')).toHaveText('5');
    await expect(page.locator('#name')).toHaveText('iris');
  });

  test('navbar tabs, nav_menu and nav_select()', async ({ open }) => {
    const page = await open();
    await page.getByRole('tab', { name: 'Plot' }).click();
    await expect(page.locator('#state')).toHaveText(/^nav=plot /);
    await expect(page.locator('#hist img')).toHaveAttribute('src', /^data:image\/png/);
    await page.getByRole('link', { name: 'More' }).click();
    await page.getByRole('tab', { name: 'Notes' }).click();
    await expect(page.getByText('Some notes')).toBeVisible();
    await expect(page.locator('#state')).toHaveText(/^nav=notes /);
    await page.click('#to_table');
    await expect(page.locator('#state')).toHaveText(/^nav=table /);
    await expect(page.locator('#tbl table')).toBeVisible();
    await expect(page.locator('#tbl')).toContainText('21.0');
  });

  test('nav_hide() / nav_show() and the sidebar toggle', async ({ open }) => {
    const page = await open();
    const plotTab = page.getByRole('tab', { name: 'Plot' });
    await expect(plotTab).toBeVisible();
    await page.click('#hide_plot');
    await expect(plotTab).toBeHidden();
    await page.click('#show_plot');
    await expect(plotTab).toBeVisible();
    await page.locator('.bslib-sidebar-layout > .collapse-toggle').click();
    await expect(page.locator('#state')).toHaveText(/ sb=FALSE$/);
  });

  test('card full screen expands and closes', async ({ open }) => {
    const page = await open();
    await page.getByRole('tab', { name: 'Plot' }).click();
    const card = page.locator('.card', { has: page.locator('#hist') });
    await card.hover();
    await card.locator('.bslib-full-screen-enter').click();
    await expect(card).toHaveAttribute('data-full-screen', 'true');
    await page.locator('.bslib-full-screen-exit').click();
    await expect(card).toHaveAttribute('data-full-screen', 'false');
  });
});
