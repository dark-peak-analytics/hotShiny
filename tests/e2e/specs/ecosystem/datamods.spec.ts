import { Page } from '@playwright/test';
import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-datamods' });

const CSV = [
  'species,size,weight',
  'cat,1.5,4',
  'dog,3.2,20',
  'dog,2.8,15',
  'bird,0.3,0.2',
  'cat,1.1,3',
  'fish,0.5,1',
].join('\n');

// Hex-encoded column names, as datamods builds its filter input ids.
const SPECIES = '#filter-filter_73706563696573';
const SIZE = '#filter-filter_73697a65';

async function importCsv(page: Page) {
  await page.setInputFiles('#import-file', { name: 'animals.csv', mimeType: 'text/csv', buffer: Buffer.from(CSV) });
  await expect(page.locator('#import-file_progress')).toContainText('Upload complete');
  await expect(page.locator('#import-import-result')).toContainText('Data ready to be imported!');
  await expect(page.locator('#import-import-result')).toContainText('6 obs. of 3 variables');
  await settle(page);
  await page.click('#import-confirm');
  await expect(page.locator('#imported')).toHaveText('name=animals.csv rows=6 cols=species,size,weight');
  await expect(page.locator('#filter-nrow')).toHaveText('6 / 6');
}

async function togglePickerOption(page: Page, select: string, label: string) {
  await page.evaluate(([sel, label]) => {
    const el = (window as any).jQuery(sel);
    const cur: string[] = el.val() || [];
    const next = cur.includes(label) ? cur.filter((v) => v !== label) : cur.concat([label]);
    el.selectpicker('val', next);
    el.trigger('change');
  }, [select, label]);
}

test.describe('datamods', () => {
  test('import_file reads an uploaded CSV and previews it', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#imported')).toHaveText('');
    await importCsv(page);
    await expect(page.locator('#filtered')).toHaveText('filtered rows=6 species=bird,cat,dog,fish');
    await expect(page.locator(SPECIES)).toHaveClass(/shiny-bound-input/);
    await expect(page.locator(`${SIZE} input`)).toHaveCount(2);
  });

  test('filter_data filters by factor and numeric range and builds the dplyr code', async ({ open }) => {
    const page = await open();
    await importCsv(page);

    await togglePickerOption(page, SPECIES, 'dog');
    await expect(page.locator('#filtered')).toHaveText('filtered rows=4 species=bird,cat,fish');
    await expect(page.locator('#filter-nrow')).toHaveText('4 / 6');
    await expect(page.locator('#code')).toHaveText('!(species %in% "dog")');

    const min = page.locator(`${SIZE} input`).first();
    await min.fill('1');
    await min.press('Tab');
    await expect(page.locator('#filtered')).toHaveText('filtered rows=2 species=cat');
    await expect(page.locator('#filter-nrow')).toHaveText('2 / 6');
    await expect(page.locator('#code')).toHaveText('!(species %in% "dog") & (size >= 1 & size <= 3.2)');

    await togglePickerOption(page, SPECIES, 'dog');
    await expect(page.locator('#filtered')).toHaveText('filtered rows=4 species=cat,dog');
  });

  test('a second import replaces the data and resets the filters', async ({ open }) => {
    const page = await open();
    await importCsv(page);
    await togglePickerOption(page, SPECIES, 'dog');
    await expect(page.locator('#filter-nrow')).toHaveText('4 / 6');
    const csv2 = 'species,size\nowl,0.4\nowl,0.6\nbat,0.1\n';
    await page.setInputFiles('#import-file', { name: 'night.csv', mimeType: 'text/csv', buffer: Buffer.from(csv2) });
    await expect(page.locator('#import-import-result')).toContainText('3 obs. of 2 variables');
    await settle(page);
    await page.click('#import-confirm');
    await expect(page.locator('#imported')).toHaveText('name=night.csv rows=3 cols=species,size');
    await expect(page.locator('#filter-nrow')).toHaveText('3 / 3');
    await expect(page.locator('#filtered')).toHaveText('filtered rows=3 species=bat,owl');
  });
});
