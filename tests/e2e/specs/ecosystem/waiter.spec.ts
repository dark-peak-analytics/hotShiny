import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-waiter' });

test.describe('waiter', () => {
  test('waiter_show, waiter_update and waiter_hide cover the page while the observer runs', async ({ open }) => {
    const page = await open();
    await expect(page.locator('.waiter-overlay')).toHaveCount(0);
    await page.click('#full');
    const overlay = page.locator('.waiter-overlay.waiter-fullscreen');
    await expect(overlay).toBeVisible();
    await expect(page.locator('#full-msg')).toHaveText('Loading everything');
    await expect(overlay.locator('.sk-fading-circle, [class*="fading"]').first()).toBeAttached();
    await expect(page.locator('#full-msg')).toHaveText('Almost there');
    await expect(page.locator('#full_done')).toHaveText('full done 1', { timeout: 15_000 });
    await expect(overlay).toHaveCount(0);
  });

  test('Waiter on an output hides itself when the output renders', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#plot img')).toBeVisible();
    await page.click('#redraw');
    const overlay = page.locator('#plot .waiter-overlay');
    await expect(overlay).toBeVisible();
    await expect(page.locator('#plot-msg')).toHaveText('Plot loading');
    await expect(overlay).toHaveCSS('background-color', 'rgba(0, 0, 255, 0.5)');
    await expect(overlay).toHaveCount(0, { timeout: 15_000 });
    await expect(page.locator('#plot img')).toBeVisible();
    await settle(page);
  });

  test('w$show() and w$hide() on a plain element', async ({ open }) => {
    const page = await open();
    await page.click('#manual');
    await expect(page.locator('#box .waiter-overlay')).toBeVisible();
    await expect(page.locator('#box-msg')).toHaveText('Box busy');
    await settle(page);
    // not tied to rendering: stays until hidden explicitly
    await expect(page.locator('#box .waiter-overlay')).toBeVisible();
    await page.click('#manual_hide');
    await expect(page.locator('#box .waiter-overlay')).toHaveCount(0);
  });

  test('autoWaiter follows shiny:recalculating', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#auto_txt')).toHaveText('auto 0');
    await settle(page);
    await page.click('#auto');
    await expect(page.locator('#auto_txt .waiter-overlay')).toBeVisible();
    await expect(page.locator('#auto_txt .waiter-overlay')).toContainText('auto waiting');
    await expect(page.locator('#auto_txt')).toHaveText('auto 1', { timeout: 15_000 });
    await expect(page.locator('#auto_txt .waiter-overlay')).toHaveCount(0);
  });

  test('Waitress progress bar', async ({ open }) => {
    const page = await open();
    await page.click('#progress');
    // progressjs marks the target and draws its bar in a body-level container
    await expect(page.locator('#box')).toHaveAttribute('data-progressjs', /\d+/);
    await expect(page.locator('.progressjs-container .progressjs-progress')).toBeAttached();
    await expect(page.locator('#progress_done')).toHaveText('progress done', { timeout: 15_000 });
    await expect(page.locator('#box')).not.toHaveAttribute('data-progressjs');
    await settle(page);
  });
});
