import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { Page } from '@playwright/test';
import { test as base, expect, settle, waitForIdle } from '../../helpers/fixtures';
import { startApp, RunningApp } from '../../helpers/server';

// shiny's own example apps (system.file("examples", package = "shiny")),
// copied verbatim apart from library(hotShiny). One real user interaction per
// example, asserted against what plain shiny does.
//
// The `fixture` option is worker-scoped and cannot vary per describe group,
// so each group starts its own app; `open` keeps the shared fixture's
// contract (navigate, wait for idle, fail on uncaught page errors).
let current: RunningApp | undefined;

const test = base.extend({
  open: async ({ page, pageErrors }, use) => {
    void pageErrors;
    await use(async (p = '') => {
      const app = current!;
      try {
        await page.goto(app.url + p);
        await waitForIdle(page);
      } catch (e) {
        throw new Error(`${e}\n--- app log (${app.runtime}) ---\n${app.logs()}`);
      }
      return page;
    });
  },
});

function example(name: string, body: () => void) {
  test.describe(name, () => {
    test.beforeAll(async ({ runtime }) => {
      test.setTimeout(90_000);
      current = await startApp({ runtime, fixture: `ex-${name}` });
    });
    test.afterAll(async () => {
      await current?.stop();
      current = undefined;
    });
    body();
  });
}

/** The ionRangeSlider widget shiny.js builds in front of a sliderInput. */
const sliderOf = (page: Page, id: string) =>
  page.locator(`#${id}`).locator('xpath=preceding-sibling::span[contains(@class,"irs")]');

/** Drag an ionRangeSlider handle by `dx` pixels, like a user would. */
async function dragSlider(page: Page, id: string, dx: number, handle = '.irs-handle.single') {
  const box = (await sliderOf(page, id).locator(handle).boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width / 2 + dx, box.y + box.height / 2, { steps: 8 });
  await page.mouse.up();
}

async function selectizeChoose(page: Page, id: string, value: string) {
  await page.locator(`#${id} + .selectize-control .selectize-input`).click();
  await page.locator(`#${id} + .selectize-control .option[data-value="${value}"]`).click();
}

const inputValue = (page: Page, id: string) =>
  page.evaluate((id) => (window as any).Shiny.shinyapp.$inputValues[id], id);

const imgSrc = (page: Page, id: string) => page.locator(`#${id} img`).getAttribute('src');

example('01_hello', () => {
  test('moving the bins slider redraws the histogram', async ({ open }) => {
    const page = await open();
    await expect(page.locator('h2')).toHaveText('Hello Shiny!');
    await expect(page.locator('#distPlot img')).toHaveAttribute('src', /^data:image\/png;base64,/);
    expect(await inputValue(page, 'bins')).toBe(30);
    const before = await imgSrc(page, 'distPlot');
    await dragSlider(page, 'bins', -120);
    await expect.poll(() => inputValue(page, 'bins')).toBeLessThan(30);
    await expect.poll(() => imgSrc(page, 'distPlot')).not.toBe(before);
    await settle(page);
    const bins = await inputValue(page, 'bins');
    expect(await page.locator('#bins').inputValue()).toBe(String(bins));
  });

  // DESCRIPTION says "DisplayMode: Showcase": the app is shown with its code
  // and README, and the server tells the page which code just ran.
  test('showcase mode highlights the renderPlot code when it re-runs', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#showcase-app-container #distPlot')).toBeVisible();
    await expect(page.locator('#readme-md')).toContainText('Number of bins');
    await expect(page.locator('#app_R_code')).toContainText('renderPlot');
    const highlight = page.locator('#app_R_code span[id^="srcref_"]');
    await expect(highlight).toHaveCount(1);
    await expect(highlight).toContainText('hist(x, breaks = bins');
    const sources: string[] = [];
    await page.evaluate(() => {
      const w = window as any;
      w.__showcaseSrc = [];
      const ws = w.Shiny.shinyapp.$socket;
      const orig = ws.onmessage;
      ws.onmessage = (e: MessageEvent) => {
        if (typeof e.data === 'string' && e.data.includes('"showcase-src"')) w.__showcaseSrc.push(e.data);
        orig(e);
      };
    });
    await dragSlider(page, 'bins', 80);
    await expect.poll(() => page.evaluate(() => (window as any).__showcaseSrc.length)).toBeGreaterThan(0);
    sources.push(...(await page.evaluate(() => (window as any).__showcaseSrc)));
    const id = await highlight.getAttribute('id');
    expect(sources.some((s) => s.includes(`"srcref":[${id!.replace('srcref_', '')}]`))).toBe(true);

    await page.locator('#showcase-code-position-toggle').click();
    await expect(page.locator('#showcase-sxs-code #showcase-code-tabs')).toBeVisible();
  });
});

example('02_text', () => {
  test('dataset and observation count drive summary and table', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#summary')).toContainText('area');
    await expect(page.locator('#view table tbody tr')).toHaveCount(10);
    await selectizeChoose(page, 'dataset', 'pressure');
    await expect(page.locator('#summary')).toContainText('temperature');
    await expect(page.locator('#view table thead')).toContainText('pressure');
    await page.fill('#obs', '3');
    await expect(page.locator('#view table tbody tr')).toHaveCount(3);
    await expect(page.locator('#view table tbody tr').first()).toContainText('0.00');
  });
});

