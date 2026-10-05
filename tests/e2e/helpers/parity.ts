import { Page } from '@playwright/test';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

/**
 * Serialise the live DOM in a runtime-neutral form: hotShiny's dev-only script
 * is dropped and per-render random ids (tabset ids, etc.) are canonicalised so
 * two independent renders of the same UI compare equal.
 */
export async function normalizedDom(page: Page): Promise<{ body: string; head: string[] }> {
  return page.evaluate(() => {
    const body = document.body.cloneNode(true) as HTMLElement;
    body.querySelectorAll('script[src*="hotshiny-dev"], [data-hotshiny-dev]').forEach((el) => el.remove());
    let html = body.outerHTML;

    // Random numbers that shiny itself regenerates on every render.
    const seen = new Map<string, string>();
    const canon = (raw: string) => {
      if (!seen.has(raw)) seen.set(raw, String(seen.size));
      return seen.get(raw)!;
    };
    html = html.replace(/session\/[0-9a-f]+\//g, 'session/TOKEN/');
    html = html.replace(/nonce=[0-9a-f]+/g, 'nonce=NONCE');
    // selectize generates random listbox ids, referenced via aria-owns
    for (const m of html.matchAll(/aria-owns="([a-z0-9]{6,})"/g)) {
      html = html.split(m[1]).join('selectize-' + canon(m[1]));
    }
    html = html.replace(/ui-tab-\d+/g, (m) => 'ui-tab-' + canon(m));
    html = html.replace(/(tab-)(\d{4})(-\d+)/g, (_m, a, n, b) => `${a}${canon(n)}${b}`);
    html = html.replace(/(data-tabsetid=")(\d+)(")/g, (_m, a, n, b) => `${a}${canon(n)}${b}`);
    html = html.replace(/(bslib-[a-z-]+-)(\d{3,})/g, (_m, a, n) => `${a}${canon(n)}`);
    html = html.replace(/(id="|for="|aria-labelledby="|aria-controls="|data-bs-target="#|href="#)(navbar-collapse-|nav-|bslib-)(\d+)/g,
      (_m, a, b, n) => `${a}${b}${canon(n)}`);

    const head = Array.from(document.querySelectorAll('script[src], link[rel="stylesheet"][href]'))
      .map((el) => (el as HTMLScriptElement).src || (el as HTMLLinkElement).href)
      .filter((u) => !/hotshiny-dev/.test(u))
      .map((u) => new URL(u).pathname);
    return { body: html, head };
  });
}

export interface PixelDiff {
  ratio: number;
  diffPng: Buffer;
}

export function diffScreenshots(a: Buffer, b: Buffer): PixelDiff {
  const pa = PNG.sync.read(a);
  const pb = PNG.sync.read(b);
  const width = Math.max(pa.width, pb.width);
  const height = Math.max(pa.height, pb.height);
  const pad = (p: PNG) => {
    if (p.width === width && p.height === height) return p;
    const out = new PNG({ width, height });
    PNG.bitblt(p, out, 0, 0, p.width, p.height, 0, 0);
    return out;
  };
  const A = pad(pa);
  const B = pad(pb);
  const diff = new PNG({ width, height });
  const n = pixelmatch(A.data, B.data, diff.data, width, height, { threshold: 0.1 });
  return { ratio: n / (width * height), diffPng: PNG.sync.write(diff) };
}

import { test, expect } from '@playwright/test';
import { startApp, RunningApp } from './server';
import { waitForIdle } from './fixtures';

export const MAX_PIXEL_DIFF = 0.002;

/**
 * Declare a parity test for a fixture: it is rendered by plain shiny (the
 * reference, produced by publish_to_shiny()) and by hotShiny; the live DOM
 * after shiny.js has initialised, the loaded dependencies, and the pixels
 * must match. `ready` waits for fixture-specific async content.
 */
export function parityTest(
  fixture: string,
  ready: (page: Page) => Promise<void> = async () => {},
  opts: { maxPixelDiff?: number } = {},
) {
  test.describe(`parity: ${fixture}`, () => {
    let ref: RunningApp;
    let hot: RunningApp;

    test.beforeAll(async () => {
      [ref, hot] = await Promise.all([
        startApp({ runtime: 'shiny', fixture }),
        startApp({ runtime: 'hotshiny', fixture }),
      ]);
    });
    test.afterAll(async () => {
      await Promise.all([ref?.stop(), hot?.stop()]);
    });

    async function load(page: Page, app: RunningApp) {
      await page.goto(app.url);
      await waitForIdle(page);
      await ready(page);
      await waitForIdle(page);
      await page.addStyleTag({
        content: '*,*::before,*::after{transition:none!important;animation:none!important;caret-color:transparent!important}',
      });
    }

    test('DOM, dependencies and pixels match shiny', async ({ browser }, testInfo) => {
      const refPage = await (await browser.newContext()).newPage();
      const hotPage = await (await browser.newContext()).newPage();
      await Promise.all([load(refPage, ref), load(hotPage, hot)]);

      const [refDom, hotDom] = await Promise.all([normalizedDom(refPage), normalizedDom(hotPage)]);
      expect.soft(hotDom.head, 'loaded <script>/<link> dependencies').toEqual(refDom.head);
      expect.soft(hotDom.body, 'normalised <body> markup').toBe(refDom.body);

      const [refShot, hotShot] = await Promise.all([
        refPage.screenshot({ fullPage: true }),
        hotPage.screenshot({ fullPage: true }),
      ]);
      const { ratio, diffPng } = diffScreenshots(refShot, hotShot);
      if (ratio > 0) {
        await testInfo.attach('shiny.png', { body: refShot, contentType: 'image/png' });
        await testInfo.attach('hotshiny.png', { body: hotShot, contentType: 'image/png' });
        await testInfo.attach('diff.png', { body: diffPng, contentType: 'image/png' });
      }
      expect.soft(ratio, 'fraction of differing pixels').toBeLessThanOrEqual(opts.maxPixelDiff ?? MAX_PIXEL_DIFF);
    });
  });
}
