// Screenshots and a short video of the dock: collapsed, expanded, one question answered.
//   PW_DIR=<dir with playwright-core installed> node scripts/capture.mjs [dashboardId] [question]
// Writes to media/ (gitignored). A step that fails stops the run: nothing is faked.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';

const require = createRequire(path.join(process.env.PW_DIR ?? process.cwd(), '/'));
const { chromium } = require('playwright-core');

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const MEDIA = path.join(ROOT, 'media');
const SUPERSET = process.env.SUPERSET_URL ?? 'http://localhost:8088';
const AGENT = process.env.AGENT_URL ?? 'http://localhost:5005';
const dashboard = process.argv[2] ?? '1';
const question = process.argv[3] ?? 'что показывает этот дашборд?';
fs.mkdirSync(MEDIA, { recursive: true });
const videoDir = path.join(ROOT, '.work', 'video');
fs.rmSync(videoDir, { recursive: true, force: true });

const browser = await chromium.launch();
const ctx = await browser.newContext({
	viewport: { width: 1440, height: 900 },
	recordVideo: { dir: videoDir, size: { width: 1440, height: 900 } },
});
const page = await ctx.newPage();
const t0 = Date.now();
const mark = (label) => console.log(`${((Date.now() - t0) / 1000).toFixed(1)}s ${label}`);

// Sign in to both apps first; the dock then reuses the agent's session cookie.
await page.goto(`${AGENT}/login`);
await page.fill('input[type=email]', 'demo@example.com');
await page.fill('input[type=password]', 'demo-password-123');
await page.click('button[type=submit]');
await page.waitForURL((u) => !u.pathname.startsWith('/login'), { timeout: 30000 });
await page.goto(`${SUPERSET}/login/`);
await page.fill('#username, input[name=username]', 'admin');
await page.fill('#password, input[name=password]', 'admin');
await page.click('input[type=submit], button[type=submit], [data-test=login-button]');
await page.waitForURL((u) => !u.pathname.startsWith('/login'), { timeout: 30000 });
mark('signed in');

// The video starts here, on the dashboard.
await page.goto(`${SUPERSET}/superset/dashboard/${dashboard}/`);
await page.waitForSelector('.dashboard-markdown details > iframe', { state: 'attached', timeout: 60000 });
await page.waitForTimeout(6000);
await page.screenshot({ path: path.join(MEDIA, 'dashboard-dock-collapsed.png') });
mark('collapsed screenshot');
const videoStart = (Date.now() - t0) / 1000;

await page.click('.dashboard-markdown details:has(> iframe) > summary');
const frame = page.frameLocator('.dashboard-markdown details > iframe');
const input = frame.locator('textarea, [contenteditable=true]').first();
await input.waitFor({ timeout: 30000 });
await page.waitForTimeout(1500);
await page.screenshot({ path: path.join(MEDIA, 'dashboard-dock-expanded.png') });
mark('expanded screenshot');

await input.click();
await page.keyboard.type(question, { delay: 40 });
await page.keyboard.press('Enter');
mark('question sent');

// Done when the assistant text stops changing for 6 s after the first non-empty reply.
const body = frame.locator('body');
let last = '';
let stableSince = Date.now();
const deadline = Date.now() + 120000;
const baseline = (await body.innerText()).length;
while (Date.now() < deadline) {
	await page.waitForTimeout(1000);
	const text = await body.innerText();
	if (text !== last) {
		last = text;
		stableSince = Date.now();
	} else if (text.length > baseline + 200 && Date.now() - stableSince > 6000) break;
}
if (last.length <= baseline + 200) throw new Error('no answer appeared in the dock');
await page.screenshot({ path: path.join(MEDIA, 'dock-answer.png') });
mark('answer screenshot');
fs.writeFileSync(path.join(ROOT, '.work', 'answer.txt'), last);
fs.writeFileSync(path.join(ROOT, '.work', 'video-start.txt'), String(videoStart));

await ctx.close();
await browser.close();
mark('done');
