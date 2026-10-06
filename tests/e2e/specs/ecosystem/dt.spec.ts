import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-dt' });

const rows = (id: string) => `#${id} table.dataTable tbody tr`;
const firstCell = (id: string) => `#${id} table.dataTable tbody tr:first-child td:nth-child(1)`;

test.describe('DT', () => {
  test('client-side table searches, sorts and pages', async ({ open }) => {
    const page = await open();
    await expect(page.locator(rows('client'))).toHaveCount(5);
    await expect(page.locator(firstCell('client'))).toHaveText('Mazda RX4');
    await expect(page.locator('#client .dataTables_info')).toHaveText('Showing 1 to 5 of 15 entries');

    await page.locator('#client thead th', { hasText: 'mpg' }).click();
    await expect(page.locator(firstCell('client'))).toHaveText('Cadillac Fleetwood');
    await page.locator('#client thead th', { hasText: 'mpg' }).click();
    await expect(page.locator(firstCell('client'))).toHaveText('Merc 240D');

    await page.locator('#client input[type=search]').fill('Merc');
    await expect(page.locator('#client .dataTables_info')).toHaveText(
      'Showing 1 to 5 of 7 entries (filtered from 15 total entries)',
    );
    await page.locator('#client .paginate_button.next').click();
    await expect(page.locator(rows('client'))).toHaveCount(2);
  });

  test('client-side row selection feeds input$<id>_rows_selected', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#client_selected')).toHaveText('client selected:');
    await page.locator(rows('client')).nth(0).click();
    await expect(page.locator('#client_selected')).toHaveText('client selected: 1');
    await page.locator(rows('client')).nth(2).click();
    await expect(page.locator('#client_selected')).toHaveText('client selected: 1,3');
    await expect(page.locator(`${rows('client')}.selected`)).toHaveCount(2);
    await page.locator(rows('client')).nth(0).click();
    await expect(page.locator('#client_selected')).toHaveText('client selected: 3');
  });

  test('server-side processing searches and pages through the dataobj endpoint', async ({ open }) => {
    const page = await open();
    await expect(page.locator(rows('server'))).toHaveCount(5);
    await expect(page.locator(firstCell('server'))).toHaveText('Mazda RX4');
    await expect(page.locator('#server .dataTables_info')).toHaveText('Showing 1 to 5 of 15 entries');

    const ajax = page.waitForResponse((r) => /dataobj\/server/.test(r.url()) && r.request().method() === 'POST');
    await page.locator('#server input[type=search]').fill('Merc');
    expect((await ajax).status()).toBe(200);
    await expect(page.locator('#server .dataTables_info')).toHaveText(
      'Showing 1 to 5 of 7 entries (filtered from 15 total entries)',
    );
    await expect(page.locator('#server_search')).toHaveText('server search: Merc');
    await page.locator('#server .paginate_button.next').click();
    await expect(page.locator(rows('server'))).toHaveCount(2);
    await expect(page.locator(firstCell('server'))).toHaveText('Merc 450SL');

    await page.locator('#server input[type=search]').clear();
    await page.locator('#server input[type=search]').press('Backspace');
    await expect(page.locator('#server_search')).toHaveText('server search:');
    await page.locator('#server thead th', { hasText: 'cyl' }).click();
    await expect(page.locator('#server .dataTables_info')).toHaveText('Showing 1 to 5 of 15 entries');
    await expect(page.locator(firstCell('server'))).toHaveText('Datsun 710');
  });

  test('server-side selection and dataTableProxy selectRows / replaceData', async ({ open }) => {
    const page = await open();
    await page.locator(rows('server')).nth(1).click();
    await expect(page.locator('#server_selected')).toHaveText('server selected: 2');

    await page.click('#select_rows');
    await expect(page.locator('#server_selected')).toHaveText('server selected: 2,4');
    await expect(page.locator(`${rows('server')}.selected`)).toHaveCount(2);
    await expect(page.locator(`${rows('server')}`).nth(3)).toHaveClass(/selected/);

    await page.click('#replace');
    await expect(page.locator(`${rows('server')}`).nth(0).locator('td').nth(1)).toHaveText('210');
    await expect(page.locator(rows('server'))).toHaveCount(5);
    await settle(page);
    await page.click('#replace');
    await expect(page.locator(`${rows('server')}`).nth(0).locator('td').nth(1)).toHaveText('2100');
  });

  test('DT inside a module: column filter, rows_all, selection and namespaced proxy', async ({ open }) => {
    const page = await open();
    await expect(page.locator(rows('mod-tbl'))).toHaveCount(15);
    await expect(page.locator('#mod-rows_all')).toHaveText('module rows: 15');
    // column filter row: [rownames, make, mpg, cyl]
    const makeFilter = page.locator('#mod-tbl thead tr').nth(1).locator('td').nth(1).locator('input');
    await makeFilter.fill('Merc');
    await expect(page.locator(rows('mod-tbl'))).toHaveCount(7);
    await expect(page.locator('#mod-rows_all')).toHaveText('module rows: 7');

    await page.locator(rows('mod-tbl')).nth(1).click();
    await expect(page.locator('#mod-selected')).toHaveText('module selected: 9');
    await settle(page);
    await page.click('#mod-select_first');
    await expect(page.locator('#mod-selected')).toHaveText('module selected: 1');
    // the top-level tables are untouched
    await expect(page.locator('#server_selected')).toHaveText('server selected:');
  });

  test('editable cells send input$<id>_cell_edit and editData updates the table', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#edit_data')).toContainText('Mazda RX4      21');
    const cell = page.locator(rows('edit')).nth(0).locator('td').nth(1);
    await cell.dblclick();
    const editor = cell.locator('input, textarea');
    await expect(editor).toBeVisible();
    await editor.fill('99');
    // cell editing commits on blur
    await editor.blur();
    await expect(page.locator('#edit_info')).toHaveText('edited row 1 col 1 -> 99');
    await expect(page.locator('#edit_data')).toContainText('Mazda RX4      99');
    await expect(cell).toHaveText('99');

    const cell2 = page.locator(rows('edit')).nth(2).locator('td').nth(2);
    await cell2.dblclick();
    await cell2.locator('input, textarea').fill('7');
    await cell2.locator('input, textarea').blur();
    await expect(page.locator('#edit_info')).toHaveText('edited row 3 col 2 -> 7');
    await expect(page.locator('#edit_data')).toContainText('Datsun 710     22.8   7');
  });
});
