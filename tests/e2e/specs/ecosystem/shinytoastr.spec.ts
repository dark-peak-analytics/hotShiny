import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinytoastr' });

test.describe('shinytoastr', () => {
  test('success toast with title and close button', async ({ open }) => {
    const page = await open();
    await page.click('#success');
    const toast = page.locator('#toast-container.toast-top-right .toast-success');
    await expect(toast).toBeVisible();
    await expect(toast.locator('.toast-title')).toHaveText('Yay');
    await expect(toast.locator('.toast-message')).toHaveText('It worked');
    await toast.locator('.toast-close-button').click();
    await expect(toast).toHaveCount(0);
  });

  test('position, progress bar and ordering options', async ({ open }) => {
    const page = await open();
    await page.click('#error');
    const err = page.locator('#toast-container.toast-bottom-left .toast-error');
    await expect(err).toContainText('It broke');
    await expect(err.locator('.toast-progress')).toBeAttached();
    await err.click();
    await expect(err).toHaveCount(0);
    await settle(page);
    await page.click('#info');
    await expect(page.locator('.toast-info')).toHaveCount(1);
    await page.click('#info');
    await expect(page.locator('.toast-info')).toHaveCount(2);
    await expect(page.locator('.toast-info .toast-message').first()).toHaveText('info 2');
  });

  test('timeOut hides the toast; module toasts work', async ({ open }) => {
    const page = await open();
    await page.click('#quick');
    await expect(page.locator('.toast-success')).toContainText('gone soon');
    await expect(page.locator('.toast-success')).toHaveCount(0, { timeout: 5000 });
    await page.click('#m-warn');
    await expect(page.locator('.toast-warning .toast-message')).toHaveText('module warning 1');
  });
});
