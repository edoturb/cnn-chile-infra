// 🧪 Pruebas E2E - Homepage y Navegación
// CNN Chile Infrastructure

import { test, expect } from '@playwright/test';

test.describe('Homepage y Navegación Principal', () => {
  
  test.beforeEach(async ({ page }) => {
    // Ir a la página principal
    await page.goto('/');
  });

  test('debe cargar la homepage correctamente', async ({ page }) => {
    // Verificar título
    await expect(page).toHaveTitle(/CNN Chile/);
    
    // Verificar elementos principales
    await expect(page.locator('[data-testid="main-logo"]')).toBeVisible();
    await expect(page.locator('[data-testid="main-navigation"]')).toBeVisible();
    await expect(page.locator('[data-testid="news-grid"]')).toBeVisible();
    
    // Verificar que hay noticias
    const newsItems = page.locator('[data-testid="news-item"]');
    await expect(newsItems).toHaveCountGreaterThan(0);
  });

  test('debe mostrar las secciones principales en el menú', async ({ page }) => {
    const navigation = page.locator('[data-testid="main-navigation"]');
    
    // Verificar secciones principales
    await expect(navigation.locator('text=Nacional')).toBeVisible();
    await expect(navigation.locator('text=Internacional')).toBeVisible();
    await expect(navigation.locator('text=Deportes')).toBeVisible();
    await expect(navigation.locator('text=Economía')).toBeVisible();
    await expect(navigation.locator('text=Tecnología')).toBeVisible();
    await expect(navigation.locator('text=En Vivo')).toBeVisible();
  });

  test('debe navegar a sección de noticias', async ({ page }) => {
    // Click en sección Nacional
    await page.click('[data-testid="nav-nacional"]');
    
    // Verificar que navega correctamente
    await expect(page).toHaveURL(/.*\/nacional/);
    await expect(page.locator('h1')).toContainText('Nacional');
    
    // Verificar que hay contenido
    const newsItems = page.locator('[data-testid="news-item"]');
    await expect(newsItems).toHaveCountGreaterThan(0);
  });

  test('debe funcionar la búsqueda', async ({ page }) => {
    // Abrir búsqueda
    await page.click('[data-testid="search-button"]');
    
    // Escribir término de búsqueda
    await page.fill('[data-testid="search-input"]', 'política');
    await page.press('[data-testid="search-input"]', 'Enter');
    
    // Verificar resultados
    await expect(page).toHaveURL(/.*\/buscar/);
    await expect(page.locator('[data-testid="search-results"]')).toBeVisible();
    
    // Verificar que hay resultados
    const results = page.locator('[data-testid="search-result"]');
    await expect(results).toHaveCountGreaterThan(0);
  });

  test('debe ser responsive en móvil', async ({ page }) => {
    // Cambiar a viewport móvil
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Verificar que el menú hamburguesa está visible
    await expect(page.locator('[data-testid="mobile-menu-button"]')).toBeVisible();
    
    // Abrir menú móvil
    await page.click('[data-testid="mobile-menu-button"]');
    
    // Verificar que el menú se despliega
    await expect(page.locator('[data-testid="mobile-menu"]')).toBeVisible();
    
    // Verificar navegación móvil
    await page.click('[data-testid="mobile-nav-deportes"]');
    await expect(page).toHaveURL(/.*\/deportes/);
  });

  test('debe cargar contenido dinámicamente al hacer scroll', async ({ page }) => {
    // Contar noticias iniciales
    const initialNews = await page.locator('[data-testid="news-item"]').count();
    
    // Hacer scroll hasta abajo
    await page.evaluate(() => {
      window.scrollTo(0, document.body.scrollHeight);
    });
    
    // Esperar que carguen más noticias
    await page.waitForTimeout(2000);
    
    // Verificar que hay más noticias
    const newCount = await page.locator('[data-testid="news-item"]').count();
    expect(newCount).toBeGreaterThan(initialNews);
  });

  test('debe mostrar hora local correctamente', async ({ page }) => {
    // Verificar que se muestra la hora
    await expect(page.locator('[data-testid="current-time"]')).toBeVisible();
    
    // Verificar formato de hora (HH:MM)
    const timeText = await page.locator('[data-testid="current-time"]').textContent();
    expect(timeText).toMatch(/\d{2}:\d{2}/);
  });

  test('debe funcionar el botón de compartir', async ({ page }) => {
    // Click en primera noticia
    const firstNews = page.locator('[data-testid="news-item"]').first();
    await firstNews.click();
    
    // Verificar que estamos en la página del artículo
    await expect(page).toHaveURL(/.*\/noticias\/.*/);
    
    // Click en botón compartir
    await page.click('[data-testid="share-button"]');
    
    // Verificar que aparece el menú de compartir
    await expect(page.locator('[data-testid="share-menu"]')).toBeVisible();
    
    // Verificar opciones de compartir
    await expect(page.locator('[data-testid="share-facebook"]')).toBeVisible();
    await expect(page.locator('[data-testid="share-twitter"]')).toBeVisible();
    await expect(page.locator('[data-testid="share-whatsapp"]')).toBeVisible();
  });

});
