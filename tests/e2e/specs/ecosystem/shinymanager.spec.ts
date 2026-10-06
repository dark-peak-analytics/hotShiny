import { Page } from '@playwright/test';
import { test, expect, waitForIdle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinymanager' });

async function login(page: Page, user: string, pwd: string) {
  await page.fill('#auth-user_id', user);
  await page.fill('#auth-user_pwd', pwd);
  await page.click('#auth-go_auth');
}

test.describe('shinymanager', () => {
  test('the app is hidden behind the login form', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#auth-user_id')).toBeVisible();
    await expect(page.locator('#auth-user_pwd')).toBeVisible();
    await expect(page.locator('#app_title')).toHaveCount(0);
    await expect(page.locator('#doubled')).toHaveCount(0);
  });

  test('wrong credentials are rejected', async ({ open }) => {
    const page = await open();
    await login(page, 'alice', 'nope');
    await expect(page.locator('#auth-result_auth')).toContainText('Username or password are incorrect');
    await expect(page.locator('#app_title')).toHaveCount(0);
    await login(page, 'mallory', 'wonderland');
    await expect(page.locator('#auth-result_auth')).toContainText('Username or password are incorrect');
  });

  test('login reloads into the app with the user info', async ({ open }) => {
    const page = await open();
    await login(page, 'alice', 'wonderland');
    await page.waitForURL(/token=/);
    await waitForIdle(page);
    await expect(page.locator('#app_title')).toHaveText('Secured app');
    await expect(page.locator('#auth_info')).toHaveText('user=alice role=analyst admin=FALSE');
    await expect(page.locator('#doubled')).toHaveText('doubled=4');
    await page.fill('#n', '21');
    await expect(page.locator('#doubled')).toHaveText('doubled=42');
    await expect(page.locator('#auth-user_id')).toHaveCount(0);
  });

  test('logout returns to the login form', async ({ open }) => {
    const page = await open();
    await login(page, 'bob', 'builder');
    await page.waitForURL(/token=/);
    await waitForIdle(page);
    await expect(page.locator('#auth_info')).toHaveText('user=bob role=manager admin=TRUE');
    await page.locator('.mfb-component__button--main').hover();
    await page.click('#\\.shinymanager_logout');
    await page.waitForURL((u) => !/token=/.test(u.toString()));
    await waitForIdle(page);
    await expect(page.locator('#auth-user_id')).toBeVisible();
    await expect(page.locator('#app_title')).toHaveCount(0);
  });

  test('a token from another session does not leak', async ({ open, browser, app }) => {
    const page = await open();
    await login(page, 'alice', 'wonderland');
    await page.waitForURL(/token=/);
    await waitForIdle(page);
    const ctx = await browser.newContext();
    const other = await ctx.newPage();
    await other.goto(app.url);
    await waitForIdle(other);
    await expect(other.locator('#auth-user_id')).toBeVisible();
    await expect(other.locator('#app_title')).toHaveCount(0);
    await ctx.close();
  });
});