example('03_reactivity', () => {
  test('caption updates as you type; dataset and obs update outputs', async ({ open }) => {
    const page = await open();
    await expect(page.locator('h3 > span#caption')).toHaveText('Data Summary');
    // The example reuses the id "caption" for both the text input and the output.
    await page.locator('input#caption').fill('');
    await page.locator('input#caption').pressSequentially('Cars!');
    await expect(page.locator('h3 > span#caption')).toHaveText('Cars!');
    await selectizeChoose(page, 'dataset', 'cars');
    await expect(page.locator('#summary')).toContainText('speed');
    await expect(page.locator('#view table thead')).toContainText('dist');
    await page.fill('#obs', '4');
    await expect(page.locator('#view table tbody tr')).toHaveCount(4);
    await expect(page.locator('h3 > span#caption')).toHaveText('Cars!');
  });
});

example('04_mpg', () => {
  test('variable and outliers change caption and boxplot', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#caption')).toHaveText('mpg ~ cyl');
    await expect(page.locator('#mpgPlot img')).toHaveAttribute('src', /^data:image\/png;base64,/);
    const cyl = await imgSrc(page, 'mpgPlot');
    // only the cylinder boxplot has outliers, so toggling them redraws it
    await page.locator('#outliers').uncheck();
    await expect.poll(() => imgSrc(page, 'mpgPlot')).not.toBe(cyl);
    await page.locator('#outliers').check();
    await expect.poll(() => imgSrc(page, 'mpgPlot')).toBe(cyl);
    await selectizeChoose(page, 'variable', 'am');
    await expect(page.locator('#caption')).toHaveText('mpg ~ am');
    await expect.poll(() => imgSrc(page, 'mpgPlot')).not.toBe(cyl);
  });
});

example('05_sliders', () => {
  const cell = (page: Page, name: string) =>
    page.locator('#values table tbody tr', { has: page.locator(`td:text-is("${name}")`) }).locator('td').nth(1);
  const cellText = async (page: Page, name: string) => (await cell(page, name).textContent())!.trim();

  test('slider values show in the table; play animates', async ({ open }) => {
    const page = await open();
    await expect(cell(page, 'Integer')).toHaveText('500');
    await expect(cell(page, 'Decimal')).toHaveText('0.5');
    await expect(cell(page, 'Range')).toHaveText('200 500');
    await expect(cell(page, 'Custom Format')).toHaveText('0');
    await expect(cell(page, 'Animation')).toHaveText('1');
    await expect(sliderOf(page, 'format').locator('.irs-max'))
      .toHaveText('$10,000');

    await dragSlider(page, 'decimal', 60);
    await expect.poll(async () => Number(await cellText(page, 'Decimal'))).toBeGreaterThan(0.5);

    await dragSlider(page, 'range', -40, '.irs-handle.from');
    await expect.poll(async () => (await cellText(page, 'Range')).split(' ')[0]).not.toBe('200');
    await expect(cell(page, 'Range')).toHaveText(/^\s*\d+ 500\s*$/);

    // The looping animation advances the value server-side by 10 every 300ms.
    const play = page.locator('#animation').locator('xpath=following-sibling::div[contains(@class,"slider-animate-container")]').locator('a');
    await play.click();
    await expect.poll(async () => Number(await cellText(page, 'Animation')), { timeout: 5000 }).toBeGreaterThanOrEqual(21);
    await play.click();
    await settle(page);
    const stopped = await cell(page, 'Animation').textContent();
    await page.waitForTimeout(800);
    await expect(cell(page, 'Animation')).toHaveText(stopped!);
  });
});

example('06_tabsets', () => {
  test('distribution radio redraws plot; tabs show summary and table', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#plot img')).toHaveAttribute('src', /^data:image\/png;base64,/);
    const norm = await imgSrc(page, 'plot');
    await page.locator('input[name="dist"][value="unif"]').check();
    await expect.poll(() => imgSrc(page, 'plot')).not.toBe(norm);

    await page.getByRole('tab', { name: 'Summary' }).click();
    await expect(page.locator('#summary')).toBeVisible();
    await expect(page.locator('#summary')).toContainText('Min.');
    // runif: every value lies in [0, 1]
    const nums = (await page.locator('#summary').textContent())!.split('\n')[1].trim().split(/\s+/).map(Number);
    expect(nums.length).toBe(6);
    for (const n of nums) expect(n >= 0 && n <= 1).toBe(true);

    await page.getByRole('tab', { name: 'Table' }).click();
    await expect(page.locator('#table table tbody tr')).toHaveCount(500);
    await dragSlider(page, 'n', -300);
    await expect.poll(async () => page.locator('#table table tbody tr').count()).toBeLessThan(500);
    await settle(page);
    expect(await page.locator('#table table tbody tr').count()).toBe(await inputValue(page, 'n'));
  });
});

