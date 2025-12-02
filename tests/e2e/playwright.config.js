// 🧪 Configuración de Playwright para Pruebas E2E
// CNN Chile Infrastructure - End-to-End Testing

import { defineConfig, devices } from '@playwright/test';

/**
 * @see https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './specs',
  
  /* Configuración de timeout */
  timeout: 30 * 1000,
  expect: {
    timeout: 5000
  },

  /* Ejecutar tests en paralelo */
  fullyParallel: true,
  
  /* Fallar la build si hay tests que no pasan en CI */
  forbidOnly: !!process.env.CI,
  
  /* Retry en CI */
  retries: process.env.CI ? 2 : 0,
  
  /* Workers paralelos */
  workers: process.env.CI ? 1 : undefined,

  /* Reporter para CI/CD */
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results/playwright-results.json' }],
    ['junit', { outputFile: 'test-results/playwright-junit.xml' }]
  ],

  /* Configuración global */
  use: {
    /* URL base para e2e tests */
    baseURL: process.env.BASE_URL || 'https://dev.cnnchile.com',

    /* Tracing solo en retry */
    trace: 'on-first-retry',
    
    /* Screenshots en fallas */
    screenshot: 'only-on-failure',
    
    /* Video en fallas */
    video: 'retain-on-failure',
    
    /* Configuraciones de navegador */
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true,
    
    /* API testing */
    extraHTTPHeaders: {
      'Accept': 'application/json',
      'User-Agent': 'Playwright E2E Tests'
    }
  },

  /* Configurar proyectos para diferentes navegadores */
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },

    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },

    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },

    /* Test en dispositivos móviles */
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },

    /* Test de Microsoft Edge */
    {
      name: 'Microsoft Edge',
      use: { ...devices['Desktop Edge'], channel: 'msedge' },
    },

    /* Test de Google Chrome */
    {
      name: 'Google Chrome',
      use: { ...devices['Desktop Chrome'], channel: 'chrome' },
    },
  ],

  /* Setup global */
  globalSetup: require.resolve('./global-setup.js'),
  globalTeardown: require.resolve('./global-teardown.js'),

  /* Servidor de desarrollo local */
  webServer: process.env.CI ? undefined : {
    command: 'npm run dev',
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
