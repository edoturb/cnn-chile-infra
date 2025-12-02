// 🧪 Pruebas E2E - Suscripciones y Contenido Premium
// CNN Chile Infrastructure

import { test, expect } from '@playwright/test';

test.describe('Suscripciones y Contenido Premium', () => {

  test.describe('Planes de Suscripción', () => {
    test('debe mostrar todos los planes disponibles', async ({ page }) => {
      await page.goto('/suscripcion');
      
      // Verificar que se muestran los planes
      await expect(page.locator('[data-testid="plan-basico"]')).toBeVisible();
      await expect(page.locator('[data-testid="plan-premium"]')).toBeVisible();
      await expect(page.locator('[data-testid="plan-premium-plus"]')).toBeVisible();
      
      // Verificar precios
      await expect(page.locator('[data-testid="plan-basico-price"]')).toContainText('$4.990');
      await expect(page.locator('[data-testid="plan-premium-price"]')).toContainText('$9.990');
      await expect(page.locator('[data-testid="plan-premium-plus-price"]')).toContainText('$14.990');
      
      // Verificar características de cada plan
      await expect(page.locator('[data-testid="plan-basico-features"]')).toContainText('Acceso a noticias');
      await expect(page.locator('[data-testid="plan-premium-features"]')).toContainText('Sin publicidad');
      await expect(page.locator('[data-testid="plan-premium-plus-features"]')).toContainText('Transmisión en vivo');
    });

    test('debe permitir comparar planes', async ({ page }) => {
      await page.goto('/suscripcion');
      
      await page.click('[data-testid="compare-plans-button"]');
      
      // Verificar tabla de comparación
      await expect(page.locator('[data-testid="comparison-table"]')).toBeVisible();
      
      // Verificar características comparadas
      await expect(page.locator('[data-testid="feature-noticias"]')).toBeVisible();
      await expect(page.locator('[data-testid="feature-sin-ads"]')).toBeVisible();
      await expect(page.locator('[data-testid="feature-streaming"]')).toBeVisible();
      await expect(page.locator('[data-testid="feature-descarga"]')).toBeVisible();
    });
  });

  test.describe('Proceso de Suscripción', () => {
    test.beforeEach(async ({ page }) => {
      // Login antes de suscribirse
      await page.goto('/login');
      await page.fill('[data-testid="email-input"]', 'e2e-test@cnnchile.com');
      await page.fill('[data-testid="password-input"]', 'E2ETest123!');
      await page.click('[data-testid="login-button"]');
    });

    test('debe permitir suscribirse al plan premium', async ({ page }) => {
      await page.goto('/suscripcion');
      
      // Seleccionar plan premium
      await page.click('[data-testid="select-premium-plan"]');
      
      // Verificar página de checkout
      await expect(page).toHaveURL(/.*\/checkout/);
      await expect(page.locator('[data-testid="selected-plan"]')).toContainText('Premium');
      
      // Llenar datos de pago
      await page.fill('[data-testid="card-number"]', '4242424242424242');
      await page.selectOption('[data-testid="card-month"]', '12');
      await page.selectOption('[data-testid="card-year"]', '2025');
      await page.fill('[data-testid="card-cvc"]', '123');
      await page.fill('[data-testid="cardholder-name"]', 'Test User');
      
      // Datos de facturación
      await page.fill('[data-testid="billing-address"]', 'Av. Providencia 123');
      await page.fill('[data-testid="billing-city"]', 'Santiago');
      await page.selectOption('[data-testid="billing-region"]', 'Región Metropolitana');
      
      // Procesar pago
      await page.click('[data-testid="process-payment-button"]');
      
      // Verificar página de confirmación
      await expect(page).toHaveURL(/.*\/suscripcion\/confirmacion/);
      await expect(page.locator('[data-testid="subscription-success"]'))
        .toContainText('Suscripción activada exitosamente');
    });

    test('debe manejar errores de tarjeta inválida', async ({ page }) => {
      await page.goto('/suscripcion');
      await page.click('[data-testid="select-premium-plan"]');
      
      // Usar número de tarjeta que genera error
      await page.fill('[data-testid="card-number"]', '4000000000000002');
      await page.selectOption('[data-testid="card-month"]', '12');
      await page.selectOption('[data-testid="card-year"]', '2025');
      await page.fill('[data-testid="card-cvc"]', '123');
      await page.fill('[data-testid="cardholder-name"]', 'Test User');
      
      await page.click('[data-testid="process-payment-button"]');
      
      // Verificar mensaje de error
      await expect(page.locator('[data-testid="payment-error"]'))
        .toContainText('tarjeta fue rechazada');
    });

    test('debe aplicar códigos de descuento', async ({ page }) => {
      await page.goto('/suscripcion');
      await page.click('[data-testid="select-premium-plan"]');
      
      // Aplicar código de descuento
      await page.fill('[data-testid="discount-code"]', 'DESCUENTO20');
      await page.click('[data-testid="apply-discount-button"]');
      
      // Verificar que se aplica el descuento
      await expect(page.locator('[data-testid="discount-applied"]')).toBeVisible();
      await expect(page.locator('[data-testid="discounted-price"]'))
        .toContainText('$7.992'); // 20% de descuento en $9.990
    });

    test('debe permitir cambio de plan mensual a anual', async ({ page }) => {
      await page.goto('/suscripcion');
      
      // Cambiar a facturación anual
      await page.click('[data-testid="billing-annual-toggle"]');
      
      // Verificar que los precios cambian
      await expect(page.locator('[data-testid="plan-premium-price"]'))
        .toContainText('$99.900'); // Precio anual
      
      // Verificar mensaje de ahorro
      await expect(page.locator('[data-testid="annual-savings"]'))
        .toContainText('Ahorra 20%');
    });
  });

  test.describe('Gestión de Suscripción', () => {
    test.beforeEach(async ({ page }) => {
      // Login con usuario que ya tiene suscripción
      await page.goto('/login');
      await page.fill('[data-testid="email-input"]', 'premium@example.com');
      await page.fill('[data-testid="password-input"]', 'Premium123!');
      await page.click('[data-testid="login-button"]');
    });

    test('debe mostrar estado de suscripción actual', async ({ page }) => {
      await page.goto('/mi-suscripcion');
      
      // Verificar información de la suscripción
      await expect(page.locator('[data-testid="current-plan"]')).toContainText('Premium');
      await expect(page.locator('[data-testid="subscription-status"]')).toContainText('Activa');
      await expect(page.locator('[data-testid="next-billing"]')).toBeVisible();
      await expect(page.locator('[data-testid="payment-method"]')).toContainText('****2424');
    });

    test('debe permitir actualizar método de pago', async ({ page }) => {
      await page.goto('/mi-suscripcion');
      
      await page.click('[data-testid="update-payment-button"]');
      
      // Cambiar tarjeta
      await page.fill('[data-testid="new-card-number"]', '4111111111111111');
      await page.selectOption('[data-testid="new-card-month"]', '06');
      await page.selectOption('[data-testid="new-card-year"]', '2026');
      await page.fill('[data-testid="new-card-cvc"]', '456');
      
      await page.click('[data-testid="save-payment-method"]');
      
      // Verificar actualización
      await expect(page.locator('[data-testid="payment-updated"]'))
        .toContainText('Método de pago actualizado');
      await expect(page.locator('[data-testid="payment-method"]'))
        .toContainText('****1111');
    });

    test('debe permitir cambiar de plan', async ({ page }) => {
      await page.goto('/mi-suscripcion');
      
      await page.click('[data-testid="change-plan-button"]');
      
      // Seleccionar Premium Plus
      await page.click('[data-testid="upgrade-to-premium-plus"]');
      
      // Confirmar cambio
      await page.click('[data-testid="confirm-plan-change"]');
      
      // Verificar cambio
      await expect(page.locator('[data-testid="plan-change-success"]'))
        .toContainText('Plan actualizado');
      await expect(page.locator('[data-testid="current-plan"]'))
        .toContainText('Premium Plus');
    });

    test('debe permitir pausar suscripción', async ({ page }) => {
      await page.goto('/mi-suscripcion');
      
      await page.click('[data-testid="pause-subscription-button"]');
      
      // Seleccionar duración de pausa
      await page.selectOption('[data-testid="pause-duration"]', '1-month');
      await page.fill('[data-testid="pause-reason"]', 'Vacaciones de verano');
      
      await page.click('[data-testid="confirm-pause"]');
      
      // Verificar pausa
      await expect(page.locator('[data-testid="subscription-paused"]'))
        .toContainText('Suscripción pausada');
    });

    test('debe permitir cancelar suscripción', async ({ page }) => {
      await page.goto('/mi-suscripcion');
      
      await page.click('[data-testid="cancel-subscription-button"]');
      
      // Proceso de retención
      await expect(page.locator('[data-testid="retention-offer"]')).toBeVisible();
      
      // Rechazar oferta y continuar con cancelación
      await page.click('[data-testid="decline-offer-button"]');
      
      // Seleccionar razón de cancelación
      await page.selectOption('[data-testid="cancellation-reason"]', 'too-expensive');
      await page.fill('[data-testid="cancellation-feedback"]', 'Muy caro para el contenido ofrecido');
      
      // Confirmar cancelación
      await page.check('[data-testid="confirm-cancellation-checkbox"]');
      await page.click('[data-testid="final-cancel-button"]');
      
      // Verificar cancelación
      await expect(page.locator('[data-testid="cancellation-confirmed"]'))
        .toContainText('Suscripción cancelada');
      
      // Verificar que mantiene acceso hasta el final del período
      await expect(page.locator('[data-testid="access-until"]')).toBeVisible();
    });
  });

  test.describe('Contenido Premium', () => {
    test.beforeEach(async ({ page }) => {
      // Login con usuario premium
      await page.goto('/login');
      await page.fill('[data-testid="email-input"]', 'premium@example.com');
      await page.fill('[data-testid="password-input"]', 'Premium123!');
      await page.click('[data-testid="login-button"]');
    });

    test('debe acceder a contenido exclusivo', async ({ page }) => {
      await page.goto('/premium');
      
      // Verificar acceso a contenido premium
      await expect(page.locator('[data-testid="premium-content"]')).toBeVisible();
      await expect(page.locator('[data-testid="exclusive-articles"]')).toBeVisible();
      
      // Verificar ausencia de publicidad
      await expect(page.locator('[data-testid="advertisement"]')).not.toBeVisible();
    });

    test('debe acceder a transmisión en vivo premium', async ({ page }) => {
      await page.goto('/en-vivo');
      
      // Verificar acceso a streams premium
      await expect(page.locator('[data-testid="premium-stream"]')).toBeVisible();
      await expect(page.locator('[data-testid="hd-quality-selector"]')).toBeVisible();
      
      // Verificar controles avanzados
      await expect(page.locator('[data-testid="rewind-button"]')).toBeVisible();
      await expect(page.locator('[data-testid="download-button"]')).toBeVisible();
    });

    test('debe descargar contenido para offline', async ({ page }) => {
      await page.goto('/premium/articulos');
      
      // Seleccionar artículo para descargar
      const firstArticle = page.locator('[data-testid="premium-article"]').first();
      await firstArticle.hover();
      
      await page.click('[data-testid="download-article-button"]');
      
      // Verificar que se inicia la descarga
      await expect(page.locator('[data-testid="download-progress"]')).toBeVisible();
      
      // Ir a descargas
      await page.goto('/mi-cuenta/descargas');
      
      // Verificar que aparece en la lista
      await expect(page.locator('[data-testid="downloaded-content"]')).toHaveCountGreaterThan(0);
    });
  });

  test.describe('Facturación e Historial', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/login');
      await page.fill('[data-testid="email-input"]', 'premium@example.com');
      await page.fill('[data-testid="password-input"]', 'Premium123!');
      await page.click('[data-testid="login-button"]');
    });

    test('debe mostrar historial de facturación', async ({ page }) => {
      await page.goto('/mi-cuenta/facturacion');
      
      // Verificar lista de facturas
      await expect(page.locator('[data-testid="invoice-list"]')).toBeVisible();
      
      // Verificar detalles de factura
      const latestInvoice = page.locator('[data-testid="invoice-item"]').first();
      await expect(latestInvoice.locator('[data-testid="invoice-date"]')).toBeVisible();
      await expect(latestInvoice.locator('[data-testid="invoice-amount"]')).toBeVisible();
      await expect(latestInvoice.locator('[data-testid="invoice-status"]')).toContainText('Pagada');
    });

    test('debe descargar factura en PDF', async ({ page }) => {
      await page.goto('/mi-cuenta/facturacion');
      
      // Configurar listener para descarga
      const downloadPromise = page.waitForEvent('download');
      
      // Click en descargar primera factura
      await page.click('[data-testid="download-invoice-button"]');
      
      const download = await downloadPromise;
      expect(download.suggestedFilename()).toContain('.pdf');
    });

    test('debe mostrar próxima facturación', async ({ page }) => {
      await page.goto('/mi-suscripcion');
      
      // Verificar información de próximo cobro
      await expect(page.locator('[data-testid="next-billing-date"]')).toBeVisible();
      await expect(page.locator('[data-testid="next-billing-amount"]')).toBeVisible();
      
      // Verificar que la fecha es futura
      const nextBillingText = await page.locator('[data-testid="next-billing-date"]').textContent();
      const nextBillingDate = new Date(nextBillingText);
      const today = new Date();
      expect(nextBillingDate.getTime()).toBeGreaterThan(today.getTime());
    });
  });

});
