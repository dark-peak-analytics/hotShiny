import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinyjs' });

test.describe('shinyjs', () => {
  test('hide, show and toggle', async ({ open }) => {
    const page = await open();
    const target = page.locator('#target');
    await expect(target).toBeVisible();
    await page.click('#hide');
    await expect(target).toBeHidden();
    await page.click('#show');
    await expect(target).toBeVisible();
    await page.click('#toggle');
    await expect(target).toBeHidden();
    await page.click('#toggle');
    await expect(target).toBeVisible();
    await expect(page.locator('#hiddenbox')).toBeHidden();
    await page.click('#hidden_show');
    await expect(page.locator('#hiddenbox')).toBeVisible();
  });

  test('disable, enable, addClass and removeClass', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#name')).toBeEnabled();
    await page.click('#disable');
    await expect(page.locator('#name')).toBeDisabled();
    await page.click('#enable');
    await expect(page.locator('#name')).toBeEnabled();
    await page.click('#addcls');
    await expect(page.locator('#styled')).toHaveClass(/highlight/);
    await expect(page.locator('#styled')).toHaveCSS('color', 'rgb(200, 0, 0)');
    await page.click('#rmcls');
    await expect(page.locator('#styled')).not.toHaveClass(/highlight/);
  });

  test('delay, onclick, runjs and extendShinyjs', async ({ open }) => {
    const page = await open();
    await page.click('#delay');
    await expect(page.locator('#delayed')).toHaveText('waiting');
    await expect(page.locator('#delayed')).toHaveText('done after delay');
    await expect(page.locator('#clicks')).toHaveText('clicks=0');
    await page.click('#clickme');
    await page.click('#clickme');
    await expect(page.locator('#clicks')).toHaveText('clicks=2');
    await page.click('#runjs');
    await expect(page.locator('#jsout')).toHaveText('ran 2');
    await page.click('#paint');
    await expect(page.locator('#canvas')).toHaveCSS('background-color', 'rgb(255, 0, 0)');
  });

  test('reset restores a form and a single input', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#form_state')).toHaveText('default text|5|FALSE|a');
    await page.fill('#f_text', 'changed');
    await page.fill('#f_num', '42');
    await page.check('#f_chk');
    await page.evaluate(() => (window as any).$('#f_sel')[0].selectize.setValue('c'));
    await expect(page.locator('#form_state')).toHaveText('changed|42|TRUE|c');
    await page.click('#reset');
    await expect(page.locator('#form_state')).toHaveText('default text|5|FALSE|a');
    await expect(page.locator('#f_text')).toHaveValue('default text');
    await expect(page.locator('#f_chk')).not.toBeChecked();
    await page.fill('#f_text', 'again');
    await page.fill('#f_num', '7');
    await expect(page.locator('#form_state')).toHaveText('again|7|FALSE|a');
    await page.click('#reset_one');
    await expect(page.locator('#form_state')).toHaveText('default text|7|FALSE|a');
  });

  test('functions are namespaced inside moduleServer', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#m1-msg')).toBeVisible();
    await page.click('#m1-toggle');
    await expect(page.locator('#m1-msg')).toBeHidden();
    await page.click('#m1-toggle');
    await expect(page.locator('#m1-msg')).toBeVisible();
    // top-level #target is untouched by the module's toggle
    await expect(page.locator('#target')).toBeVisible();
    await page.click('#m1-paint');
    await expect(page.locator('#m1-box')).toHaveCSS('background-color', 'rgb(0, 128, 0)');
    await page.click('#m1-disable');
    await expect(page.locator('#m1-txt')).toBeDisabled();
    await expect(page.locator('#name')).toBeEnabled();
    await page.click('#m1-msg');
    await expect(page.locator('#m1-clicked')).toHaveText('module msg clicked');
    await page.locator('#m1-txt').evaluate((el: HTMLInputElement) => { el.disabled = false; });
    await page.fill('#m1-txt', 'edited');
    await expect(page.locator('#m1-txt_value')).toHaveText('mod txt=edited');
    await page.click('#m1-reset');
    await expect(page.locator('#m1-txt_value')).toHaveText('mod txt=mod');
    await settle(page);
  });
});
