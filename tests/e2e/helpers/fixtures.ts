import { test as base, expect, Page } from '@playwright/test';
import { startApp, RunningApp, Runtime } from './server';

type WorkerFixtures = {
  runtime: Runtime;
  fixture: string;
  app: RunningApp;
};

type TestFixtures = {
  /** Navigate to the app and wait until shiny is connected and idle. */
  open: (path?: string) => Promise<Page>;
  /** Uncaught page errors collected during the test; asserted empty at the end. */
  pageErrors: string[];
};

export const test = base.extend<TestFixtures, WorkerFixtures>({
  runtime: ['hotshiny', { scope: 'worker', option: true }],
  fixture: ['core-inputs', { scope: 'worker', option: true }],

  app: [
    async ({ runtime, fixture }, use) => {
      const app = await startApp({ runtime, fixture });
      await use(app);
      await app.stop();
    },
    { scope: 'worker', timeout: 90_000 },
  ],

  pageErrors: async ({ page }, use) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    await use(errors);
    expect(errors, 'uncaught browser errors').toEqual([]);
  },

  open: async ({ page, app, pageErrors }, use) => {
    void pageErrors;
    await use(async (p = '') => {
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

export { expect };

/** Wait until shiny.js has connected, initialised the session and is not busy. */
export async function waitForIdle(page: Page, timeout = 20_000) {
  await page.waitForFunction(
    () => {
      const w = window as any;
      return !!(w.Shiny && w.Shiny.shinyapp && w.Shiny.shinyapp.isConnected && w.Shiny.shinyapp.isConnected());
    },
    null,
    { timeout },
  );
  await settle(page, timeout);
}

/** Wait until the page has not been shiny-busy for a short, stable window. */
export async function settle(page: Page, timeout = 20_000) {
  await page.waitForFunction(
    () => {
      const w = window as any;
      const busy = document.documentElement.classList.contains('shiny-busy');
      const now = performance.now();
      if (busy || w.__hsLastBusy === undefined) {
        w.__hsLastBusy = now;
        return false;
      }
      return now - w.__hsLastBusy > 250;
    },
    null,
    { timeout, polling: 50 },
  );
}

/** Value shiny's client currently holds for an input (as last sent to the server). */
export async function inputValue(page: Page, id: string) {
  return page.evaluate((id) => (window as any).Shiny.shinyapp.$inputValues[id], id);
}
