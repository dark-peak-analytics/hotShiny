import { expect } from '@playwright/test';
import { parityTest } from '../../helpers/parity';

parityTest('eco-jstreer', async (page) => {
  await expect(page.locator('#tree .jstree-anchor', { hasText: 'Apple' })).toBeVisible();
  // jstree reports its selection inputs once its async 'ready' fires, which
  // can land after the idle window.
  await page.waitForFunction(() =>
    Object.keys((window as any).Shiny.shinyapp.$inputValues).some((k) => k.startsWith('tree_checked')));
});