example('07_widgets', () => {
  test('outputs only update when Update View is clicked', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#summary')).toContainText('area');
    await expect(page.locator('#view table tbody tr')).toHaveCount(10);
    await selectizeChoose(page, 'dataset', 'cars');
    await page.fill('#obs', '3');
    await settle(page);
    await page.waitForTimeout(300);
    await expect(page.locator('#summary')).toContainText('area');
    await expect(page.locator('#view table tbody tr')).toHaveCount(10);
    await page.click('#update');
    await expect(page.locator('#summary')).toContainText('speed');
    await expect(page.locator('#view table tbody tr')).toHaveCount(3);
    // obs is isolated: changing it alone does not refresh the table
    await page.fill('#obs', '5');
    await settle(page);
    await page.waitForTimeout(300);
    await expect(page.locator('#view table tbody tr')).toHaveCount(3);
    await page.click('#update');
    await expect(page.locator('#view table tbody tr')).toHaveCount(5);
  });
});

example('09_upload', () => {
  test('uploaded CSV is parsed with the chosen options', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#contents')).toBeEmpty();
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'up-'));
    const f = path.join(dir, 'data.csv');
    const rows = Array.from({ length: 9 }, (_, i) => `${i + 1};'item ${i + 1}'`);
    fs.writeFileSync(f, ['n;label', ...rows].join('\n') + '\n');
    await page.setInputFiles('#file1', f);
    await expect(page.locator('#file1_progress')).toContainText('Upload complete');
    await expect(page.locator('input[type=text][readonly]')).toHaveValue('data.csv');
    // comma separator: a single column named "n.label"
    await expect(page.locator('#contents table thead th')).toHaveText(['n.label']);
    await page.locator('input[name="sep"][value=";"]').check();
    await expect(page.locator('#contents table thead th')).toHaveText(['n', 'label']);
    await expect(page.locator('#contents table tbody tr')).toHaveCount(6);
    await expect(page.locator('#contents table tbody tr').first().locator('td').nth(1)).toHaveText("'item 1'");
    await page.locator('input[name="quote"][value="\'"]').check();
    await expect(page.locator('#contents table tbody tr').first().locator('td').nth(1)).toHaveText('item 1');
    await page.locator('input[name="disp"][value="all"]').check();
    await expect(page.locator('#contents table tbody tr')).toHaveCount(9);
    await page.locator('#header').uncheck();
    await expect(page.locator('#contents table tbody tr')).toHaveCount(10);
    await expect(page.locator('#contents table thead th')).toHaveText(['V1', 'V2']);
  });
});

example('10_download', () => {
  test('download serves the selected dataset as CSV', async ({ open }) => {
    const page = await open();
    await expect(page.locator('#table table tbody tr')).toHaveCount(48);
    const [rock] = await Promise.all([page.waitForEvent('download'), page.click('#downloadData')]);
    expect(rock.suggestedFilename()).toBe('rock.csv');
    const rockCsv = fs.readFileSync(await rock.path(), 'utf8').trim().split('\n');
    expect(rockCsv[0]).toBe('"area","peri","shape","perm"');
    expect(rockCsv).toHaveLength(49);

    await selectizeChoose(page, 'dataset', 'cars');
    await expect(page.locator('#table table tbody tr')).toHaveCount(50);
    const [cars] = await Promise.all([page.waitForEvent('download'), page.click('#downloadData')]);
    expect(cars.suggestedFilename()).toBe('cars.csv');
    const carsCsv = fs.readFileSync(await cars.path(), 'utf8').trim().split('\n');
    expect(carsCsv[0]).toBe('"speed","dist"');
    expect(carsCsv[1]).toBe('4,2');
    expect(carsCsv).toHaveLength(51);
  });
});

example('11_timer', () => {
  test('current time ticks about once per second', async ({ open }) => {
    const page = await open();
    const out = page.locator('h2 > #currentTime');
    await expect(out).toHaveText(/^The current time is \d{4}-\d\d-\d\d \d\d:\d\d:\d\d(\.\d+)?$/);
    const seen = await page.evaluate(
      () =>
        new Promise<string[]>((resolve) => {
          const el = document.getElementById('currentTime')!;
          const vals = [el.textContent!];
          const obs = new MutationObserver(() => {
            if (vals[vals.length - 1] !== el.textContent) vals.push(el.textContent!);
          });
          obs.observe(el, { childList: true, characterData: true, subtree: true });
          setTimeout(() => (obs.disconnect(), resolve(vals)), 3500);
        }),
    );
    // 3.5s at one tick per second: 3 or 4 distinct, increasing timestamps
    expect(seen.length).toBeGreaterThanOrEqual(4);
    expect(seen.length).toBeLessThanOrEqual(5);
    const t = seen.map((s) => Date.parse(s.replace('The current time is ', '').replace(' ', 'T')));
    for (let i = 1; i < t.length; i++) {
      const dt = t[i] - t[i - 1];
      expect(dt).toBeGreaterThan(800);
      expect(dt).toBeLessThan(1500);
    }
    await waitForIdle(page);
  });
});
