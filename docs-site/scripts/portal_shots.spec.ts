import { test, expect, Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const OUT_DIR = `${__dirname}/.portal-shots`;
mkdirSync(OUT_DIR, { recursive: true });

const EMAIL = process.env.DEMO_ADMIN_EMAIL ?? 'demo-admin@transit.local';
const PASSWORD = process.env.DEMO_ADMIN_PASSWORD ?? 'DemoAdmin123!';

async function shot(page: Page, name: string) {
  await page.screenshot({ path: `${OUT_DIR}/${name}.png`, fullPage: true });
}

test('capture portal screenshots', async ({ page }) => {
  await page.goto('/login');
  await shot(page, 'login');

  await page.getByLabel('Email').fill(EMAIL);
  await page.getByLabel('Password').fill(PASSWORD);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('**/admin');
  await shot(page, 'admin_home');

  const pages: Array<[string, string]> = [
    ['/admin/dispatch', 'dispatch'],
    ['/admin/vehicles', 'vehicles'],
    ['/admin/routes', 'routes'],
    ['/admin/roster', 'roster'],
    ['/admin/drivers', 'drivers'],
    ['/admin/alerts', 'alerts'],
    ['/admin/incidents', 'incidents'],
    ['/admin/api-keys', 'api_keys'],
    ['/datasets', 'datasets'],
  ];

  for (const [path, name] of pages) {
    await page.goto(path);
    await expect(page).toHaveURL(new RegExp(path.replace('/', '\\/')));
    await shot(page, name);
  }
});
