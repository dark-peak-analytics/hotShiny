import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-reactable' });

const rows = '#tbl .rt-tbody .rt-tr-group';

test.describe('reactable', () => {
  test('renders, searches and pages; page state reaches the server', async ({ open }) => {
    const page = await open();
    await expect(page.locator(rows)).toHaveCount(5);
    await expect(page.locator(rows).first()).toContainText('Mazda RX4');
    await expect(page.locator('#page')).toHaveText('page: 1');
    await page.locator('#tbl .rt-next-button').click();
    await expect(page.locator(rows).first()).toContainText('Valiant');
    await expect(page.locator('#page')).toHaveText('page: 2');
    await page.locator('#tbl .rt-search').fill('Merc');
    await expect(page.locator('#tbl .rt-page-info')).toContainText('of 5 rows');
  });

  test('row selection feeds getReactableState and updateReactable selects', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#selected')).toHaveText('selected:');
    await page.locator(rows).nth(0).click();
    await expect(page.locator('#selected')).toHaveText('selected: 1');
    await page.locator(rows).nth(3).click();
    await expect(page.locator('#selected')).toHaveText('selected: 1,4');

    await page.click('#select_two');
    await expect(page.locator('#selected')).toHaveText('selected: 2,3');
    await expect(page.locator(`${rows} .rt-tr-selected`)).toHaveCount(2);
    await settle(page);
    await page.click('#clear');
    await expect(page.locator('#selected')).toHaveText('selected:');
    await expect(page.locator(`${rows} .rt-tr-selected`)).toHaveCount(0);
  });

  test('re-render with new data', async ({ open }) => {
    const page = await open();
    await page.click('#filter_merc');
    // a single page of rows: reactable drops the pagination bar
    await expect(page.locator('#tbl .rt-page-info')).toHaveCount(0);
    await expect(page.locator(rows)).toHaveCount(5);
    await expect(page.locator(rows).first()).toContainText('Merc 240D');
  });
});
