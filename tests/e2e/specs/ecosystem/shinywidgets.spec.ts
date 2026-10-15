import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinywidgets' });

const picker = (id: string) => `.bootstrap-select:has(#${id})`;

test.describe('shinyWidgets', () => {
  test('initial values', async ({ open }) => {
    const page = await open();
    const expected: Record<string, string> = {
      o_pk1: 'character:beta',
      o_pk2: 'NULL',
      o_sw: 'logical:TRUE',
      o_ms: 'logical:FALSE',
      o_pc: 'logical:FALSE',
      o_rgb: 'character:one',
      o_adp: 'Date:2024-03-15',
      o_stx: 'character:mid',
      o_nus: 'integer:40',
      o_vs: 'character:red',
      o_confirm: 'NULL',
      o_dd: 'state=NULL text=a',
    };
    for (const [id, value] of Object.entries(expected)) {
      await expect(page.locator(`#${id}`), id).toHaveText(value);
    }
  });

  test('pickerInput single with live search', async ({ open }) => {
    const page = await open();
    await page.locator(`${picker('pk1')} button.dropdown-toggle`).click();
    const search = page.locator(`${picker('pk1')} .bs-searchbox input`);
    await search.fill('gam');
    const items = page.locator(`${picker('pk1')} .dropdown-menu li:not(.hidden):visible`);
    await expect(items).toHaveCount(1);
    await items.first().click();
    await expect(page.locator('#o_pk1')).toHaveText('character:gamma');
    await expect(page.locator(`${picker('pk1')} .filter-option-inner-inner`)).toHaveText('gamma');
  });

  test('pickerInput multiple with actions box', async ({ open }) => {
    const page = await open();
    await page.locator(`${picker('pk2')} button.dropdown-toggle`).click();
    await page.locator(`${picker('pk2')} .dropdown-menu li a:has-text("z")`).click();
    await page.locator(`${picker('pk2')} .dropdown-menu li a:has-text("x")`).click();
    await expect(page.locator('#o_pk2')).toHaveText('character:x,z');
    await page.locator(`${picker('pk2')} .bs-select-all`).click();
    await expect(page.locator('#o_pk2')).toHaveText('character:x,y,z');
    await page.locator(`${picker('pk2')} .bs-deselect-all`).click();
    await expect(page.locator('#o_pk2')).toHaveText('NULL');
  });

  test('switches, pretty checkbox and group buttons', async ({ open }) => {
    const page = await open();
    await page.locator('.bootstrap-switch:has(#sw) .bootstrap-switch-handle-on').click();
    await expect(page.locator('#o_sw')).toHaveText('logical:FALSE');
    // the material switch's checkbox is visually hidden behind a zero-size label
    await page.locator('#ms').evaluate((el: HTMLInputElement) => el.click());
    await expect(page.locator('#o_ms')).toHaveText('logical:TRUE');
    await page.locator('.pretty:has(#pc)').click();
    await expect(page.locator('#o_pc')).toHaveText('logical:TRUE');
    await page.locator('#rgb button:has(input[value="two"])').click();
    await expect(page.locator('#o_rgb')).toHaveText('character:two');
  });

  test('air datepicker, slider text, noUiSlider and virtual select', async ({ open }) => {
    const page = await open();
    await page.locator('#adp').click();
    await page.locator('.air-datepicker-cell.-day-[data-date="20"][data-month="2"]').click();
    await expect(page.locator('#o_adp')).toHaveText('Date:2024-03-20');
    await page.keyboard.press('Escape');

    await page.locator('#stx').locator('xpath=..').locator('.irs-line').focus();
    await page.keyboard.press('ArrowLeft');
    await expect(page.locator('#o_stx')).toHaveText('character:low');

    await page.locator('#nus .noUi-handle').focus();
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('ArrowRight');
    await expect(page.locator('#o_nus')).toHaveText('integer:42');

    await page.locator('#vs .vscomp-toggle-button').click();
    await page.locator('#vs .vscomp-option[data-value="green"]').click();
    await expect(page.locator('#o_vs')).toHaveText('character:green');
  });

  test('update functions without a session argument', async ({ open }) => {
    const page = await open();
    await page.click('#upd');
    await expect(page.locator('#o_pk1')).toHaveText('character:delta');
    await expect(page.locator(`${picker('pk1')} .filter-option-inner-inner`)).toHaveText('delta');
    await expect(page.locator('#o_pk2')).toHaveText('character:y,w');
    await expect(page.locator('#pk2 option')).toHaveCount(4);
    await expect(page.locator('#o_sw')).toHaveText('logical:FALSE');
    await expect(page.locator('#o_ms')).toHaveText('logical:TRUE');
    await expect(page.locator('#o_pc')).toHaveText('logical:TRUE');
    await expect(page.locator('#o_rgb')).toHaveText('character:three');
    await expect(page.locator('#o_adp')).toHaveText('Date:2025-01-02');
    await expect(page.locator('#o_stx')).toHaveText('character:high');
    await expect(page.locator('#o_nus')).toHaveText('integer:75');
    await expect(page.locator('#o_vs')).toHaveText('character:blue');
    await settle(page);
  });

  test('sweet alerts and the confirm callback input', async ({ open }) => {
    const page = await open();
    await page.click('#alert');
    const popup = page.locator('.swal2-popup');
    await expect(popup).toBeVisible();
    await expect(popup.locator('.swal2-title')).toHaveText('Hello');
    await expect(popup.locator('.swal2-html-container')).toHaveText('From the server');
    await popup.locator('.swal2-confirm').click();
    await expect(popup).toBeHidden();

    await page.click('#confirm_btn');
    await expect(popup.locator('.swal2-title')).toHaveText('Sure?');
    await popup.locator('.swal2-confirm').click();
    await expect(page.locator('#o_confirm')).toHaveText('logical:TRUE');
    await expect(popup).toBeHidden();

    await page.click('#confirm_btn');
    await popup.locator('.swal2-cancel').click();
    await expect(page.locator('#o_confirm')).toHaveText('logical:FALSE');
  });

  test('dropdownButton state and inner inputs', async ({ open }) => {
    const page = await open();
    await page.locator('#dd').click();
    await expect(page.locator('#o_dd')).toHaveText('state=logical:TRUE text=a');
    await page.fill('#dd_text', 'inside');
    await expect(page.locator('#o_dd')).toHaveText('state=logical:TRUE text=inside');
    await page.locator('h2').click();
    await expect(page.locator('#o_dd')).toHaveText('state=logical:FALSE text=inside');
  });
});
