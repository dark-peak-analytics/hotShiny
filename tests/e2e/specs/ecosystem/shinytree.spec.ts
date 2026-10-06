import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinytree' });

const node = (page: any, text: string) => page.locator('#tree .jstree-anchor', { hasText: text });

test.describe('shinyTree', () => {
  test('renders the tree from renderTree', async ({ open }) => {
    const page = await open();
    await expect(node(page, 'Apple')).toBeVisible();
    await expect(node(page, 'Vegetables')).toBeVisible();
    await expect(page.locator('#o_selected')).toHaveText('selected=');
  });

  test('selection feeds get_selected()', async ({ open }) => {
    const page = await open();
    await node(page, 'Banana').click();
    await expect(page.locator('#o_selected')).toHaveText('selected=Banana');
    await node(page, 'Apple').click();
    await expect(page.locator('#o_selected')).toHaveText('selected=Apple,Banana,Fruits');
  });

  test('re-rendering the tree from the server', async ({ open }) => {
    const page = await open();
    await page.click('#more');
    await expect(node(page, 'Three')).toBeVisible();
    await expect(node(page, 'Apple')).toHaveCount(0);
    await node(page, 'Two').click();
    await expect(page.locator('#o_selected')).toHaveText('selected=Two');
  });
});
