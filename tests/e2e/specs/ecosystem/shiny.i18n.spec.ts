import { test, expect, waitForIdle } from '../../helpers/fixtures';
import { Page } from '@playwright/test';

test.use({ fixture: 'eco-shiny.i18n' });

const pick = (page: Page, lang: string) =>
  page.evaluate((l) => (window as any).$('#picker-lang')[0].selectize.setValue(l), lang);

test.describe('shiny.i18n', () => {
  test('static UI is translated in the browser by update_lang()', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#hello')).toHaveText('Hello');
    await expect(page.locator('#bye')).toHaveText('Goodbye');
    await pick(page, 'es');
    await expect(page.locator('#hello')).toHaveText('Hola');
    await expect(page.locator('#bye')).toHaveText('Adiós');
    await expect(page.locator('#picker-lang-label')).toHaveText('Idioma');
    await pick(page, 'pl');
    await expect(page.locator('#hello')).toHaveText('Cześć');
    await pick(page, 'en');
    await expect(page.locator('#hello')).toHaveText('Hello');
  });

  test('server-side translations re-render reactively', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#server_text')).toHaveText('Server says: Hello');
    await expect(page.locator('#dyn')).toHaveText('Goodbye');
    await pick(page, 'es');
    await expect(page.locator('#server_text')).toHaveText('El servidor dice: Hola');
    await expect(page.locator('#dyn')).toHaveText('Adiós');
  });

  test('language choice is per session', async ({ open, browser, app }) => {
    const page = await open();
    await pick(page, 'pl');
    await expect(page.locator('#server_text')).toHaveText('Serwer mówi: Cześć');
    const ctx = await browser.newContext();
    const other = await ctx.newPage();
    await other.goto(app.url);
    await waitForIdle(other);
    await expect(other.locator('#server_text')).toHaveText('Server says: Hello');
    await expect(other.locator('#hello')).toHaveText('Hello');
    await ctx.close();
  });
});
