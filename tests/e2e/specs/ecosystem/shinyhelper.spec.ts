import { test, expect, settle } from '../../helpers/fixtures';
import { Page } from '@playwright/test';

test.use({ fixture: 'eco-shinyhelper' });

const iconFor = (page: Page, id: string) => page.locator(`.shinyhelper-wrapper:has(#${id}) .shinyhelper-icon`);

test.describe('shinyhelper', () => {
  test('markdown helpfile is read from help_dir and shown in a modal', async ({ open }) => {
    const page = await open();
    await iconFor(page, 'bins').click();
    const modal = page.locator('#shiny-modal');
    await expect(modal).toBeVisible();
    await expect(modal.locator('h2')).toHaveText('Slider help');
    await expect(modal.locator('strong')).toHaveText('how many');
    await modal.getByRole('button', { name: 'Okay' }).click();
    await expect(modal).toBeHidden();
  });

  test('inline helper uses title, content, size and button label', async ({ open }) => {
    const page = await open();
    await iconFor(page, 'name').click();
    const modal = page.locator('#shiny-modal');
    await expect(modal.locator('.modal-title')).toHaveText('About names');
    await expect(modal.locator('.modal-body b')).toHaveText('your');
    await expect(modal.locator('.modal-body')).toContainText('Second line.');
    await expect(modal.locator('.modal-dialog')).toHaveClass(/modal-sm/);
    await modal.getByRole('button', { name: 'Got it' }).click();
    await expect(modal).toBeHidden();
  });

  test('missing helpfile and helpers inside renderUI', async ({ open }) => {
    const page = await open();
    await expect(iconFor(page, 'missing')).toHaveCSS('color', 'rgb(255, 0, 0)');
    await iconFor(page, 'missing').click();
    const modal = page.locator('#shiny-modal');
    await expect(modal.locator('.modal-title')).toHaveText('Helpfile Not Found');
    await page.keyboard.press('Escape');
    await expect(modal).toBeHidden();
    await settle(page);
    await expect(page.locator('#dyn')).toBeAttached();
    // shinyhelper binds dynamic icons 500ms after shiny:value
    await page.waitForTimeout(700);
    await iconFor(page, 'dyn').click();
    await expect(page.locator('#shiny-modal .modal-title')).toHaveText('Dynamic help');
    await expect(page.locator('#shiny-modal .modal-body')).toContainText('Rendered by renderUI');
  });
});
