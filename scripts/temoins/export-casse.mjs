const puppeteer = require('puppeteer');
(async () => {
  const b = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const p = await b.newPage();
  await p.goto('file:///x.html');
  await p.screenshot({ path: 'out.png' });
})();
