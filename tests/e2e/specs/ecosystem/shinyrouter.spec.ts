import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-shinyrouter' });

const visibleHeading = (page: any) => page.locator('h3:visible');

test.describe('shiny.router', () => {
  test('starts on the root page', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#o_page')).toHaveText('page=/');
    await expect(visibleHeading(page)).toHaveText('Home page');
    await expect(page.locator('#o_home')).toHaveText('home output');
  });

  test('hash links navigate and outputs on the new page render', async ({ open }) => {
    const page = await open();
    await page.click('#lnk_other');
    await expect(page).toHaveURL(/#!\/other$/);
    await expect(page.locator('#o_page')).toHaveText('page=other');
    await expect(visibleHeading(page)).toHaveText('Other page');
    await page.fill('#other_txt', 'typed');
    await expect(page.locator('#o_other')).toHaveText('other=typed');
    await page.click('#lnk_home');
    await expect(page.locator('#o_page')).toHaveText('page=/');
    await expect(visibleHeading(page)).toHaveText('Home page');
  });

  test('query parameters and browser history', async ({ open }) => {
    const page = await open();
    await page.click('#lnk_params');
    await expect(page.locator('#o_page')).toHaveText('page=params');
    await expect(page.locator('#o_params')).toHaveText('x=7 y=b');
    await page.goBack();
    await expect(page.locator('#o_page')).toHaveText('page=/');
    await page.goForward();
    await expect(page.locator('#o_page')).toHaveText('page=params');
  });

  test('deep link, unknown page and server-side change_page', async ({ open }) => {
    const page = await open('#!/other');
    await expect(page.locator('#o_page')).toHaveText('page=other');
    await expect(visibleHeading(page)).toHaveText('Other page');
    await page.evaluate(() => (window.location.hash = '#!/nowhere'));
    await expect(visibleHeading(page)).toHaveText('Not found');
    await page.click('#go_other');
    await expect(page).toHaveURL(/#!\/other$/);
    await expect(page.locator('#o_page')).toHaveText('page=other');
  });
});
