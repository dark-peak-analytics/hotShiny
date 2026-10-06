import { Page } from '@playwright/test';
import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-plotly' });

/** Page coordinates of a data point in a rendered plotly graph. */
async function dataPoint(page: Page, id: string, x: number, y: number) {
  return page.evaluate(
    ({ id, x, y }) => {
      const gd = document.getElementById(id) as any;
      const fl = gd._fullLayout;
      const r = gd.getBoundingClientRect();
      return {
        x: r.left + fl.xaxis._offset + fl.xaxis.l2p(x),
        y: r.top + fl.yaxis._offset + fl.yaxis.l2p(y),
      };
    },
    { id, x, y },
  );
}

async function traces(page: Page, id: string) {
  return page.evaluate((id) => (document.getElementById(id) as any).data.length, id);
}

async function waitForPlot(page: Page, id: string) {
  await expect(page.locator(`#${id} .main-svg`).first()).toBeVisible();
  await page.waitForFunction((id) => !!(document.getElementById(id) as any)?._fullLayout?.xaxis?.l2p, id);
}

test.describe('plotly', () => {
  test('renderPlotly renders a static output', async ({ open }) => {
    const page = await open();
    await waitForPlot(page, 'static');
    await expect(page.locator('#static')).toHaveClass(/plotly/);
    await expect(page.locator('#static .scatterlayer .point')).toHaveCount(5);
    expect(await traces(page, 'static')).toBe(1);
    await expect(page.locator('#click_static')).toHaveText('click A: none');
  });

  test('event_data("plotly_click") and hover feed outputs', async ({ open }) => {
    const page = await open();
    await waitForPlot(page, 'static');
    const p = await dataPoint(page, 'static', 3, 3);
    await page.mouse.move(p.x, p.y);
    await expect(page.locator('#hover_static')).toHaveText('hover A: x=3 y=3');
    await page.mouse.click(p.x, p.y);
    await expect(page.locator('#click_static')).toHaveText('click A: x=3 y=3 curve=0');
    // two clicks within plotly's doubleClickDelay would be a double-click
    await page.waitForTimeout(600);
    const q = await dataPoint(page, 'static', 4, 5);
    await page.mouse.click(q.x, q.y);
    await expect(page.locator('#click_static')).toHaveText('click A: x=4 y=5 curve=0');
    // the other source is unaffected
    await expect(page.locator('#click_dyn')).toHaveText('click B: none');

    // a double-click clears the click event data, as plotly.R arranges
    await page.waitForTimeout(600);
    await page.mouse.dblclick(q.x, q.y);
    await expect(page.locator('#click_static')).toHaveText('click A: none');
  });

  test('drag-zoom emits plotly_relayout; box select emits plotly_selected', async ({ open }) => {
    const page = await open();
    await waitForPlot(page, 'static');
    await expect(page.locator('#relayout_static')).toHaveText('relayout A: none');
    const a = await dataPoint(page, 'static', 1, 0.5);
    const b = await dataPoint(page, 'static', 4, 5.5);
    await page.mouse.move(a.x, a.y);
    await page.mouse.down();
    await page.mouse.move(b.x, b.y, { steps: 10 });
    await page.mouse.up();
    await expect(page.locator('#relayout_static')).toHaveText('relayout A: x from 1 to 4');

    await waitForPlot(page, 'dyn');
    await settle(page);
    const c = await dataPoint(page, 'dyn', 1.5, 0.5);
    const d = await dataPoint(page, 'dyn', 3.5, 4.5);
    await page.mouse.move(c.x, c.y);
    await page.mouse.down();
    await page.mouse.move(d.x, d.y, { steps: 10 });
    await page.mouse.up();
    await expect(page.locator('#selected_dyn')).toHaveText('selected B: 2,3');
  });

  test('plotlyProxyInvoke addTraces and restyle', async ({ open }) => {
    const page = await open();
    await waitForPlot(page, 'static');
    await page.click('#add_trace');
    await expect.poll(() => traces(page, 'static')).toBe(2);
    await expect(page.locator('#static .scatterlayer .trace')).toHaveCount(2);
    await settle(page);
    await page.click('#add_trace');
    await expect.poll(() => traces(page, 'static')).toBe(3);
    expect(await page.evaluate(() => (document.getElementById('static') as any).data[2].name)).toBe('added 2');

    await page.click('#restyle');
    await expect
      .poll(() => page.evaluate(() => (document.getElementById('static') as any).data[0].marker.color))
      .toBe('red');
    await expect(page.locator('#static .scatterlayer .point').first()).toHaveCSS('fill', 'rgb(255, 0, 0)');
  });

  test('plotly inside renderUI re-renders and emits its own events', async ({ open }) => {
    const page = await open();
    await waitForPlot(page, 'dyn');
    await expect(page.locator('#dyn_label')).toHaveText('dynamic plot with 4 points');
    await expect(page.locator('#dyn .barlayer .point')).toHaveCount(4);

    await page.fill('#n', '6');
    await expect(page.locator('#dyn_label')).toHaveText('dynamic plot with 6 points');
    await expect(page.locator('#dyn .barlayer .point')).toHaveCount(6);
    await waitForPlot(page, 'dyn');
    await settle(page);

    const p = await dataPoint(page, 'dyn', 5, 2);
    await page.mouse.click(p.x, p.y);
    await expect(page.locator('#click_dyn')).toHaveText('click B: x=5 y=5');
    await expect(page.locator('#click_static')).toHaveText('click A: none');

    // bindCache(): going back to a cached n re-renders from the cache
    await page.fill('#n', '4');
    await expect(page.locator('#dyn_label')).toHaveText('dynamic plot with 4 points');
    await expect(page.locator('#dyn .barlayer .point')).toHaveCount(4);
  });
});
