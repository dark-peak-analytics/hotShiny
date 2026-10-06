import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-widgets-dynamic' });

test.describe('htmlwidgets in dynamic UI', () => {
  test('renderUI loads widget dependencies; server-side DT works from a dynamic output', async ({ open }) => {
    const page = await open();
    expect(await page.evaluate(() => typeof (window as any).Dygraph)).toBe('undefined');
    await page.click('#show');
    await expect(page.locator('#dt table.dataTable tbody tr')).toHaveCount(5);
    await expect(page.locator('#dy canvas').first()).toBeVisible();
    expect(await page.evaluate(() => typeof (window as any).Dygraph)).toBe('function');

    const ajax = page.waitForResponse((r) => /dataobj\/dt/.test(r.url()) && r.request().method() === 'POST');
    await page.locator('#dt .paginate_button.next').click();
    expect((await ajax).status()).toBe(200);
    await expect(page.locator('#dt table.dataTable tbody tr').first()).toContainText('Valiant');
    await page.locator('#dt table.dataTable tbody tr').nth(1).click();
    await expect(page.locator('#dt_selected')).toHaveText('dt selected: 7');
  });

  test('insertUI loads widget dependencies and binds each inserted output', async ({ open }) => {
    const page = await open();
    await page.click('#insert');
    await expect(page.locator('#rt1 .rt-tbody .rt-tr-group')).toHaveCount(3);
    await settle(page);
    await page.click('#insert');
    await expect(page.locator('#rt2 .rt-tbody .rt-tr-group')).toHaveCount(3);
    await expect(page.locator('.inserted')).toHaveCount(2);
  });
});
