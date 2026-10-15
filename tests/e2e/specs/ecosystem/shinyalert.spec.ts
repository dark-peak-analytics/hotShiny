import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinyalert' });

const alert = '.sweet-alert.visible';

test.describe('shinyalert', () => {
  test('simple alert opens and closes', async ({ open }) => {
    const page = await open();
    await page.click('#simple');
    await expect(page.locator(alert)).toBeVisible();
    await expect(page.locator(alert + ' h2')).toHaveText('Hello');
    await expect(page.locator(alert)).toContainText('A simple alert');
    await expect(page.locator(alert + ' .sa-icon.sa-success')).toBeVisible();
    await page.locator(alert + ' button.confirm').click();
    await expect(page.locator(alert)).toHaveCount(0);
  });

  test('callbackR receives confirm and cancel', async ({ open }) => {
    const page = await open();
    await page.click('#confirm');
    await page.locator(alert + ' button.confirm').click();
    await expect(page.locator('#confirm_result')).toHaveText('confirmed: TRUE');
    await settle(page);
    await page.click('#confirm');
    await page.locator(alert + ' button.cancel').click();
    await expect(page.locator('#confirm_result')).toHaveText('confirmed: FALSE');
  });

  test('input alert sets input$<inputId> and calls back with the text', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#input_value')).toHaveText('input$name_alert = NULL');
    await page.click('#prompt');
    const field = page.locator(alert + ' input[type="text"]');
    await expect(field).toHaveAttribute('placeholder', 'type here');
    await field.fill('Ada');
    await page.locator(alert + ' button.confirm').click();
    await expect(page.locator('#prompt_result')).toHaveText('hello Ada');
    await expect(page.locator('#input_value')).toHaveText('input$name_alert = Ada');
  });

  test('HTML alert binds shiny inputs and outputs inside it', async ({ open }) => {
    const page = await open();
    await page.click('#html');
    await expect(page.locator(alert + ' #inside')).toHaveValue('abc');
    await expect(page.locator(alert + ' #inside_echo')).toHaveText('echo abc');
    await page.locator(alert + ' #inside').fill('xyz');
    await expect(page.locator(alert + ' #inside_echo')).toHaveText('echo xyz');
    await page.locator(alert + ' button.confirm').click();
    await expect(page.locator(alert)).toHaveCount(0);
  });

  test('chained alerts from callbackR', async ({ open }) => {
    const page = await open();
    await page.click('#chain');
    await expect(page.locator(alert + ' h2')).toHaveText('First');
    await page.locator(alert + ' button.confirm').click();
    await expect(page.locator(alert + ' h2')).toHaveText('Second');
    await page.locator(alert + ' button.confirm').click();
    await expect(page.locator('#chain_result')).toHaveText('chain finished');
  });

  test('inputId and callbackR are namespaced in a module', async ({ open }) => {
    const page = await open();
    await page.click('#m-ask');
    await page.locator(alert + ' button.cancel').click();
    await expect(page.locator('#m-answer')).toHaveText(/module (callback|input) FALSE/);
    expect(await page.evaluate(() => (window as any).Shiny.shinyapp.$inputValues['m-modq'])).toBe(false);
  });
});
