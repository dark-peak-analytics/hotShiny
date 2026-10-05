import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'dynamic-ui' });

test.describe('dynamic UI', () => {
  test('insertUI and removeUI', async ({ open }) => {
    const page = await open();
    await page.click('#add');
    await page.click('#add');
    await expect(page.locator('#items .inserted-item')).toHaveCount(2);
    await expect(page.locator('#item_count')).toHaveText('items=2');
    await page.click('#remove');
    await expect(page.locator('#items .inserted-item')).toHaveCount(1);
    await expect(page.locator('#item1')).toHaveText('Item 1');
  });

  test('modal with inputs, removeModal', async ({ open }) => {
    const page = await open();
    await page.click('a[data-value="Modals"]');
    await page.click('#show_modal');
    const modal = page.locator('#shiny-modal');
    await expect(modal).toBeVisible();
    await expect(modal.locator('.modal-title')).toHaveText('A modal');
    await expect(page.locator('#modal_value')).toHaveText('modal_text=typed in modal');
    await modal.locator('#modal_text').fill('changed in modal');
    await expect(page.locator('#modal_value')).toHaveText('modal_text=changed in modal');
    await modal.locator('#modal_ok').click();
    await expect(modal).toBeHidden();
  });

  test('notifications and progress', async ({ open }) => {
    const page = await open();
    await page.click('a[data-value="Modals"]');
    await page.click('#notify');
    const note = page.locator('#shiny-notification-note1');
    await expect(note).toBeVisible();
    await expect(note).toHaveClass(/shiny-notification-warning/);
    await expect(note).toContainText('Hello notification');
    await page.click('#progress');
    await expect(page.locator('.shiny-notification .progress-message')).toHaveText('Working');
    await expect(page.locator('#progress_done')).toHaveText('progress=done');
    await expect(page.locator('.shiny-progress-notification')).toHaveCount(0);
  });

  test('conditionalPanel follows inputs', async ({ open }) => {
    const page = await open();
    await page.click('a[data-value="Conditional"]');
    await expect(page.locator('#extra')).toBeHidden();
    await page.locator('#show_extra').check();
    await expect(page.locator('#extra')).toBeVisible();
    await expect(page.locator('#beta-only')).toBeHidden();
    await page.locator('#pick + .selectize-control .selectize-input').click();
    await page.locator('#pick + .selectize-control .option[data-value="beta"]').click();
    await expect(page.locator('#beta-only')).toBeVisible();
  });

  test('tabs: navbarMenu, updateTabsetPanel, appendTab', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#nav')).toBeVisible();
    await page.click('a.dropdown-toggle:has-text("More")');
    await page.click('a[data-value="Tabs"]');
    await expect(page.locator('#inner_value')).toHaveText('inner=first');
    await page.click('#to_second');
    await expect(page.locator('#inner_value')).toHaveText('inner=second');
    await expect(page.locator('text=Second tab body')).toBeVisible();
    await page.click('#add_tab');
    await expect(page.locator('#inner_value')).toHaveText('inner=third');
    await expect(page.locator('text=Third tab body')).toBeVisible();
    await page.click('#inner a[data-value="first"]');
    await expect(page.locator('#inner_value')).toHaveText('inner=first');
  });
});
