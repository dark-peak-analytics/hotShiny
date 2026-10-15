import { Locator, Page } from '@playwright/test';
import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinyjqui' });

async function slowDrag(page: Page, x0: number, y0: number, x1: number, y1: number) {
  await page.mouse.move(x0, y0);
  await page.mouse.down();
  const n = 15;
  for (let i = 1; i <= n; i++) {
    await page.mouse.move(x0 + ((x1 - x0) * i) / n, y0 + ((y1 - y0) * i) / n);
    await page.waitForTimeout(20);
  }
  await page.mouse.up();
}

async function resizeBy(page: Page, el: Locator, dx: number, dy: number) {
  const handle = el.locator('.ui-resizable-se');
  const h = (await handle.boundingBox())!;
  await slowDrag(page, h.x + h.width / 2, h.y + h.height / 2, h.x + h.width / 2 + dx, h.y + h.height / 2 + dy);
}

test.describe('shinyjqui', () => {
  test('initial values', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#o_order')).toHaveText('order=i_a,i_b,i_c');
    await expect(page.locator('#o_size')).toHaveText('size=200x100');
    await expect(page.locator('#o_size2')).toHaveText('size2=NULL');
  });

  test('jqui_sortable reports the new order', async ({ open }) => {
    const page = await open();
    const a = (await page.locator('#i_a').boundingBox())!;
    const c = (await page.locator('#i_c').boundingBox())!;
    await slowDrag(page, a.x + 20, a.y + a.height / 2, c.x + 20, c.y + c.height + 5);
    await expect(page.locator('#o_order')).toHaveText('order=i_b,i_c,i_a');
  });

  test('jqui_resizable reports the new size', async ({ open }) => {
    const page = await open();
    await resizeBy(page, page.locator('#box'), 50, 30);
    await expect(page.locator('#o_size')).toHaveText('size=250x130');
  });

  test('jqui_resizable on inserted UI', async ({ open }) => {
    const page = await open();
    await page.click('#add');
    await expect(page.locator('#box2 .ui-resizable-se')).toBeVisible();
    await expect(page.locator('#o_size2')).toHaveText('size2=100x50');
    await resizeBy(page, page.locator('#box2'), 40, 20);
    await expect(page.locator('#o_size2')).toHaveText('size2=140x70');
  });
});
