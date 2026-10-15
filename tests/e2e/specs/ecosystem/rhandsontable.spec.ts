import { Page } from '@playwright/test';
import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-rhandsontable' });

const cell = (page: Page, row: number, col: number) =>
  page.locator('#hot .ht_master tbody tr').nth(row).locator('td').nth(col);

async function editCell(page: Page, row: number, col: number, value: string) {
  // typing on a selected cell opens its editor with the typed text replacing the value
  await cell(page, row, col).click();
  await page.keyboard.type(value);
  await page.keyboard.press('Enter');
}

test.describe('rhandsontable', () => {
  test('renders the data frame', async ({ open }) => {
    const page = await open();
    await expect(cell(page, 0, 0)).toHaveText('a');
    await expect(cell(page, 2, 1)).toHaveText('3.00');
    await expect(page.locator('#o_sum')).toHaveText('sum=6 class=numeric');
    await expect(page.locator('#o_select')).toHaveText('select=NULL');
  });

  test('hot_to_r sees an edited numeric and text cell', async ({ open }) => {
    const page = await open();
    await editCell(page, 1, 1, '20');
    await expect(page.locator('#o_sum')).toHaveText('sum=24 class=numeric');
    await editCell(page, 0, 0, 'zz');
    await expect(page.locator('#o_names')).toHaveText('names=zz,b,c');
    await cell(page, 1, 2).locator('input[type="checkbox"]').click();
    await expect(page.locator('#o_flags')).toHaveText('flags=TRUE,TRUE,TRUE');
  });

  test('selectCallback reports the selected cell', async ({ open }) => {
    const page = await open();
    await cell(page, 2, 1).click();
    await expect(page.locator('#o_select')).toHaveText('select=r3c2');
  });

  test('re-rendering from the server replaces the table', async ({ open }) => {
    const page = await open();
    await page.click('#reset');
    await expect(cell(page, 2, 1)).toHaveText('30.00');
    await expect(page.locator('#o_sum')).toHaveText('sum=60 class=numeric');
  });
});
