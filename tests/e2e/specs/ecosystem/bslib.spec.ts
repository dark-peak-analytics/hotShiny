import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'bslib' });

const bodyBg = (page: any) => page.evaluate(() => getComputedStyle(document.body).backgroundColor);

test.describe('bslib', () => {
  test('value box and plot follow the slider', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#bins_txt')).toHaveText('20');
    await expect(page.locator('#hist img')).toHaveAttribute('src', /^data:image\/png/);
    const src = () => page.evaluate(() => document.querySelector('#hist img')!.getAttribute('src'));
    const before = await src();
    await page.evaluate(() => (window as any).Shiny.setInputValue('bins', 6));
    await expect(page.locator('#bins_txt')).toHaveText('6');
    await expect.poll(async () => (await src()) !== before).toBe(true);
  });

  test('initial input values of sidebar, navset, accordion and switches', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#state')).toHaveText('sb=TRUE cards=First acc=A dark=FALSE mode=light');
  });

  test('sidebar toggles from the client and from toggle_sidebar()', async ({ open }) => {
    const page = await open();
    await page.locator('.bslib-sidebar-layout > .collapse-toggle').click();
    await expect(page.locator('#state')).toHaveText(/^sb=FALSE /);
    await expect(page.locator('.bslib-sidebar-layout')).toHaveClass(/sidebar-collapsed/);
    await page.locator('.bslib-sidebar-layout > .collapse-toggle').click();
    await expect(page.locator('#state')).toHaveText(/^sb=TRUE /);
    await page.click('#close_sb');
    await expect(page.locator('#state')).toHaveText(/^sb=FALSE /);
    await expect(page.locator('.bslib-sidebar-layout')).toHaveClass(/sidebar-collapsed/);
  });

  test('navset_card_tab: click, nav_select, nav_insert and nav_remove', async ({ open }) => {
    const page = await open();
    const tabs = page.locator('#cards');
    await tabs.getByRole('tab', { name: 'Third' }).click();
    await expect(page.locator('#state')).toHaveText(/ cards=third /);
    await expect(page.getByText('Third panel')).toBeVisible();
    await page.click('#go_second');
    await expect(page.locator('#state')).toHaveText(/ cards=Second /);
    await expect(page.getByText('Second panel')).toBeVisible();
    await expect(page.getByText('Third panel')).toBeHidden();
    await page.click('#add_tab');
    await expect(tabs.getByRole('tab', { name: 'Added' })).toBeVisible();
    await expect(page.locator('#state')).toHaveText(/ cards=added /);
    await expect(page.getByText('Added panel')).toBeVisible();
    await page.click('#remove_first');
    await expect(tabs.getByRole('tab', { name: 'First' })).toHaveCount(0);
    await expect(tabs.getByRole('tab')).toHaveText(['Second', 'Third', 'Added']);
  });

  test('accordion reports open panels and opens from the server', async ({ open }) => {
    const page = await open();
    await page.getByRole('button', { name: 'B', exact: true }).click();
    await expect(page.locator('#state')).toHaveText(/ acc=A,B /);
    await page.getByRole('button', { name: 'A', exact: true }).click();
    await expect(page.locator('#state')).toHaveText(/ acc=B /);
    await expect(page.getByText('Panel A body')).toBeHidden();
    await page.getByRole('button', { name: 'B', exact: true }).click();
    await expect(page.locator('#state')).toHaveText(/ acc= /);
    await page.click('#open_b');
    await expect(page.locator('#state')).toHaveText(/ acc=B /);
    await expect(page.getByText('Panel B body')).toBeVisible();
  });

  test('input_switch drives session$setCurrentTheme(), update_switch() flips it', async ({ open }) => {
    const page = await open();
    expect(await bodyBg(page)).toBe('rgb(255, 255, 255)');
    await page.locator('label[for="dark"]').click();
    await expect(page.locator('#state')).toHaveText(/ dark=TRUE /);
    await expect.poll(() => bodyBg(page)).toBe('rgb(17, 17, 17)');
    await expect.poll(() => page.evaluate(() => getComputedStyle(document.body).color)).toBe('rgb(216, 216, 216)');
    // The primary colour survives the restyle.
    expect(await page.evaluate(() => getComputedStyle(document.querySelector('#task')!).backgroundColor))
      .toBe('rgb(123, 44, 191)');
    await page.click('#flip_switch');
    await expect(page.locator('#dark')).not.toBeChecked();
    await expect(page.locator('#state')).toHaveText(/ dark=FALSE /);
    await expect.poll(() => bodyBg(page)).toBe('rgb(255, 255, 255)');
    await settle(page);
  });

  test('input_dark_mode toggles the colour mode', async ({ open }) => {
    const page = await open();
    await expect(page.locator('html')).toHaveAttribute('data-bs-theme', 'light');
    await page.locator('#mode button').click();
    await expect(page.locator('html')).toHaveAttribute('data-bs-theme', 'dark');
    await expect(page.locator('#state')).toHaveText(/ mode=dark$/);
    await expect.poll(() => bodyBg(page)).not.toBe('rgb(255, 255, 255)');
    await page.locator('#mode button').click();
    await expect(page.locator('#state')).toHaveText(/ mode=light$/);
  });

  test('task button shows busy state while the ExtendedTask runs', async ({ open }) => {
    const page = await open();
    const btn = page.locator('#task');
    await expect(page.locator('#task_result')).toHaveText('');
    await btn.click();
    await expect(btn).toBeDisabled();
    await expect(btn.locator('bslib-switch-inline')).toHaveAttribute('case', 'busy');
    await expect(page.locator('#task_result')).toHaveText('task=40', { timeout: 5000 });
    await expect(btn).toBeEnabled();
    await expect(btn.locator('bslib-switch-inline')).toHaveAttribute('case', 'ready');
    await page.evaluate(() => (window as any).Shiny.setInputValue('bins', 7));
    await btn.click();
    await expect(page.locator('#task_result')).toHaveText('task=14', { timeout: 5000 });
  });
});
