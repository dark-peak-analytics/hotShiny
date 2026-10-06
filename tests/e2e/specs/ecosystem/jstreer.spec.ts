import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-jstreer' });

const node = (page: any, text: string) => page.locator('#tree .jstree-anchor', { hasText: text });

test.describe('jsTreeR', () => {
  test('renders the tree with the opened node', async ({ open }) => {
    const page = await open();
    await expect(node(page, 'Apple')).toBeVisible();
    await expect(node(page, 'Carrot')).toHaveCount(0);
    await expect(page.locator('#o_selected')).toHaveText('selected=');
  });

  test('selecting and checking nodes', async ({ open }) => {
    const page = await open();
    await node(page, 'Banana').click();
    await expect(page.locator('#o_selected')).toHaveText('selected=Banana');
    await expect(page.locator('#o_checked')).toHaveText('checked=Banana');
    await node(page, 'Apple').click();
    await expect(page.locator('#o_selected')).toHaveText('selected=Banana,Apple,Fruits');
    await expect(page.locator('#o_checked')).toHaveText('checked=Banana,Apple,Fruits');
  });

  test('opening a closed node', async ({ open }) => {
    const page = await open();
    await page.locator('#tree li', { hasText: 'Vegetables' }).locator('> .jstree-ocl').click();
    await expect(node(page, 'Leek')).toBeVisible();
    await node(page, 'Leek').click();
    await expect(page.locator('#o_selected')).toHaveText('selected=Leek');
  });
});
