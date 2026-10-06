import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-colourpicker' });

test.describe('colourpicker', () => {
  test('initial values', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#o_col')).toHaveText('col=#FF0000');
    await expect(page.locator('#o_col_lim')).toHaveText('lim=#0000FF');
    await expect(page.locator('#o_col_alpha')).toHaveText('alpha=#00FF0080');
    await expect(page.locator('#plot img')).toBeVisible();
  });

  test('typing a colour updates the input and the plot', async ({ open }) => {
    const page = await open();
    const before = await page.locator('#plot img').getAttribute('src');
    await page.locator('#col').click();
    await page.locator('#col').press('ControlOrMeta+a');
    await page.locator('#col').pressSequentially('#00AA00');
    await page.locator('#col').press('Enter');
    await page.locator('h2').click();
    await expect(page.locator('#o_col')).toHaveText('col=#00AA00');
    await expect.poll(() => page.locator('#plot img').getAttribute('src')).not.toBe(before);
  });

  test('picking from a limited palette', async ({ open }) => {
    const page = await open();
    await page.locator('#col_lim').click();
    await page.locator('.colourpicker-panel:visible .cp-list-col[data-cp-col="red" i], .colourpicker-panel:visible [data-cp-col="#FF0000" i]').first().click();
    await expect(page.locator('#o_col_lim')).toHaveText('lim=#FF0000');
  });

  test('updateColourInput', async ({ open }) => {
    const page = await open();
    await page.click('#upd');
    await expect(page.locator('#o_col')).toHaveText('col=#123456');
    await expect(page.locator('#col')).toHaveValue('#123456');
    await expect(page.locator('label[for="col"]')).toHaveText('Relabelled');
    await expect(page.locator('#o_col_lim')).toHaveText('lim=#00FF00');
    await settle(page);
  });
});
