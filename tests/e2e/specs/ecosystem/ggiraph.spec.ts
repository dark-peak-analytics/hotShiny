import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-ggiraph' });

const point = (name: string) => `#plot svg [data-id="${name}"]`;

test.describe('ggiraph', () => {
  test('girafe renders interactive points', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#plot .ggiraph-toolbar')).toHaveCount(1);
    await expect(page.locator('#plot svg [data-id]')).toHaveCount(8);
    await expect(page.locator('#selected')).toHaveText('selected:');
  });

  test('clicking points feeds input$<id>_selected', async ({ open }) => {
    const page = await open();
    await page.locator(point('Datsun 710')).click();
    await expect(page.locator('#selected')).toHaveText('selected: Datsun 710');
    await page.locator(point('Valiant')).click();
    await expect(page.locator('#selected')).toHaveText('selected: Datsun 710,Valiant');
    await page.locator(point('Datsun 710')).click();
    await expect(page.locator('#selected')).toHaveText('selected: Valiant');
  });

  test('server sets the selection with <id>_set messages', async ({ open }) => {
    const page = await open();
    await page.click('#select_two');
    await expect(page.locator('#selected')).toHaveText('selected: Mazda RX4,Valiant');
    await expect(page.locator(point('Mazda RX4'))).toHaveClass(/select_data/);
    await settle(page);
    await page.click('#reset');
    await expect(page.locator('#selected')).toHaveText('selected:');
  });

  test('tooltip on hover', async ({ open }) => {
    const page = await open();
    await page.locator(point('Hornet 4 Drive')).hover();
    await expect(page.locator('.girafe_tooltip_plot, [class*="tooltip_"]').filter({ hasText: 'Hornet 4 Drive' }).first())
      .toBeVisible();
  });
});
