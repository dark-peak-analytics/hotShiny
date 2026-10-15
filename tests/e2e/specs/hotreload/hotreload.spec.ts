import * as fs from 'node:fs';
import * as path from 'node:path';
import { test, expect, Page } from '@playwright/test';
import { startApp, RunningApp } from '../../helpers/server';
import { waitForIdle } from '../../helpers/fixtures';

// Each test gets its own hot-reloading app (tests edit its source).
let app: RunningApp;

test.beforeEach(async () => {
  app = await startApp({ runtime: 'hotshiny', fixture: 'hotreload', hotReload: true });
});
test.afterEach(async () => {
  await app?.stop();
});

function appFile() {
  return path.join(app.dir, 'app.R');
}

function edit(fn: (src: string) => string) {
  const f = appFile();
  const before = fs.readFileSync(f, 'utf8');
  const after = fn(before);
  if (after === before) throw new Error('edit did not change the source');
  fs.writeFileSync(f, after);
}

async function open(page: Page) {
  page.on('pageerror', (e) => console.log('pageerror:', String(e)));
  const disconnects: string[] = [];
  await page.exposeFunction('__hsDisconnected', () => disconnects.push('x'));
  await page.goto(app.url);
  await waitForIdle(page);
  await page.evaluate(() => {
    (window as any).__marker = 'same-page';
    (window as any).$(document).on('shiny:disconnected', () => (window as any).__hsDisconnected());
  });
  // Put the session in a non-default state.
  await page.fill('#name', 'Ada');
  await page.locator('#flag').check();
  await page.locator('#pick + .selectize-control .selectize-input').click();
  await page.locator('#pick + .selectize-control .option[data-value="c"]').click();
  await page.click('#inc');
  await page.click('#inc');
  await expect(page.locator('#count')).toHaveText('count=2');
  await expect(page.locator('#greeting')).toHaveText('hello Ada');
  return { disconnects };
}

async function reloaded(page: Page, n: number) {
  await page.waitForFunction((n) => ((window as any).hotShinyDev?.reloads ?? 0) >= n, n, { timeout: 20_000 });
  await waitForIdle(page);
}

async function expectStatePreserved(page: Page) {
  expect(await page.evaluate(() => (window as any).__marker)).toBe('same-page');
  await expect(page.locator('#name')).toHaveValue('Ada');
  await expect(page.locator('#flag')).toBeChecked();
  await expect(page.locator('#pick')).toHaveValue('c');
  await expect(page.locator('#count')).toHaveText(/count=2/);
}

test('UI edits morph in place and keep inputs and reactive state', async ({ page }) => {
  const { disconnects } = await open(page);
  edit((s) => s.replace('"Version one"', '"Version two"'));
  await reloaded(page, 1);
  await expect(page.locator('#title')).toHaveText('Version two');
  await expectStatePreserved(page);
  const changed = await page.evaluate(() => (window as any).hotShinyDev.lastChangedKeys);
  expect(changed, 'only the edited subtree is swapped').toHaveLength(1);
  expect(disconnects).toEqual([]);
});

test('server edits take effect and reactiveVal state survives', async ({ page }) => {
  await open(page);
  edit((s) => s.replace('paste0("count=", count())', 'paste0("count=", count(), " (x10=", count() * 10, ")")'));
  await reloaded(page, 1);
  await expect(page.locator('#count')).toHaveText('count=2 (x10=20)');
  await expectStatePreserved(page);
  await page.click('#inc');
  await expect(page.locator('#count')).toHaveText('count=3 (x10=30)');
  await expect(page.locator('#greeting')).toHaveText('hello Ada');
});

test('new inputs, outputs and widget dependencies appear and work', async ({ page }) => {
  await open(page);
  edit((s) =>
    s
      .replace('div(id = "extra-slot")', 'div(id = "extra-slot", dateInput("when", "When", value = "2024-05-06"), textOutput("when_out"))')
      .replace('output$count <-', 'output$when_out <- renderText(paste0("when=", input$when))\n  output$count <-'),
  );
  await reloaded(page, 1);
  await expect(page.locator('#when_out')).toHaveText('when=2024-05-06');
  // bootstrap-datepicker was not on the page before; it must have been loaded.
  expect(await page.evaluate(() => typeof (window as any).$.fn.bsDatepicker)).toBe('function');
  await expectStatePreserved(page);
});

test('errors are reported without losing the session, and fixing recovers', async ({ page }) => {
  const { disconnects } = await open(page);
  edit((s) => s.replace('output$greeting <- renderText(paste0("hello ", input$name))', 'output$greeting <- renderText(paste0("hello ", input$name)'));
  await expect(page.locator('#hotshiny-dev-overlay .hotshiny-error')).toBeVisible({ timeout: 20_000 });
  await expect(page.locator('#greeting')).toHaveText('hello Ada');
  edit((s) => s.replace('output$greeting <- renderText(paste0("hello ", input$name)', 'output$greeting <- renderText(paste0("hi ", input$name))'));
  await reloaded(page, 1);
  await expect(page.locator('#greeting')).toHaveText('hi Ada');
  await expectStatePreserved(page);
  expect(disconnects).toEqual([]);
});

test('page reload after hot reload serves the new version', async ({ page }) => {
  await open(page);
  edit((s) => s.replace('"Version one"', '"Version three"'));
  await reloaded(page, 1);
  await page.reload();
  await waitForIdle(page);
  await expect(page.locator('#title')).toHaveText('Version three');
});
