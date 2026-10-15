import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'outputs' });

test.describe('outputs', () => {
  test('text, print and table render like shiny', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#txt')).toHaveText('n is 3');
    await expect(page.locator('#txt_inline')).toHaveText('3');
    await expect(page.locator('#txt_inline')).toHaveJSProperty('tagName', 'SPAN');
    await expect(page.locator('#prn')).toContainText('Min. 1st Qu.');
    await expect(page.locator('#prn')).toHaveJSProperty('tagName', 'PRE');
    await expect(page.locator('#tbl table tbody tr')).toHaveCount(3);
    await expect(page.locator('#tbl table')).toHaveClass(/table/);
    await page.fill('#n', '5');
    await expect(page.locator('#tbl table tbody tr')).toHaveCount(5);
    await expect(page.locator('#txt')).toHaveText('n is 5');
  });

  test('validate and req', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#validated')).toHaveText('Please type something');
    await expect(page.locator('#validated')).toHaveClass(/shiny-output-error-validation/);
    await expect(page.locator('#required')).toHaveText('');
    await page.fill('#need', 'abc');
    await expect(page.locator('#validated')).toHaveText('You typed abc');
    await expect(page.locator('#validated')).not.toHaveClass(/shiny-output-error/);
    await expect(page.locator('#required')).toHaveText('Required ok: ABC');
  });

  test('renderUI binds nested inputs and outputs', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#dyn .irs--shiny')).toBeVisible();
    await expect(page.locator('#dyn_value')).toHaveText('dynamic: 3');
    await page.fill('#n', '6');
    await expect(page.locator('#dyn_value')).toHaveText('dynamic: 6');
    await expect(page.locator('#strong-n')).toHaveText('6');
  });

  test('plot sized by clientData and errors shown', async ({ open }) => {
    const page = await open();
    const img = page.locator('#plt img');
    await expect(img).toBeVisible();
    await expect(img).toHaveAttribute('src', /^data:image\/png;base64,/);
    await expect(img).toHaveAttribute('width', '400');
    await expect(img).toHaveAttribute('height', '300');
    await page.locator('#fail').check();
    await expect(page.locator('#plt')).toHaveClass(/shiny-output-error/);
    await expect(page.locator('#plt')).toContainText('Deliberate plot failure');
    await page.locator('#fail').uncheck();
    await expect(page.locator('#plt img')).toBeVisible();
  });

  test('image output', async ({ open }) => {
    const page = await open();
    const img = page.locator('#img img');
    await expect(img).toHaveAttribute('alt', 'square');
    await expect(img).toHaveAttribute('src', /^data:image\/png;base64,/);
  });

  test('downloads', async ({ open }) => {
    const page = await open();
    await page.fill('#n', '2');
    await expect(page.locator('#txt')).toHaveText('n is 2');
    const [dl] = await Promise.all([page.waitForEvent('download'), page.click('#dl')]);
    expect(dl.suggestedFilename()).toBe('cars.csv');
    const csv = fs.readFileSync(await dl.path(), 'utf8').trim().split('\n');
    expect(csv).toHaveLength(3);
    expect(csv[0]).toContain('"mpg"');
    const [dl2] = await Promise.all([page.waitForEvent('download'), page.click('#dl_txt')]);
    expect(dl2.suggestedFilename()).toBe('hello.txt');
    expect(fs.readFileSync(await dl2.path(), 'utf8')).toBe('hello\nworld\n');
  });

  test('file upload', async ({ open }) => {
    const page = await open();
    const f = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'up-')), 'data.csv');
    fs.writeFileSync(f, 'a,b\n1,2\n3,4\n');
    await page.setInputFiles('#upload', f);
    await expect(page.locator('#upload_progress')).toContainText('Upload complete');
    await expect(page.locator('#uploaded table tbody tr')).toHaveCount(2);
    await expect(page.locator('#upload').locator('xpath=ancestor::div[contains(@class,"input-group")]').locator('input[type=text]')).toHaveValue('data.csv');
  });
});
