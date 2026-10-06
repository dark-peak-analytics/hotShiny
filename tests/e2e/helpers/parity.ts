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
    // Class token order records which client-side initialiser ran first (e.g.
    // shiny binding vs. a plugin decorating the same element on window load),
    // which varies between loads of the same shiny app.
    body.querySelectorAll('[class]').forEach((el) => {
      el.setAttribute('class', Array.from(el.classList).sort().join(' '));
    });
    // OverlayScrollbars (bs4Dash's sidebar) sizes its invisible glue spacer
    // only if its update timer catches a size change after window load, which
    // varies between loads of the same shiny app.
    body.querySelectorAll<HTMLElement>('.os-content-glue').forEach((el) => {
      el.style.removeProperty('width');
      el.style.removeProperty('height');
    });
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
    // htmlwidgets gives statically rendered widgets a random id
    html = html.replace(/htmlwidget-[0-9a-f]{20}/g, (m) => 'htmlwidget-' + canon(m));
    // shinyWidgets' virtual-select numbers each instance randomly
    html = html.replace(/(vscomp-[a-z-]+-)(\d+)/g, (_m, a, n) => `${a}${canon('vscomp' + n)}`);
    // plotly.js gives every graph a random 6-hex uid (defs-<uid>, clip<uid>xy...)
    for (const m of html.matchAll(/id="defs-([0-9a-f]{6})"/g)) {
      html = html.split(m[1]).join('plotly' + canon(m[1]));
    }
    // ...and every trace without an explicit uid a random one (class "trace<uid>")
    html = html.replace(/(class="[^"]*\btrace)([0-9a-f]{6})(?=["\s])/g, (_m, a, u) => `${a}${canon(u)}`);
    // echarts stamps each instance with a timestamp id
    html = html.replace(/(_echarts_instance_="ec_)(\d+)"/g, (_m, a, n) => `${a}${canon(n)}"`);
    // highcharts containers get a random id per chart
    html = html.replace(/(highcharts-)([a-z0-9]{7})(-\d+)/g, (_m, a, n, b) => `${a}${canon(n)}${b}`);
    // ggiraph's girafe() names every svg with a random 16-hex id
    for (const m of html.matchAll(/id="svg_([0-9a-f]{16})_rootg"/g)) {
      html = html.split(m[1]).join('girafe' + canon(m[1]));
    }
    // shinyjs::onclick() names its hidden input with a random integer
    html = html.replace(/(shinyjs-[\w-]+?-)(\d+)(-input-click)/g, (_m, a, n, b) => `${a}${canon(n)}${b}`);
    // shinybusy: random spinner ids and SpinKit class suffixes
    html = html.replace(/(spin-)([0-9a-f]{24})\b/g, (_m, a, n) => `${a}${canon(n)}`);
    html = html.replace(/(sk-[a-z]+-)([a-z]{12})\b/g, (_m, a, n) => `${a}${canon(n)}`);
    // gt gives each rendered table a random 10-letter id, which scopes its <style>
    for (const m of html.matchAll(/<div id="([a-z]{10})" style="padding-left:/g)) {
      html = html.split(m[1]).join('gt-' + canon(m[1]));
    }
    html = html.replace(/ui-tab-\d+/g, (m) => 'ui-tab-' + canon(m));
    html = html.replace(/(tab-)(\d{4})(-\d+)/g, (_m, a, n, b) => `${a}${canon(n)}${b}`);
    html = html.replace(/(data-tabsetid=")(\d+)(")/g, (_m, a, n, b) => `${a}${canon(n)}${b}`);
    html = html.replace(/(bslib-[a-z-]+-)(\d{3,})/g, (_m, a, n) => `${a}${canon(n)}`);
    html = html.replace(/(id="|for="|aria-labelledby="|aria-controls="|data-bs-target="#|data-target="#|href="#)(navbar-collapse-|nav-|bslib-)(\d+)/g,
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
 * Wait until the DOM has stopped changing (or give up after `timeout`, for
 * pages that tick forever). Shiny being idle is not enough: client-side
 * widgets keep adjusting themselves afterwards (ion.rangeSlider re-measures
 * its labels on a timer once its stylesheet has applied), so comparing pages
 * loaded at different moments would compare different stages of that.
 */
async function domQuiet(page: Page, quietMs = 600, timeout = 4000) {
  await page.evaluate(
    ([quietMs, timeout]) =>
      new Promise<void>((resolve) => {
        const start = performance.now();
        let timer: ReturnType<typeof setTimeout>;
        const observer = new MutationObserver(() => arm());
        const done = () => {
          observer.disconnect();
          resolve();
        };
        const arm = () => {
          clearTimeout(timer);
          timer = setTimeout(done, Math.max(0, Math.min(quietMs, timeout - (performance.now() - start))));
        };
        observer.observe(document, { subtree: true, childList: true, attributes: true, characterData: true });
        arm();
      }),
    [quietMs, timeout],
  );
}

/**
 * Showcase mode lists the app's source. The reference runs the app as
 * converted by publish_to_shiny(), whose only change to these fixtures is
 * library(hotShiny) -> library(shiny); undo exactly that token in the listing
 * (DOM and pixels) so the rest of the source still has to match.
 */
async function canonicalizeShowcaseSource(page: Page) {
  await page.evaluate(() => {
    document.querySelectorAll('#showcase-code-content .identifier').forEach((el) => {
      const prev = el.previousElementSibling;
      const fn = prev?.previousElementSibling;
      if (el.textContent === 'hotShiny' && prev?.textContent === '(' && fn?.textContent === 'library') {
        el.textContent = 'shiny';
      }
    });
  });
}

/**
 * Declare a parity test for a fixture: it is rendered by plain shiny (the
 * reference, produced by publish_to_shiny()) and by hotShiny; the live DOM
 * after shiny.js has initialised, the loaded dependencies, and the pixels
 * must match. `ready` waits for fixture-specific async content.
 */
export function parityTest(
  fixture: string,
  ready: (page: Page) => Promise<void> = async () => {},
  opts: { maxPixelDiff?: number; seed?: number } = {},
) {
  test.describe(`parity: ${fixture}`, () => {
    let ref: RunningApp;
    let hot: RunningApp;

    test.beforeAll(async () => {
      [ref, hot] = await Promise.all([
        startApp({ runtime: 'shiny', fixture, seed: opts.seed }),
        startApp({ runtime: 'hotshiny', fixture, seed: opts.seed }),
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
      // jQuery effects (e.g. showcase mode's code highlighting) run on timers
      // the CSS override below cannot stop; let them finish. The first flush
      // can arrive just after waitForIdle() returns, so require a quiet
      // window rather than a single animation-free instant.
      await page.waitForFunction(
        () => {
          const w = window as any;
          const now = performance.now();
          if (w.jQuery && w.jQuery(':animated').length > 0) w.__hsLastAnimated = now;
          w.__hsLastAnimated ??= now;
          return now - w.__hsLastAnimated > 500;
        },
        null,
        { polling: 50 },
      );
      await canonicalizeShowcaseSource(page);
      await page.addStyleTag({
        content: '*,*::before,*::after{transition:none!important;animation:none!important;caret-color:transparent!important}',
      });
      await domQuiet(page);
    }

    test('DOM, dependencies and pixels match shiny', async ({ browser }, testInfo) => {
      const refPage = await (await browser.newContext()).newPage();
      const hotPage = await (await browser.newContext()).newPage();
      // One page at a time, so they do not compete for CPU while initialising.
      await load(refPage, ref);
      await load(hotPage, hot);

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
