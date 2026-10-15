import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-logger' });

test.describe('logger::log_shiny_input_changes', () => {
  test('logs the initial inputs and every change, skipping excluded inputs', async ({ open, app }) => {
    const page = await open();
    // At the top level logger's namespace prefix is session$ns(character(0)),
    // which ifelse() turns into NA (in shiny as well).
    const log = page.locator('#log');
    await expect(log).toContainText('INFO NA Default Shiny inputs initialized: {');
    const init = (await log.textContent())!.split('\n')[0];
    expect(JSON.parse(init.replace('INFO NA Default Shiny inputs initialized: ', ''))).toEqual({
      name: 'ann', n: 1, ignored: 'x', go: 0,
    });

    await page.fill('#name', 'bob');
    await expect(log).toContainText('INFO NA Shiny input change detected in name: ann -> bob');
    await page.fill('#ignored', 'changed');
    await settle(page);
    await page.fill('#n', '5');
    await expect(log).toContainText('INFO NA Shiny input change detected in n: 1 -> 5');
    await page.click('#go');
    await expect(log).toContainText('INFO NA Shiny input change detected in go: 0 -> 1');
    await settle(page);

    const lines = (await log.textContent())!.split('\n');
    expect(lines.slice(1)).toEqual([
      'INFO NA Shiny input change detected in name: ann -> bob',
      'INFO NA Shiny input change detected in n: 1 -> 5',
      'INFO NA Shiny input change detected in go: 0 -> 1',
    ]);
    // The console appender wrote the same lines to the app's stderr.
    for (const l of lines.slice(1)) expect(app.logs()).toContain(l);
  });
});
