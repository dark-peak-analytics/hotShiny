import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinywidgets-modules' });

const selectize = (id: string) => `#${id} + .selectize-control`;

test.describe('shinyWidgets in modules', () => {
  test('update and confirm alert inside a module, without session', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#m1-o_pk')).toHaveText('pk=a');
    await page.click('#m1-upd');
    await expect(page.locator('#m1-o_pk')).toHaveText('pk=c');
    await expect(page.locator('.bootstrap-select:has(#m1-pk) .filter-option-inner-inner')).toHaveText('c');

    await page.click('#m1-ask');
    const popup = page.locator('.swal2-popup');
    await expect(popup.locator('.swal2-title')).toHaveText('Module question');
    await popup.locator('.swal2-confirm').click();
    await expect(page.locator('#m1-o_ok')).toHaveText('ok=TRUE');
  });

  test('inputSweetAlert returns the typed value', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#o_name')).toHaveText('name=NULL');
    await page.click('#name_btn');
    const popup = page.locator('.swal2-popup');
    await popup.locator('input.swal2-input').fill('Ada');
    await popup.locator('.swal2-confirm').click();
    await expect(page.locator('#o_name')).toHaveText('name=Ada');
  });

  test('selectizeGroupServer filters data and dependent choices', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#o_rows')).toHaveText('rows=5 makes=audi,bmw,fiat');
    await page.locator(`${selectize('flt-make')} .selectize-input`).click();
    await page.locator(`${selectize('flt-make')} .option[data-value="bmw"]`).click();
    await page.locator('h2').click();
    await expect(page.locator('#o_rows')).toHaveText('rows=2 makes=bmw');

    await page.locator(`${selectize('flt-fuel')} .selectize-input`).click();
    await expect(page.locator(`${selectize('flt-fuel')} .option`)).toHaveText(['diesel', 'petrol']);
    await page.locator(`${selectize('flt-fuel')} .option[data-value="diesel"]`).click();
    await page.locator('h2').click();
    await expect(page.locator('#o_rows')).toHaveText('rows=1 makes=bmw');

    await page.click('#flt-reset_all');
    await expect(page.locator('#o_rows')).toHaveText('rows=5 makes=audi,bmw,fiat');
  });
});
