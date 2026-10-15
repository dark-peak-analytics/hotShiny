import { test, expect, Page } from '../../helpers/fixtures';

test.use({ fixture: 'eco-fresh' });

const css = (page: Page, sel: string, prop: string) =>
  page.evaluate(([s, p]) => getComputedStyle(document.querySelector(s)!).getPropertyValue(p), [sel, prop]);

test.describe('fresh', () => {
  test('create_theme() variables style the page', async ({ open }) => {
    const page = await open();
    expect(await css(page, 'body', 'background-color')).toBe('rgb(253, 246, 227)');
    expect(await css(page, 'body', 'color')).toBe('rgb(7, 54, 66)');
    expect(await css(page, '.navbar', 'background-color')).toBe('rgb(38, 139, 210)');
    expect(await css(page, '#go', 'background-color')).toBe('rgb(211, 54, 130)');
    expect(await css(page, '.well', 'background-color')).toBe('rgb(238, 232, 213)');
  });

  test('dynamic content and tabs pick up the theme', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#txt')).toHaveText('go=0 tab=One');
    await page.click('#add');
    await expect(page.locator('#dyn_btn')).toHaveText('Dynamic 1');
    expect(await css(page, '#dyn_btn', 'background-color')).toBe('rgb(133, 153, 0)');
    await page.click('#go');
    await expect(page.locator('#txt')).toHaveText('go=1 tab=One');
    await page.locator('.navbar a[data-value="two"]').click();
    await expect(page.getByText('Two content')).toBeVisible();
    await page.locator('.navbar a[data-value="One"]').click();
    await expect(page.locator('#txt')).toHaveText('go=1 tab=One');
  });
});
