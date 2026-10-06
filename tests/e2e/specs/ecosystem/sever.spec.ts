import { test, expect, waitForIdle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-sever' });

test.describe('sever', () => {
  test('sever() message replaces the grey-out when session$close() is called', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#session_info')).toHaveText('session alive');
    await expect(page.locator('.severed')).toHaveCount(0);
    await page.click('#close');
    const severed = page.locator('.severed');
    await expect(severed).toBeVisible();
    await expect(severed).toContainText('Gone');
    await expect(severed).toContainText('The session was closed');
    await expect(severed).toHaveCSS('color', 'rgb(255, 255, 255)');
    await expect(page.locator('#shiny-disconnected-overlay')).toHaveCSS('background-color', 'rgb(10, 20, 30)');
    // shiny's own reconnect dialog is hidden by sever's css
    await expect(page.locator('#ss-connect-dialog')).toBeHidden();
    expect(await page.evaluate(() => (window as any).Shiny.shinyapp.isConnected())).toBe(false);

    await severed.getByText('Reconnect now').click();
    await page.waitForLoadState('load');
    await waitForIdle(page);
    await expect(page.locator('#session_info')).toHaveText('session alive');
    await expect(page.locator('.severed')).toHaveCount(0);
  });

  test('cleave() overlays an output that errors', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#maybe')).toHaveText('output fine');
    await page.click('#fail');
    await expect(page.locator('#maybe #cleaved')).toHaveText('Output broke');
    await expect(page.locator('#maybe .cleave-overlay')).toHaveCSS('background-color', 'rgb(250, 240, 230)');
  });
});
