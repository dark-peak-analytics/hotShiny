import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinyace' });

test.describe('shinyAce', () => {
  test('initial value', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#o_ed')).toHaveText('ed=x <- 1');
    await expect(page.locator('#ed .ace_content')).toContainText('x <- 1');
  });

  test('typing in the editor updates the input', async ({ open }) => {
    const page = await open();
    await page.locator('#ed .ace_content').click();
    await page.keyboard.press('End');
    await page.keyboard.type(' + 41');
    await expect(page.locator('#o_ed')).toHaveText('ed=x <- 1 + 41');
  });

  test('updateAceEditor value and mode', async ({ open }) => {
    const page = await open();
    await page.click('#upd');
    await expect(page.locator('#o_ed')).toHaveText('ed=y <- 2\\nz <- 3');
    await expect(page.locator('#ed .ace_line')).toHaveCount(2);
    await page.click('#mode');
    await expect
      .poll(() => page.evaluate(() => (window as any).ace.edit('ed').getSession().getMode().$id))
      .toBe('ace/mode/python');
  });

  test('aceAutocomplete serves R completions from the server', async ({ open }) => {
    const page = await open();
    await page.locator('#ed .ace_content').click();
    await page.keyboard.press('End');
    await page.keyboard.press('Enter');
    await page.keyboard.type('paste');
    await page.keyboard.press('Control+Space');
    const popup = page.locator('.ace_autocomplete');
    await expect(popup).toBeVisible();
    await expect(popup).toContainText('paste0');
  });

  test('read-only editor ignores typing', async ({ open }) => {
    const page = await open();
    await page.locator('#ro .ace_content').click();
    await page.keyboard.type('zzz');
    await expect(page.locator('#ro .ace_content')).toHaveText('read only');
  });
});
