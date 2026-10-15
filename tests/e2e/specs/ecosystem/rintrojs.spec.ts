import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'eco-rintrojs' });

test.describe('rintrojs', () => {
  test('introBox annotates elements for intro.js', async ({ open }) => {
    const page = await open();
    await expect(page.locator('[data-step="1"]')).toHaveAttribute('data-intro', 'This button starts the tour');
    await expect(page.locator('[data-step="2"]')).toHaveAttribute('data-intro', 'Type your name here');
  });

  test('introjs() starts a tour from the server and oncomplete reaches R', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#tour_state')).toHaveText('tour not finished');
    await page.click('#tour');
    const tooltip = page.locator('.introjs-tooltip');
    await expect(tooltip).toBeVisible();
    await expect(tooltip.locator('.introjs-tooltiptext')).toHaveText('This button starts the tour');
    await expect(page.locator('#tour')).toHaveClass(/introjs-showElement/);
    await tooltip.getByText('Onward').click();
    await expect(tooltip.locator('.introjs-tooltiptext')).toHaveText('Type your name here');
    await tooltip.getByText('Back').click();
    await expect(tooltip.locator('.introjs-tooltiptext')).toHaveText('This button starts the tour');
    await tooltip.getByText('Onward').click();
    await tooltip.getByText('Onward').click();
    await expect(tooltip.locator('.introjs-tooltiptext')).toHaveText('Defined in R');
    await tooltip.getByText('Finish').click();
    await expect(page.locator('.introjs-overlay')).toHaveCount(0);
    await expect(page.locator('#tour_state')).toHaveText('tour finished');
  });
});
