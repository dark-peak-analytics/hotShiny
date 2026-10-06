import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-cicerone' });

test.describe('cicerone', () => {
  test('guide starts, switches tabs and reports steps to R', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#current_tab')).toHaveText('tab A');
    await page.click('#tour');
    const popover = page.locator('#driver-popover-item');
    await expect(popover).toBeVisible();
    await expect(popover.locator('.driver-popover-title')).toHaveText('Start');
    await expect(popover.locator('.driver-popover-description')).toHaveText('This starts the guide');
    await expect(page.locator('#tour')).toHaveClass(/driver-highlighted-element/);

    await popover.getByText('Next one').click();
    await expect(popover.locator('.driver-popover-title')).toHaveText('Name');
    await expect(page.locator('#next_el')).toHaveText(/left tour has_next TRUE/);

    await popover.getByText('Next one').click();
    await expect(popover.locator('.driver-popover-title')).toHaveText('Last');
    // R switched the tabset when it saw the guide leave 'name'
    await expect(page.locator('#b_content')).toBeVisible();
    await expect(page.locator('#current_tab')).toHaveText('tab B');

    await popover.getByText('All done').click();
    await expect(popover).toBeHidden();
    await expect(page.locator('#driver-page-overlay')).toHaveCount(0);
  });
});
