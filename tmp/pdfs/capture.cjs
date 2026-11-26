const { chromium } = require('C:/Users/HAMMAD PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('fs');
(async()=>{
fs.mkdirSync('tmp/pdfs/screens',{recursive:true});
const browser = await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
for(const screen of ['home','login','register','buddies','chat','activity','settings','sosbuddies','permissions','editprofile','privacy','pin']) {
const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,colorScheme:'light'});
const page=await context.newPage();
await page.route('https://www.gstatic.com/flutter-canvaskit/**', async route=>{
const url=route.request().url();
const suffix=url.includes('/chromium/')?'chromium/'+url.split('/').pop():url.split('/').pop();
await route.fulfill({path:'build/web/canvaskit/'+suffix});
});
page.on('pageerror',error=>console.log(String(error)));
await page.goto('http://127.0.0.1:8085/?screen='+screen);
await page.waitForSelector('flutter-view',{timeout:60000});
await page.waitForTimeout(10000);
await page.screenshot({path:'tmp/pdfs/screens/'+screen+'.png'});
await context.close();
console.log(screen);
}
await browser.close();
})();
