import { Page } from '@playwright/test';
import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-dygraphs' });

const ready = (page: Page) =>
  page.waitForFunction(() => {
    const w = window as any;
    const inst = w.HTMLWidgets.find('#dy');
    return !!inst?.dygraph && inst.dygraph.numRows() > 0;
  });

/** Page coordinates of the given (ms since epoch, y) value. */
async function toPage(page: Page, x: number, y: number) {
  return page.evaluate(
    ({ x, y }) => {
      const g = (window as any).HTMLWidgets.find('#dy').dygraph;
      const [cx, cy] = g.toDomCoords(x, y);
      const r = g.graphDiv.getBoundingClientRect();
      return { x: r.left + cx, y: r.top + cy };
    },
    { x, y },
  );
}

test.describe('dygraphs', () => {
  test('renders and reports the date window', async ({ open }) => {
    const page = await open();
    await ready(page);
    await expect(page.locator('#dy .dygraph-title')).toHaveText('Deaths');
    await expect(page.locator('#dy .dygraph-rangesel-fgcanvas')).toHaveCount(1);
    await expect(page.locator('#window')).toHaveText('window: 1974-01 to 1979-12');
  });

  test('drag-zoom updates input$<id>_date_window and click sets input$<id>_click', async ({ open }) => {
    const page = await open();
    await ready(page);
    const a = await toPage(page, Date.UTC(1975, 0, 1), 2000);
    const b = await toPage(page, Date.UTC(1977, 0, 1), 2000);
    await page.mouse.move(a.x, a.y);
    await page.mouse.down();
    await page.mouse.move(b.x, b.y, { steps: 10 });
    await page.mouse.up();
    await expect(page.locator('#window')).toHaveText(/^window: 197[45]-\d\d to 197[67]-\d\d$/);
    await expect(page.locator('#window')).not.toHaveText('window: 1974-01 to 1979-12');
    await settle(page);

    const c = await toPage(page, Date.UTC(1976, 0, 1), 2000);
    await page.mouse.click(c.x, c.y);
    await expect(page.locator('#clicked')).toHaveText(/^clicked: 197[56]-\d\d$/);
  });

  test('re-renders when an input changes', async ({ open }) => {
    const page = await open();
    await ready(page);
    const roll = () => page.evaluate(() => (window as any).HTMLWidgets.find('#dy').dygraph.rollPeriod());
    expect(await roll()).toBe(1);
    await page.locator('#smooth').evaluate((el) => {
      const s = (window as any).$(el).data('ionRangeSlider');
      s.update({ from: 6 });
      (window as any).$(el).trigger('change');
    });
    await expect.poll(roll).toBe(6);
  });
});
