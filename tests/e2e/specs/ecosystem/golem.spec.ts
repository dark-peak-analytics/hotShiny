import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-golem' });

test.describe('golem', () => {
  test('golem_opts reach the UI and the server', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#title')).toHaveText('Golem on hotShiny');
    await expect(page.locator('#ui_opts')).toHaveText('ui sees n=5 prod=TRUE');
    await expect(page.locator('#config')).toHaveText('Hello from golem-config.yml');
    await expect(page.locator('#server_opts')).toHaveText('server sees title=Golem on hotShiny n=5 all=n,title');
    await expect(page).toHaveTitle('ecogolem');
  });

  test('bundled www resources and golem JS handlers', async ({ open }) => {
    const page = await open();
    await expect(page.locator('body')).toHaveAttribute('data-golem-script', 'loaded');
    await expect(page.locator('.golem-counter').first()).toHaveCSS('border-left-color', 'rgb(30, 120, 200)');
    await expect(page.locator('#target')).toBeVisible();
    await page.click('#hide');
    await expect(page.locator('#target')).toBeHidden();
    await page.click('#show');
    await expect(page.locator('#target')).toBeVisible();
  });

  test('modules count independently with the step from golem_opts', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#counter_1-count')).toHaveText('counter_1-count=0');
    await page.click('#counter_1-inc');
    await page.click('#counter_1-inc');
    await page.click('#counter_2-inc');
    await expect(page.locator('#counter_1-count')).toHaveText('counter_1-count=2');
    await expect(page.locator('#counter_2-count')).toHaveText('counter_2-count=5');
    await expect(page.locator('#total')).toHaveText('total=7');
  });
});
