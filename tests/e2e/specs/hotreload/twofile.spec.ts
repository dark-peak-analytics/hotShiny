import * as fs from 'node:fs';
import * as path from 'node:path';
import { test, expect, Page } from '@playwright/test';
import { startApp, RunningApp } from '../../helpers/server';
import { waitForIdle } from '../../helpers/fixtures';

// The ui.R/server.R layout with global.R and a module in R/: every file in
// the app directory is watched and edits to any of them hot-reload.
let app: RunningApp;

test.beforeEach(async () => {
  app = await startApp({ runtime: 'hotshiny', fixture: 'hotreload-twofile', hotReload: true });
});
test.afterEach(async () => {
  await app?.stop();
});

function edit(file: string, fn: (src: string) => string) {
  const f = path.join(app.dir, file);
  const before = fs.readFileSync(f, 'utf8');
  const after = fn(before);
  if (after === before) throw new Error('edit did not change the source');
  fs.writeFileSync(f, after);
}

async function open(page: Page) {
  page.on('pageerror', (e) => console.log('pageerror:', String(e)));
  await page.goto(app.url);
  await waitForIdle(page);
  await page.evaluate(() => ((window as any).__marker = 'same-page'));
  await expect(page.locator('#greeting')).toHaveText('hello initial');
  await page.fill('#name', 'Ada');
  await page.click('#counter-inc');
  await page.click('#counter-inc');
  await expect(page.locator('#counter-count')).toHaveText('count=2');
  await expect(page.locator('#greeting')).toHaveText('hello Ada');
}

async function reloaded(page: Page, n: number) {
  await page.waitForFunction((n) => ((window as any).hotShinyDev?.reloads ?? 0) >= n, n, { timeout: 20_000 });
  await waitForIdle(page);
}

async function expectStatePreserved(page: Page) {
  expect(await page.evaluate(() => (window as any).__marker)).toBe('same-page');
  await expect(page.locator('#name')).toHaveValue('Ada');
}

test('module edits in R/ hot-reload and keep module state', async ({ page }) => {
  await open(page);
  edit('R/counter_module.R', (s) =>
    s
      .replace('"Counter one"', '"Counter two"')
      .replace('paste0("count=", count())', 'paste0("count=", count(), " (x10=", count() * 10, ")")'),
  );
  await reloaded(page, 1);
  await expect(page.locator('#counter-label')).toHaveText('Counter two');
  await expect(page.locator('#counter-count')).toHaveText('count=2 (x10=20)');
  await expectStatePreserved(page);
  await page.click('#counter-inc');
  await expect(page.locator('#counter-count')).toHaveText('count=3 (x10=30)');
});

test('ui.R edits hot-reload', async ({ page }) => {
  await open(page);
  edit('ui.R', (s) => s.replace('"Version one"', '"Version two"'));
  await reloaded(page, 1);
  await expect(page.locator('#title')).toHaveText('Version two');
  await expectStatePreserved(page);
  await expect(page.locator('#counter-count')).toHaveText('count=2');
});

test('server.R edits hot-reload', async ({ page }) => {
  await open(page);
  edit('server.R', (s) => s.replace('paste(greeting_prefix, input$name)', 'paste(greeting_prefix, toupper(input$name))'));
  await reloaded(page, 1);
  await expect(page.locator('#greeting')).toHaveText('hello ADA');
  await expectStatePreserved(page);
  await expect(page.locator('#counter-count')).toHaveText('count=2');
});

test('global.R edits hot-reload', async ({ page }) => {
  await open(page);
  edit('global.R', (s) => s.replace('"hello"', '"hi"'));
  await reloaded(page, 1);
  await expect(page.locator('#greeting')).toHaveText('hi Ada');
  await expectStatePreserved(page);
});
