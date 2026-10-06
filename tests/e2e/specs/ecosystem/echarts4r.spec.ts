import { Page } from '@playwright/test';
import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-echarts4r' });

const chart = (page: Page) =>
  page.waitForFunction(() => {
    const w = window as any;
    const c = w.echarts && w.echarts.getInstanceByDom(document.getElementById('bars'));
    return !!c && c.getOption().series.length > 0;
  });

async function barCentre(page: Page, category: string, value: number) {
  return page.evaluate(
    ({ category, value }) => {
      const el = document.getElementById('bars')!;
      const c = (window as any).echarts.getInstanceByDom(el);
      const [x, y] = c.convertToPixel({ seriesIndex: 0 }, [category, value / 2]);
      const r = el.getBoundingClientRect();
      return { x: r.left + x, y: r.top + y };
    },
    { category, value },
  );
}

const seriesCount = (page: Page) =>
  page.evaluate(() => (window as any).echarts.getInstanceByDom(document.getElementById('bars')).getOption().series.length);

test.describe('echarts4r', () => {
  test('renders a bar chart and click events reach the server', async ({ open }) => {
    const page = await open();
    await chart(page);
    await expect(page.locator('#bars canvas')).toHaveCount(1);
    expect(await seriesCount(page)).toBe(1);
    await expect(page.locator('#clicked')).toHaveText('clicked: none');

    const p = await barCentre(page, 'banana', 7);
    await page.mouse.click(p.x, p.y);
    await expect(page.locator('#clicked')).toHaveText('clicked: banana = 7 (row 2, sales)');
    const q = await barCentre(page, 'date', 2);
    await page.mouse.click(q.x, q.y);
    await expect(page.locator('#clicked')).toHaveText('clicked: date = 2 (row 4, sales)');
  });

  test('echarts4rProxy adds a series', async ({ open }) => {
    const page = await open();
    await chart(page);
    await page.click('#add_series');
    await expect.poll(() => seriesCount(page)).toBe(2);
    await settle(page);
    expect(
      await page.evaluate(() =>
        (window as any).echarts.getInstanceByDom(document.getElementById('bars')).getOption().series[1].name),
    ).toBe('target');
  });
});
