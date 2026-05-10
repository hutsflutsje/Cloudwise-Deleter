const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  await page.goto('file://' + process.cwd() + '/index.html');

  // Full page
  await page.screenshot({ path: '/home/jules/verification/v2_full.png', fullPage: true });

  // Hover over header to see flicker/glow
  await page.hover('header h1');
  await page.screenshot({ path: '/home/jules/verification/v2_header_hover.png' });

  // Hover over footer gear
  await page.hover('.hidden-gear');
  await page.screenshot({ path: '/home/jules/verification/v2_footer_gear.png' });

  await browser.close();
})();
