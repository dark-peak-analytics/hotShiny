import { test, expect, Page } from '../../helpers/fixtures';

test.use({ fixture: 'eco-thematic' });

/** RGB of a pixel of the rendered plot image (a corner: plot background). */
const plotPixel = (page: Page, x = 2, y = 2) =>
  page.evaluate(async ([x, y]) => {
    const img = document.querySelector('#plot img') as HTMLImageElement;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.naturalWidth;
    c.height = img.naturalHeight;
    const ctx = c.getContext('2d')!;
    ctx.drawImage(img, 0, 0);
    return Array.from(ctx.getImageData(x, y, 1, 1).data).slice(0, 3).join(',');
  }, [x, y]);

const plotSrc = (page: Page) => page.locator('#plot img').getAttribute('src');

test.describe('thematic', () => {
  test('plot background and colours follow the bslib theme', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#info')).toHaveText('n=50 bg=#1D1F21 fg=#B4B7B6');
    await expect(page.locator('#plot img')).toHaveAttribute('src', /^data:image\/png/);
    expect(await plotPixel(page)).toBe('29,31,33');
  });

  test('switching the theme at runtime re-renders the plot with the new background', async ({ open }) => {
    const page = await open();
    expect(await plotPixel(page)).toBe('29,31,33');
    const before = await plotSrc(page);
    await page.locator('label[for="light"]').click();
    await expect.poll(() => page.evaluate(() => getComputedStyle(document.body).backgroundColor))
      .toBe('rgb(255, 255, 255)');
    await expect(page.locator('#info')).toHaveText('n=50 bg=#FFFFFF fg=#383838');
    await expect.poll(async () => (await plotSrc(page)) !== before).toBe(true);
    await expect.poll(() => plotPixel(page)).toBe('255,255,255');
    await page.locator('label[for="light"]').click();
    await expect.poll(() => plotPixel(page)).toBe('29,31,33');
  });

  test('plot still re-renders on input changes under thematic', async ({ open }) => {
    const page = await open();
    const before = await plotSrc(page);
    await page.evaluate(() => (window as any).Shiny.setInputValue('n', 120));
    await expect(page.locator('#info')).toHaveText(/^n=120 /);
    await expect.poll(async () => (await plotSrc(page)) !== before).toBe(true);
    expect(await plotPixel(page)).toBe('29,31,33');
  });
});
