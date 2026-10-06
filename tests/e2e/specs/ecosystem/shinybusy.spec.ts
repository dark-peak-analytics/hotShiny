import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinybusy' });

test.describe('shinybusy', () => {
  test('busy spinner follows shiny:busy / shiny:idle', async ({ open }) => {
    const page = await open();
    const spin = page.locator('.shinybusy:has(.sk-fading-circle)');
    await expect(spin).toHaveClass(/shinybusy-ready/);
    await expect(spin).toBeHidden();
    await page.click('#slow');
    await expect(spin).toHaveClass(/shinybusy-busy/);
    await expect(spin).toBeVisible();
    await expect(page.locator('#slow_done')).toHaveText('slow 1', { timeout: 15_000 });
    await expect(spin).toHaveClass(/shinybusy-ready/);
    await expect(spin).toBeHidden();
  });

  test('busy bar appears while busy', async ({ open }) => {
    const page = await open();
    await page.click('#slow');
    // nanobar appends a new .bar each time it restarts
    await expect(page.locator('.nanobar .bar').first()).toHaveCSS('background-color', 'rgb(255, 0, 0)');
    await expect(page.locator('#slow_done')).toHaveText('slow 1', { timeout: 15_000 });
    await settle(page);
  });

  test('show_modal_spinner, update_modal_spinner and remove_modal_spinner', async ({ open }) => {
    const page = await open();
    await page.click('#modal');
    const modal = page.locator('.modal.shinybusy-modal, .shinybusy-modal');
    await expect(page.locator('.shinybusy-modal-text')).toHaveText('Please wait...');
    await expect(page.locator('.shinybusy-modal-spinner .sk-cube-grid')).toBeVisible();
    await expect(page.locator('.shinybusy-modal-text')).toHaveText('Nearly done');
    await expect(page.locator('#modal_done')).toHaveText('modal done 1', { timeout: 15_000 });
    await expect(modal).toHaveCount(0);
    await expect(page.locator('#shiny-modal')).toHaveCount(0);
  });

  test('modal progress bar updates and is removed', async ({ open }) => {
    const page = await open();
    await page.click('#progress');
    await expect(page.locator('#shiny-modal')).toBeVisible();
    await expect(page.locator('#shiny-modal')).toContainText(/step [1-5]/);
    await expect(page.locator('#shinybusy-modal-progress svg')).toBeAttached();
    await expect(page.locator('#progress_done')).toHaveText('progress done', { timeout: 15_000 });
    await expect(page.locator('#shiny-modal')).toHaveCount(0);
  });

  test('notify and report (notiflix)', async ({ open }) => {
    const page = await open();
    await page.click('#notify');
    await expect(page.locator('.notiflix-notify-success')).toContainText('Saved!');
    await page.click('#report');
    const report = page.locator('[id^="NotiflixReportWrap"]');
    await expect(report).toBeVisible();
    await expect(report).toContainText('All good');
    await expect(report).toContainText('The report body');
    await report.getByText('Ok').click();
    await expect(report).toHaveCount(0);
    await settle(page);
  });
});
