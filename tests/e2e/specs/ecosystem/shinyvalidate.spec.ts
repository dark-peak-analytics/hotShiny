import { test, expect, settle, waitForIdle } from '../../helpers/fixtures';
import { Page } from '@playwright/test';

test.use({ fixture: 'eco-shinyvalidate' });

const messageOf = (page: Page, id: string) =>
  page.locator(`.shiny-input-container:has(#${id}) .shiny-validation-message`);

test.describe('shinyvalidate', () => {
  test('no messages until enable(), then messages per rule', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#valid')).toHaveText('valid: FALSE');
    await expect(page.locator('.shiny-validation-message')).toHaveCount(0);
    await page.click('#submit');
    await expect(page.locator('#submitted')).toHaveText('fix errors');
    await expect(messageOf(page, 'name')).toHaveText('Required');
    await expect(messageOf(page, 'email')).toHaveText('Required');
    await expect(messageOf(page, 'age')).toHaveText('Must be 18 or older');
    await expect(page.locator('.shiny-input-container:has(#name)')).toHaveClass(/has-error/);
    // condition() is FALSE: the child validator does not report
    await expect(messageOf(page, 'phone')).toHaveCount(0);
  });

  test('messages update live and is_valid() turns TRUE', async ({ open }) => {
    const page = await open();
    await page.click('#submit');
    await page.fill('#name', 'Ada');
    await expect(messageOf(page, 'name')).toHaveCount(0);
    await page.fill('#email', 'not-an-email');
    await expect(messageOf(page, 'email')).toHaveText(/valid email/i);
    await page.fill('#email', 'ada@example.com');
    await expect(messageOf(page, 'email')).toHaveCount(0);
    await page.fill('#age', '30');
    await expect(messageOf(page, 'age')).toHaveCount(0);
    await expect(page.locator('#valid')).toHaveText('valid: TRUE');
    await page.check('#has_phone');
    await expect(messageOf(page, 'phone')).toHaveText('Phone is required');
    await expect(page.locator('#valid')).toHaveText('valid: FALSE');
    await page.fill('#phone', '12ab');
    await expect(messageOf(page, 'phone')).toHaveText('Digits only');
    await page.fill('#phone', '1234');
    await expect(messageOf(page, 'phone')).toHaveCount(0);
    await expect(page.locator('#valid')).toHaveText('valid: TRUE');
    await page.click('#submit');
    await expect(page.locator('#submitted')).toHaveText('submitted Ada');
  });

  test('validator state is per session (two browser contexts)', async ({ open, browser, app }) => {
    const page = await open();
    const ctx = await browser.newContext();
    const other = await ctx.newPage();
    await other.goto(app.url);
    await waitForIdle(other);

    await page.click('#submit');
    await expect(messageOf(page, 'name')).toHaveText('Required');
    await settle(other);
    // enabling in one session must not show messages in the other
    await expect(other.locator('.shiny-validation-message')).toHaveCount(0);

    await other.fill('#name', 'Bob');
    await other.fill('#email', 'bob@example.com');
    await other.fill('#age', '40');
    await expect(other.locator('#valid')).toHaveText('valid: TRUE');
    await expect(page.locator('#valid')).toHaveText('valid: FALSE');
    await expect(messageOf(page, 'name')).toHaveText('Required');

    await other.click('#submit');
    await expect(other.locator('#submitted')).toHaveText('submitted Bob');
    await expect(other.locator('.shiny-validation-message')).toHaveCount(0);
    await expect(page.locator('#submitted')).toHaveText('fix errors');
    await page.fill('#name', 'Ada');
    await expect(messageOf(page, 'name')).toHaveCount(0);
    await expect(other.locator('#name')).toHaveValue('Bob');
    await ctx.close();
  });
});
