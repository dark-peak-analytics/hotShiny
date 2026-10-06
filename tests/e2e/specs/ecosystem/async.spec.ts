import { test, expect, settle } from '../../helpers/fixtures';

test.use({ fixture: 'eco-async' });

test.describe('async: promises, future and ExtendedTask', () => {
  test('initial state', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#fast')).toHaveText('fast=2');
    await expect(page.locator('#task_status')).toHaveText('status=initial');
    await expect(page.locator('#task_result')).toHaveText('');
    await expect(page.locator('#task_runs')).toHaveText('runs=0');
    await expect(page.locator('#future_out')).toHaveText('');
    await expect(page.locator('#slow_out')).toHaveText('');
    await expect(page.locator('#async_ui')).toBeEmpty();
  });

  test('future_promise output resolves in a worker; same-session inputs wait for it', async ({ open }) => {
    const page = await open();
    await page.click('#go_future');
    // While the session has an async output in flight, shiny holds later
    // input changes until it resolves (async is non-blocking across sessions,
    // not within one).
    await page.fill('#n', '5');
    await page.waitForTimeout(300);
    await expect(page.locator('#fast')).toHaveText('fast=2');
    await expect(page.locator('#future_out')).toHaveText('future=10 in-worker=TRUE', { timeout: 20_000 });
    await expect(page.locator('#fast')).toHaveText('fast=10');
    await settle(page);
    await page.click('#go_future');
    await expect(page.locator('#future_out')).toHaveText('future=50 in-worker=TRUE', { timeout: 20_000 });
  });

  test('promises resolved by later, and rejected promises render as errors', async ({ open }) => {
    const page = await open();
    await page.click('#go_later');
    await expect(page.locator('#later_out')).toHaveText('later=1');
    await settle(page);
    await page.click('#go_later');
    await expect(page.locator('#later_out')).toHaveText('later=2');
    await page.click('#go_fail');
    await expect(page.locator('#fail_out')).toHaveText('async boom');
    await expect(page.locator('#fail_out')).toHaveClass(/shiny-output-error/);
    // The session survives the rejection.
    await page.fill('#n', '4');
    await expect(page.locator('#fast')).toHaveText('fast=8');
  });

  test('ExtendedTask keeps the session responsive while it runs', async ({ open }) => {
    const page = await open();
    await page.fill('#n', '3');
    await expect(page.locator('#fast')).toHaveText('fast=6');
    await page.click('#run_task');
    await expect(page.locator('#task_status')).toHaveText('status=running');
    await expect(page.locator('#task_runs')).toHaveText('runs=1');
    // Unlike a promise output, the task does not hold the session.
    await page.fill('#n', '7');
    await expect(page.locator('#fast')).toHaveText('fast=14');
    await expect(page.locator('#task_status')).toHaveText('status=running');
    await expect(page.locator('#task_result')).toHaveClass(/recalculating/);
    await expect(page.locator('#task_status')).toHaveText('status=success', { timeout: 20_000 });
    await expect(page.locator('#task_result')).toHaveText('result=103');
    await expect(page.locator('#task_result')).not.toHaveClass(/recalculating/);
    await page.click('#run_task');
    await expect(page.locator('#task_status')).toHaveText('status=running');
    await expect(page.locator('#task_result')).toHaveText('result=103');
    await expect(page.locator('#task_result')).toHaveText('result=107', { timeout: 20_000 });
    await expect(page.locator('#task_runs')).toHaveText('runs=2');
  });

  test('renderUI returning a promise inserts live inputs and outputs', async ({ open }) => {
    const page = await open();
    await page.fill('#n', '6');
    await expect(page.locator('#fast')).toHaveText('fast=12');
    await page.click('#go_ui');
    await expect(page.locator('#ui_label')).toHaveText('ui for n=6');
    await expect(page.locator('#dyn_text')).toHaveValue('seed6');
    await expect(page.locator('#dyn_echo')).toHaveText('echo=seed6');
    await page.fill('#dyn_text', 'typed');
    await expect(page.locator('#dyn_echo')).toHaveText('echo=typed');
    await page.fill('#n', '2');
    await expect(page.locator('#fast')).toHaveText('fast=4');
    await settle(page);
    await page.click('#go_ui');
    await expect(page.locator('#ui_label')).toHaveText('ui for n=2');
  });

  test('another session stays responsive while one waits on a future', async ({ open, browser, app }) => {
    const page = await open();
    // The first future starts the multisession workers, which blocks R for a
    // moment in both runtimes; warm them up before measuring responsiveness.
    await page.click('#go_future');
    await expect(page.locator('#future_out')).toHaveText('future=10 in-worker=TRUE', { timeout: 20_000 });
    await settle(page);
    const ctx = await browser.newContext();
    const other = await ctx.newPage();
    await other.goto(app.url);
    await expect(other.locator('#fast')).toHaveText('fast=2');
    await page.click('#go_slow');
    await other.fill('#n', '9');
    // The slow future sleeps 4s; the other session must answer well before.
    await expect(other.locator('#fast')).toHaveText('fast=18', { timeout: 2_500 });
    await expect(page.locator('#slow_out')).toHaveText('');
    await expect(page.locator('#slow_out')).toHaveText('slow done', { timeout: 20_000 });
    await ctx.close();
  });
});
