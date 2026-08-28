import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  testMatch: 'portal_shots.spec.ts',
  timeout: 30_000,
  use: {
    baseURL: process.env.PORTAL_URL ?? 'http://localhost:3000',
    viewport: { width: 1440, height: 900 },
  },
  outputDir: '.portal-shots-tmp',
  reporter: 'list',
});
