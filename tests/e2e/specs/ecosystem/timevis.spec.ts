import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-timevis' });

const item = (page: any, text: string) => page.locator('#tl .vis-item', { hasText: text });

test.describe('timevis', () => {
  test('renders items and reports its data and window', async ({ open }) => {
    const page = await open();
    await expect(item(page, 'Alpha')).toBeVisible();
    await expect(item(page, 'Beta')).toBeVisible();
    await expect(page.locator('#o_selected')).toHaveText('selected=');
    await expect(page.locator('#o_data')).toHaveText('data=data.frame:Alpha,Beta,Gamma');
    await expect(page.locator('#o_window')).toHaveText('window=2024-01-01');
  });

  test('clicking an item sets the selected input', async ({ open }) => {
    const page = await open();
    await item(page, 'Beta').click();
    await expect(page.locator('#o_selected')).toHaveText('selected=i2');
    await expect(item(page, 'Beta')).toHaveClass(/vis-selected/);
  });

  test('proxy functions update the widget and its inputs', async ({ open }) => {
    const page = await open();
    await page.click('#add');
    await expect(item(page, 'Delta')).toBeVisible();
    await expect(page.locator('#o_data')).toHaveText('data=data.frame:Alpha,Beta,Delta,Gamma');
    await page.click('#sel');
    await expect(item(page, 'Gamma')).toHaveClass(/vis-selected/);
    await expect(page.locator('#o_selected')).toHaveText('selected=i3');
    await page.click('#rm');
    await expect(item(page, 'Alpha')).toHaveCount(0);
    await expect(page.locator('#o_data')).toHaveText('data=data.frame:Beta,Delta,Gamma');
  });
});
