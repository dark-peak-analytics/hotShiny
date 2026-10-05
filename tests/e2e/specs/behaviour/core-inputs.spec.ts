import { Locator } from '@playwright/test';
import { test, expect, settle } from '../../helpers/fixtures';

async function typeDate(input: Locator, value: string) {
  await input.click();
  await input.press('ControlOrMeta+a');
  await input.pressSequentially(value);
  await input.press('Escape');
  await input.blur();
}

test.use({ fixture: 'core-inputs' });

test.describe('core inputs', () => {
  test('initial values arrive with shiny types', async ({ open }) => {
    const page = await open();
    const expected: Record<string, string> = {
      o_txt: 'character:hello',
      o_area: 'character:line',
      o_pwd: 'character:',
      o_num: 'integer:5',
      o_sel: 'character:b',
      o_selmulti: 'NULL',
      o_selnative: 'character:one',
      o_chk: 'logical:TRUE',
      o_chkgrp: 'character:g',
      o_radio: 'character:mid',
      o_slider: 'integer:30',
      o_range: 'integer:20,80',
      o_date: 'Date:2024-03-15',
      o_daterange: 'Date:2024-01-01,2024-01-31',
      o_btn: 'integer:0',
      o_lnk: 'integer:0',
    };
    for (const [id, value] of Object.entries(expected)) {
      await expect(page.locator(`#${id}`), id).toHaveText(value);
    }
  });

  test('text-like inputs', async ({ open }) => {
    const page = await open();
    await page.fill('#txt', 'typed text');
    await expect(page.locator('#o_txt')).toHaveText('character:typed text');
    await page.fill('#area', 'multi\nline');
    await expect(page.locator('#o_area')).toHaveText('character:multi\nline');
    await page.fill('#pwd', 's3cret');
    await expect(page.locator('#o_pwd')).toHaveText('character:s3cret');
    await page.fill('#num', '8');
    await expect(page.locator('#o_num')).toHaveText('integer:8');
    await page.fill('#num', '2.5');
    await expect(page.locator('#o_num')).toHaveText('numeric:2.5');
  });

  test('selectize, native select and multiple', async ({ open }) => {
    const page = await open();
    await page.locator('#sel + .selectize-control .selectize-input').click();
    await page.locator('#sel + .selectize-control .option[data-value="c"]').click();
    await expect(page.locator('#o_sel')).toHaveText('character:c');

    await page.locator('#selmulti + .selectize-control .selectize-input').click();
    await page.locator('#selmulti + .selectize-control .option[data-value="y"]').click();
    await page.locator('#selmulti + .selectize-control .option[data-value="z"]').click();
    await expect(page.locator('#o_selmulti')).toHaveText('character:y,z');

    await page.selectOption('#selnative', 'two');
    await expect(page.locator('#o_selnative')).toHaveText('character:two');
  });

  test('checkbox, checkbox group and radio', async ({ open }) => {
    const page = await open();
    await page.locator('#chk').uncheck();
    await expect(page.locator('#o_chk')).toHaveText('logical:FALSE');
    await page.locator('#chkgrp input[value="r"]').check();
    await expect(page.locator('#o_chkgrp')).toHaveText('character:r,g');
    await page.locator('#chkgrp input[value="g"]').uncheck();
    await page.locator('#chkgrp input[value="r"]').uncheck();
    await expect(page.locator('#o_chkgrp')).toHaveText('NULL');
    await page.locator('#radio input[value="high"]').check();
    await expect(page.locator('#o_radio')).toHaveText('character:high');
  });

  test('sliders via keyboard', async ({ open }) => {
    const page = await open();
    const single = page.locator('#slider').locator('xpath=..');
    await single.locator('.irs-line').focus();
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('ArrowRight');
    await expect(page.locator('#o_slider')).toHaveText('integer:34');
    const range = page.locator('#range').locator('xpath=..');
    await range.locator('.irs-handle.from').click();
    await page.keyboard.press('ArrowLeft');
    await expect(page.locator('#o_range')).toHaveText(/^integer:\d+,80$/);
    await expect(page.locator('#o_range')).not.toHaveText('integer:20,80');
  });

  test('date inputs accept typed values', async ({ open }) => {
    const page = await open();
    await typeDate(page.locator('#date input'), '2024-04-01');
    await expect(page.locator('#o_date')).toHaveText('Date:2024-04-01');
    await typeDate(page.locator('#daterange input').nth(1), '2024-02-15');
    await expect(page.locator('#o_daterange')).toHaveText('Date:2024-01-01,2024-02-15');
  });

  test('action button and link count clicks', async ({ open }) => {
    const page = await open();
    await page.click('#btn');
    await page.click('#btn');
    await expect(page.locator('#o_btn')).toHaveText('integer:2');
    await page.click('#lnk');
    await expect(page.locator('#o_lnk')).toHaveText('integer:1');
  });

  test('update* functions reach every input', async ({ open }) => {
    const page = await open();
    await page.click('#update_all');
    await expect(page.locator('#o_txt')).toHaveText('character:updated');
    await expect(page.locator('#txt')).toHaveValue('updated');
    await expect(page.locator('#o_area')).toHaveText('character:new area');
    await expect(page.locator('#o_num')).toHaveText('integer:9');
    await expect(page.locator('#o_sel')).toHaveText('character:c');
    await expect(page.locator('#o_selmulti')).toHaveText('character:x,z');
    await expect(page.locator('#o_chk')).toHaveText('logical:FALSE');
    await expect(page.locator('#o_chkgrp')).toHaveText('character:r,b');
    await expect(page.locator('#o_radio')).toHaveText('character:high');
    await expect(page.locator('#o_slider')).toHaveText('integer:77');
    await expect(page.locator('#o_range')).toHaveText('integer:10,40');
    await expect(page.locator('#o_date')).toHaveText('Date:2025-12-25');
    await expect(page.locator('#o_daterange')).toHaveText('Date:2025-02-01,2025-02-28');
    await expect(page.locator('#btn')).toHaveText('Relabelled');
    await settle(page);
  });
});
