// 🧪 Setup Global para Playwright
// CNN Chile Infrastructure - Global Test Setup

const { chromium } = require('@playwright/test');

async function globalSetup() {
  console.log('🚀 Iniciando setup global de pruebas E2E...');
  
  // Crear contexto de navegador para setup
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    // Verificar que el sitio esté disponible
    console.log('📡 Verificando disponibilidad del sitio...');
    const baseURL = process.env.BASE_URL || 'https://dev.cnnchile.com';
    
    const response = await page.goto(baseURL, { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    
    if (!response.ok()) {
      throw new Error(`Sitio no disponible: ${response.status()} ${response.statusText()}`);
    }
    
    console.log('✅ Sitio web disponible');

    // Crear usuario de prueba si es necesario
    console.log('👤 Configurando usuario de prueba...');
    
    // Ir a página de registro
    await page.goto(`${baseURL}/registro`);
    
    // Llenar formulario de registro (si no existe el usuario)
    const testUser = {
      email: 'e2e-test@cnnchile.com',
      password: 'E2ETest123!',
      firstName: 'Test',
      lastName: 'User'
    };

    try {
      await page.fill('[data-testid="email-input"]', testUser.email);
      await page.fill('[data-testid="password-input"]', testUser.password);
      await page.fill('[data-testid="firstName-input"]', testUser.firstName);
      await page.fill('[data-testid="lastName-input"]', testUser.lastName);
      await page.click('[data-testid="register-button"]');
      
      // Esperar confirmación o redirección
      await page.waitForURL('**/dashboard', { timeout: 10000 });
      console.log('✅ Usuario de prueba creado');
    } catch (error) {
      // Usuario probablemente ya existe, intentar login
      console.log('👤 Usuario ya existe, verificando login...');
      
      await page.goto(`${baseURL}/login`);
      await page.fill('[data-testid="email-input"]', testUser.email);
      await page.fill('[data-testid="password-input"]', testUser.password);
      await page.click('[data-testid="login-button"]');
      
      await page.waitForURL('**/dashboard', { timeout: 10000 });
      console.log('✅ Usuario de prueba verificado');
    }

    // Guardar estado de autenticación
    const storage = await context.storageState();
    require('fs').writeFileSync('./tests/e2e/auth-state.json', JSON.stringify(storage));
    
    console.log('💾 Estado de autenticación guardado');

    // Crear suscripción premium para tests
    console.log('💎 Configurando suscripción premium...');
    
    await page.goto(`${baseURL}/suscripcion`);
    
    // Seleccionar plan premium (si no existe)
    try {
      await page.click('[data-testid="premium-plan-button"]');
      
      // Llenar datos de pago de prueba
      await page.fill('[data-testid="card-number"]', '4242424242424242');
      await page.fill('[data-testid="card-expiry"]', '12/25');
      await page.fill('[data-testid="card-cvc"]', '123');
      await page.fill('[data-testid="cardholder-name"]', 'Test User');
      
      await page.click('[data-testid="subscribe-button"]');
      
      await page.waitForSelector('[data-testid="subscription-success"]', { timeout: 15000 });
      console.log('✅ Suscripción premium configurada');
    } catch (error) {
      console.log('⚠️ No se pudo configurar suscripción premium (puede que ya exista)');
    }

    // Verificar APIs críticas
    console.log('🔍 Verificando APIs críticas...');
    
    const apiChecks = [
      '/api/v1/health',
      '/api/v1/news',
      '/api/v1/categories',
      '/api/v1/auth/status'
    ];

    for (const endpoint of apiChecks) {
      try {
        const apiResponse = await page.request.get(`${baseURL}${endpoint}`);
        if (apiResponse.ok()) {
          console.log(`✅ API ${endpoint} disponible`);
        } else {
          console.log(`⚠️ API ${endpoint} respondió con ${apiResponse.status()}`);
        }
      } catch (error) {
        console.log(`❌ API ${endpoint} falló: ${error.message}`);
      }
    }

  } catch (error) {
    console.error('❌ Error en setup global:', error.message);
    throw error;
  } finally {
    await browser.close();
  }

  console.log('🎉 Setup global completado exitosamente');
}

module.exports = globalSetup;
