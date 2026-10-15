import { parityTest } from '../../helpers/parity';

parityTest('eco-echarts4r', async (page) => {
  await page.waitForFunction(() => {
    const w = window as any;
    const c = w.echarts && w.echarts.getInstanceByDom(document.getElementById('bars'));
    return !!c && c.getOption().series.length > 0;
  });
});
