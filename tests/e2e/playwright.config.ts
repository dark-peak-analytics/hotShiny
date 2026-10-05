import { defineConfig } from '@playwright/test';

// Behaviour specs run twice: against plain shiny (the reference, produced by
// hotShiny::publish_to_shiny()) and against hotShiny. Parity specs launch both
// runtimes side by side and diff DOM, dependencies and screenshots. Hot-reload
// specs only make sense for hotShiny.
const behaviour = /specs\/(behaviour|ecosystem)\/.*\.spec\.ts$/;

export default defineConfig({
  testDir: './specs',
  timeout: 60_000,
  expect: { timeout: 10_000, toHaveScreenshot: { maxDiffPixelRatio: 0.002 } },
  fullyParallel: false,
  workers: process.env.CI ? 4 : 6,
  reporter: [['list'], ['html', { open: 'never' }]],
  snapshotPathTemplate: '{testDir}/__screenshots__/{testFilePath}/{arg}{ext}',
  use: {
    channel: 'chrome',
    headless: true,
    viewport: { width: 1280, height: 900 },
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'shiny', testMatch: behaviour, use: { runtime: 'shiny' } as any },
    { name: 'hotshiny', testMatch: behaviour, use: { runtime: 'hotshiny' } as any },
    { name: 'parity', testMatch: /specs\/parity\/.*\.spec\.ts$/ },
    { name: 'hotreload', testMatch: /specs\/hotreload\/.*\.spec\.ts$/, use: { runtime: 'hotshiny' } as any },
  ],
});
