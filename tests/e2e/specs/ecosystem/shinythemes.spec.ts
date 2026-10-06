import { test, expect, Page } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinythemes' });

const css = (page: Page, sel: string, prop: string) =>
  page.evaluate(([s, p]) => getComputedStyle(document.querySelector(s)!).getPropertyValue(p), [sel, prop]);

test.describe('shinythemes', () => {
  test('flatly stylesheet is loaded and styles the page', async ({ open }) => {
    const page = await open();
    await expect(page.locator('link[href*="shinythemes/css/flatly.min.css"]')).toHaveCount(1);
    expect(await css(page, '.navbar', 'background-color')).toBe('rgb(44, 62, 80)');
    expect(await css(page, '#go', 'background-color')).toBe('rgb(44, 62, 80)');
    expect(await css(page, 'body', 'font-family')).toMatch(/Lato/);
    await expect(page.locator('#summary')).toHaveText('n=40 col=steelblue go=0 tab=Inputs');
    await expect(page.locator('#tbl table')).toHaveClass(/table/);
  });

  test('navbar tabs and menu switch panels, inputs still work', async ({ open }) => {
    const page = await open();
    await page.click('#go');
    await page.locator('#col + .selectize-control .selectize-input').click();
    await page.locator('#col + .selectize-control .option[data-value="tomato"]').click();
    await expect(page.locator('#summary')).toHaveText('n=40 col=tomato go=1 tab=Inputs');
    await page.locator('.navbar a[data-value="about"]').click();
    await expect(page.getByRole('heading', { name: 'About tab' })).toBeVisible();
    expect(await css(page, '.text-success', 'color')).toBe('rgb(24, 188, 156)');
    await page.locator('.navbar .dropdown-toggle').click();
    await page.locator('.navbar a[data-value="Sub B"]').click();
    await expect(page.getByText('Sub B content')).toBeVisible();
    await expect(page.getByText('About tab')).toBeHidden();
    await page.locator('.navbar a[data-value="Inputs"]').click();
    await expect(page.locator('#summary')).toHaveText('n=40 col=tomato go=1 tab=Inputs');
  });

  test('themeSelector swaps the stylesheet in the browser', async ({ open }) => {
    const page = await open();
    await page.locator('#shinytheme-selector').selectOption('darkly');
    await expect(page.locator('link[href*="shinythemes/css/darkly.min.css"]').first()).toBeAttached();
    await expect.poll(() => css(page, 'body', 'background-color')).toBe('rgb(34, 34, 34)');
    await page.locator('#shinytheme-selector').selectOption('default');
    await expect.poll(() => css(page, 'body', 'background-color')).toBe('rgb(255, 255, 255)');
    await expect.poll(() => css(page, '.navbar', 'background-color')).toBe('rgb(248, 248, 248)');
  });
});
