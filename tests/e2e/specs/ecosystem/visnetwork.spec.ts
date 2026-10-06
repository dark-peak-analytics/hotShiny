import { Page } from '@playwright/test';
import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-visnetwork' });

const network = (page: Page) =>
  page.waitForFunction(() => !!(document.getElementById('graphnet') as any)?.chart?.body?.data?.nodes);

const nodeCount = (page: Page) =>
  page.evaluate(() => (document.getElementById('graphnet') as any).chart.body.data.nodes.length);

async function nodePosition(page: Page, id: number) {
  return page.evaluate((id) => {
    const el = document.getElementById('graphnet') as any;
    const net = el.chart;
    const p = net.canvasToDOM(net.getPositions([id])[id]);
    const r = el.querySelector('canvas').getBoundingClientRect();
    return { x: r.left + p.x, y: r.top + p.y };
  }, id);
}

test.describe('visNetwork', () => {
  test('renders nodes and the id selector', async ({ open }) => {
    const page = await open();
    await network(page);
    await expect(page.locator('#net canvas')).toHaveCount(1);
    expect(await nodeCount(page)).toBe(4);
    await expect(page.locator('#nodeSelectnet option')).toHaveCount(5);
    await expect(page.locator('#selected')).toHaveText('selected:');
  });

  test('selecting a node (dropdown and canvas click) sets input$<id>_selected', async ({ open }) => {
    const page = await open();
    await network(page);
    await page.locator('#nodeSelectnet').selectOption('3');
    await expect(page.locator('#selected')).toHaveText('selected: 3');
    await settle(page);
    const p = await nodePosition(page, 4);
    await page.mouse.click(p.x, p.y);
    await expect(page.locator('#selected')).toHaveText('selected: 4');
    await expect(page.locator('#nodeSelectnet')).toHaveValue('4');
  });

  test('visNetworkProxy updates nodes/edges and selects', async ({ open }) => {
    const page = await open();
    await network(page);
    await page.click('#add_node');
    await expect.poll(() => nodeCount(page)).toBe(5);
    expect(await page.evaluate(() => (document.getElementById('graphnet') as any).chart.body.data.edges.length)).toBe(4);
    await settle(page);
    await page.click('#select_beta');
    await expect
      .poll(() => page.evaluate(() => (document.getElementById('graphnet') as any).chart.getSelectedNodes()))
      .toEqual([2]);
  });
});
