import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinyFeedback' });

test.describe('shinyFeedback', () => {
  test('showFeedbackDanger and hideFeedback', async ({ open }) => {
    const page = await open();
    const container = page.locator('.form-group:has(#num)');
    await expect(page.locator('#num-text')).toHaveCount(0);
    await page.fill('#num', '3');
    await expect(page.locator('#num-text')).toHaveText('Odd numbers are not allowed');
    await expect(page.locator('#num-text p')).toHaveCSS('color', 'rgb(217, 83, 79)');
    await expect(container).toHaveClass(/has-feedback/);
    await expect(container.locator('label')).toHaveCSS('color', 'rgb(217, 83, 79)');
    await expect(page.locator('#num')).toHaveCSS('border-top-color', 'rgb(217, 83, 79)');
    await expect(page.locator('#num-icon')).toBeAttached();
    await page.fill('#num', '4');
    await expect(page.locator('#num-text')).toHaveCount(0);
    await expect(page.locator('#num-icon')).toHaveCount(0);
    await expect(container).not.toHaveClass(/has-feedback/);
  });

  test('success feedback and feedbackDanger(show = condition)', async ({ open }) => {
    const page = await open();
    await page.fill('#word', 'hello');
    await expect(page.locator('#word-text')).toHaveText('Nice word');
    await expect(page.locator('#word-text p')).toHaveCSS('color', 'rgb(92, 184, 92)');
    await page.fill('#word', '');
    await expect(page.locator('#word-text')).toHaveCount(0);
    await page.evaluate(() => (window as any).$('#pick')[0].selectize.setValue('bad'));
    await expect(page.locator('#pick-text')).toHaveText('Bad pick');
    await page.evaluate(() => (window as any).$('#pick')[0].selectize.setValue('ok'));
    await expect(page.locator('#pick-text')).toHaveCount(0);
  });

  test('feedback is namespaced in a module', async ({ open }) => {
    const page = await open();
    await page.fill('#m-qty', '50');
    await expect(page.locator('#m-qty-text')).toHaveText('That is a lot');
    await expect(page.locator('#m-qty-text p')).toHaveCSS('color', 'rgb(248, 148, 6)');
    await page.fill('#m-qty', '5');
    await expect(page.locator('#m-qty-text')).toHaveCount(0);
  });

  test('loadingButton and resetLoadingButton, showToast', async ({ open }) => {
    const page = await open();
    await page.click('#save');
    await expect(page.locator('#save')).toContainText('Saving...');
    await expect(page.locator('#save')).toBeDisabled();
    await expect(page.locator('#saved')).toHaveText('saved 1', { timeout: 15_000 });
    await expect(page.locator('#save')).toContainText('Save');
    await expect(page.locator('#save')).not.toContainText('Saving');
    await expect(page.locator('#save')).toBeEnabled();
    await page.click('#toast');
    await expect(page.locator('.toast-success')).toContainText('Toasted!');
    await settle(page);
  });
});
