import { Locator, Page } from '@playwright/test';
import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-sortable' });

// SortableJS reacts to pointer events and animates swaps; drag with slow,
// explicit mouse steps so each swap settles before the next one.
async function drag(page: Page, from: Locator, to: Locator, below = true) {
  const a = (await from.boundingBox())!;
  const b = (await to.boundingBox())!;
  await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2);
  await page.mouse.down();
  await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2 + 5, { steps: 5 });
  const y = below ? b.y + b.height * 0.8 : b.y + b.height * 0.2;
  const x0 = a.x + a.width / 2, y0 = a.y + a.height / 2 + 5, n = 20;
  for (let i = 1; i <= n; i++) {
    await page.mouse.move(x0 + ((b.x + b.width / 2 - x0) * i) / n, y0 + ((y - y0) * i) / n);
    await page.waitForTimeout(30);
  }
  await page.waitForTimeout(200);
  await page.mouse.up();
}

test.describe('sortable', () => {
  test('initial values', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#o_rank')).toHaveText('rank=apple,banana,cherry');
    await expect(page.locator('#o_left')).toHaveText('left=one,two,three');
    await expect(page.locator('#o_right')).toHaveText('right=');
    await expect(page.locator('#o_grp')).toHaveText('grp=left:one+two+three;right:');
  });

  test('reordering a rank list feeds the output', async ({ open }) => {
    const page = await open();
    const items = page.locator('#rank .rank-list-item');
    await drag(page, items.filter({ hasText: 'cherry' }), items.filter({ hasText: 'apple' }), false);
    await expect(page.locator('#o_rank')).toHaveText('rank=cherry,apple,banana');
    await expect(items.first()).toHaveText('cherry');
  });

  test('moving an item between buckets', async ({ open }) => {
    const page = await open();
    const item = page.locator('#left .rank-list-item', { hasText: 'two' });
    await drag(page, item, page.locator('#right'));
    await expect(page.locator('#o_left')).toHaveText('left=one,three');
    await expect(page.locator('#o_right')).toHaveText('right=two');
    await expect(page.locator('#o_grp')).toHaveText('grp=left:one+three;right:two');
  });
});
