import { test, expect } from '../../helpers/fixtures';

test.use({ fixture: 'reactivity' });

test.describe('reactivity', () => {
  test('module instances are isolated and namespaced', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#a-count')).toHaveText('count=0');
    await expect(page.locator('#a-greeting')).toHaveText('hi a from a-');
    await page.click('#a-inc');
    await page.click('#a-inc');
    await page.click('#b-inc');
    await expect(page.locator('#a-count')).toHaveText('count=2');
    await expect(page.locator('#b-count')).toHaveText('count=10');
    await expect(page.locator('#total')).toHaveText('total=12');
    await page.fill('#b-name', 'bee');
    await expect(page.locator('#b-greeting')).toHaveText('hi bee from b-');
    await expect(page.locator('#a-greeting')).toHaveText('hi a from a-');
  });

  test('reactiveValues, isolate and observeEvent', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#snapshot')).toHaveText('snapshot=none');
    await expect(page.locator('#doubled')).toHaveText('doubled=2 isolated-snap=none');
    await page.fill('#x', '4');
    await expect(page.locator('#doubled')).toHaveText('doubled=8 isolated-snap=none');
    await page.click('#snap');
    await expect(page.locator('#snapshot')).toHaveText('snapshot=4');
    // isolate(): the snapshot change alone must not re-render `doubled`
    await expect(page.locator('#doubled')).toHaveText('doubled=8 isolated-snap=none');
    await page.fill('#x', '5');
    await expect(page.locator('#doubled')).toHaveText('doubled=10 isolated-snap=4');
  });

  test('eventReactive waits for the event, ignoreInit skips startup', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#event_result')).toHaveText('');
    await expect(page.locator('#observer_runs')).toHaveText('runs=0');
    await page.click('#go');
    await expect(page.locator('#event_result')).toHaveText('went with x=1');
    await expect(page.locator('#observer_runs')).toHaveText('runs=1');
    await page.fill('#x', '3');
    await expect(page.locator('#doubled')).toHaveText(/doubled=6/);
    await expect(page.locator('#event_result')).toHaveText('went with x=1');
    await page.click('#go');
    await expect(page.locator('#event_result')).toHaveText('went with x=3');
    await expect(page.locator('#observer_runs')).toHaveText('runs=2');
  });

  test('outputs created in lapply with computed input ids', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#gen_out2')).toHaveText('gen2=v2');
    await expect(page.locator('#gen_all')).toHaveText('v1|v2|v3');
    await page.fill('#gen3', 'changed');
    await expect(page.locator('#gen_out3')).toHaveText('gen3=changed');
    await expect(page.locator('#gen_all')).toHaveText('v1|v2|changed');
  });

  test('invalidateLater ticks and debounce settles', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#ticks')).toHaveText('ticking=TRUE', { timeout: 5000 });
    await page.locator('#typing').pressSequentially('abc', { delay: 50 });
    await expect(page.locator('#debounced')).toHaveText('debounced=abc');
  });

  test('two browser sessions do not share state', async ({ open, browser, app }) => {
    const page = await open();
    await page.click('#a-inc');
    await expect(page.locator('#a-count')).toHaveText('count=1');
    const ctx = await browser.newContext();
    const other = await ctx.newPage();
    await other.goto(app.url);
    await expect(other.locator('#a-count')).toHaveText('count=0');
    await other.fill('#x', '7');
    await expect(other.locator('#doubled')).toHaveText(/doubled=14/);
    await expect(page.locator('#doubled')).toHaveText(/doubled=2/);
    await expect(page.locator('#a-count')).toHaveText('count=1');
    await ctx.close();
  });
});
