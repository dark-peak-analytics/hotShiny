import { test, expect, settle } from '../../helpers/fixtures';

// the date-time picker converts through the browser's time zone; pin it
test.use({ fixture: 'eco-shinywidgets-more', timezoneId: 'UTC' });

test.describe('more shinyWidgets inputs', () => {
  test('initial values (incl. typed input handlers)', async ({ open }) => {
    const page = await open();
    const expected: Record<string, string> = {
      o_cgb: 'character:p',
      o_ar: 'character:left',
      o_si: 'character:',
      o_nri: 'numeric:10,20',
      o_rng: 'Date:2024-05-01,2024-05-10',
      o_dt: 'character:2024-05-01 10:30 UTC',
      o_kn: 'integer:30',
    };
    for (const [id, value] of Object.entries(expected)) {
      await expect(page.locator(`#${id}`), id).toHaveText(value);
    }
  });

  test('interactions', async ({ open }) => {
    const page = await open();
    await page.locator('#cgb button:has(input[value="r"])').click();
    await expect(page.locator('#o_cgb')).toHaveText('character:p,r');
    await page.locator('#ar label:text-is("right")').click();
    await expect(page.locator('#o_ar')).toHaveText('character:right');

    await page.locator('#si_text').fill('needle');
    await page.locator('#si_text').press('Enter');
    await expect(page.locator('#o_si')).toHaveText('character:needle');
    await page.locator('#si_reset').click();
    await expect(page.locator('#o_si')).toHaveText('character:');

    await page.locator('#nri input').nth(1).fill('25');
    await page.locator('#nri input').nth(1).blur();
    await expect(page.locator('#o_nri')).toHaveText('numeric:10,25');

    await page.locator('#rng').click();
    await page.locator('.air-datepicker-cell.-day-[data-date="3"][data-month="4"]').click();
    await page.locator('.air-datepicker-cell.-day-[data-date="7"][data-month="4"]').click();
    await expect(page.locator('#o_rng')).toHaveText('Date:2024-05-03,2024-05-07');
  });

  test('update functions', async ({ open }) => {
    const page = await open();
    await page.click('#upd');
    await expect(page.locator('#o_cgb')).toHaveText('character:q,r');
    await expect(page.locator('#o_ar')).toHaveText('character:right');
    await expect(page.locator('#o_si')).toHaveText('character:found');
    await expect(page.locator('#o_nri')).toHaveText('numeric:1,2');
    await expect(page.locator('#o_rng')).toHaveText('Date:2025-06-01,2025-06-03');
    await expect(page.locator('#o_kn')).toHaveText('integer:70');
    await settle(page);
  });
});
