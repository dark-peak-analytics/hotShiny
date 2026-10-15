import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinycssloaders' });

const spinnerOf = (id: string) => `.shiny-spinner-output-container:has(> #${id}) > .load-container`;
const placeholderOf = (id: string) => `.shiny-spinner-output-container:has(> #${id}) .shiny-spinner-placeholder`;

test.describe('shinycssloaders', () => {
  test('spinners are hidden once outputs have rendered', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#plot img')).toBeVisible();
    await expect(page.locator(spinnerOf('plot'))).toHaveClass(/shiny-spinner-hidden/);
    await expect(page.locator('#plot')).toHaveCSS('visibility', 'visible');
    await expect(page.locator('#maybe')).toHaveText('value is ok');
    await expect(page.locator(spinnerOf('maybe'))).toHaveClass(/shiny-spinner-hidden/);
    await expect(page.locator(placeholderOf('maybe'))).toHaveClass(/shiny-spinner-hidden/);
    await expect(page.locator('#tbl table')).toBeVisible();
  });

  test('spinner shows while a slow renderPlot recalculates', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#plot img')).toBeVisible();
    await page.click('#redraw');
    await expect(page.locator(spinnerOf('plot'))).not.toHaveClass(/shiny-spinner-hidden/);
    await expect(page.locator('#plot')).toHaveCSS('visibility', 'hidden');
    await expect(page.locator(spinnerOf('plot') + ' .loader')).toBeVisible();
    // hide.ui = FALSE keeps the old table visible under its spinner
    await expect(page.locator(spinnerOf('tbl'))).not.toHaveClass(/shiny-spinner-hidden/);
    await expect(page.locator('#tbl')).toHaveCSS('visibility', 'visible');
    await expect(page.locator(spinnerOf('plot'))).toHaveClass(/shiny-spinner-hidden/, { timeout: 15_000 });
    await expect(page.locator('#plot')).toHaveCSS('visibility', 'visible');
    await expect(page.locator(spinnerOf('tbl'))).toHaveClass(/shiny-spinner-hidden/);
    await settle(page);
  });

  test('spinner disappears when the output errors, and recovers', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#maybe')).toHaveText('value is ok');
    await page.click('#fail');
    await expect(page.locator(placeholderOf('maybe'))).not.toHaveClass(/shiny-spinner-hidden/);
    await expect(page.locator('#maybe')).toHaveClass(/shiny-output-error/, { timeout: 15_000 });
    await expect(page.locator('#maybe')).toHaveText('boom from server');
    await expect(page.locator(spinnerOf('maybe'))).toHaveClass(/shiny-spinner-hidden/);
    await expect(page.locator(placeholderOf('maybe'))).toHaveClass(/shiny-spinner-hidden/);
    await expect(page.locator('#maybe')).not.toHaveClass(/shiny-spinner-hidden/);
    await settle(page);
    await page.click('#recover');
    await expect(page.locator('#maybe')).toHaveText('value is ok', { timeout: 15_000 });
    await expect(page.locator('#maybe')).not.toHaveClass(/shiny-output-error/);
    await expect(page.locator(spinnerOf('maybe'))).toHaveClass(/shiny-spinner-hidden/);
  });

  test('showSpinner/hideSpinner and the page spinner', async ({ open }) => {
    const page = await open();
    await page.click('#manual_show');
    await expect(page.locator(spinnerOf('tbl'))).not.toHaveClass(/shiny-spinner-hidden/);
    await page.click('#manual_hide');
    await expect(page.locator(spinnerOf('tbl'))).toHaveClass(/shiny-spinner-hidden/);
    await settle(page);
    await page.click('#page');
    const overlay = page.locator('#shinycssloaders-global-spinner');
    await expect(overlay).toBeVisible();
    await expect(overlay).toContainText('Working on it');
    await expect(page.locator('#page_done')).toHaveText('page work done 1', { timeout: 15_000 });
    await expect(overlay).toHaveCount(0);
  });
});
