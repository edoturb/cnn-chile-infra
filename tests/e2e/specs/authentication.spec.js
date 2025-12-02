// 🧪 Pruebas E2E - Autenticación y Usuario
// CNN Chile Infrastructure

import { test, expect } from '@playwright/test';

test.describe('Autenticación y Gestión de Usuario', () => {

  test.describe('Registro de Usuario', () => {
    test('debe permitir registro de nuevo usuario', async ({ page }) => {
      await page.goto('/registro');

      // Llenar formulario de registro
      const timestamp = Date.now();
      const testEmail = `test${timestamp}@example.com`;
      
      await page.fill('[data-testid="firstName-input"]', 'Juan');
      await page.fill('[data-testid="lastName-input"]', 'Pérez');
      await page.fill('[data-testid="email-input"]', testEmail);
      await page.fill('[data-testid="password-input"]', 'Password123!');
      await page.fill('[data-testid="confirmPassword-input"]', 'Password123!');
      
      // Aceptar términos
      await page.check('[data-testid="terms-checkbox"]');
      
      // Enviar formulario
      await page.click('[data-testid="register-button"]');
      
      // Verificar redirección a dashboard
      await expect(page).toHaveURL(/.*\/dashboard/);
      
      // Verificar mensaje de bienvenida
      await expect(page.locator('[data-testid="welcome-message"]')).toContainText('Juan');
    });

    test('debe mostrar errores de validación', async ({ page }) => {
      await page.goto('/registro');

      // Intentar registrar sin datos
      await page.click('[data-testid="register-button"]');
      
      // Verificar mensajes de error
      await expect(page.locator('[data-testid="firstName-error"]')).toBeVisible();
      await expect(page.locator('[data-testid="email-error"]')).toBeVisible();
      await expect(page.locator('[data-testid="password-error"]')).toBeVisible();
    });

    test('debe validar formato de email', async ({ page }) => {
      await page.goto('/registro');

      await page.fill('[data-testid="email-input"]', 'email-invalido');
      await page.blur('[data-testid="email-input"]');
      
      await expect(page.locator('[data-testid="email-error"]'))
        .toContainText('formato de email válido');
    });

    test('debe validar fortaleza de contraseña', async ({ page }) => {
      await page.goto('/registro');

      // Contraseña débil
      await page.fill('[data-testid="password-input"]', '123');
      await page.blur('[data-testid="password-input"]');
      
      await expect(page.locator('[data-testid="password-strength"]'))
        .toContainText('débil');
      
      // Contraseña fuerte
      await page.fill('[data-testid="password-input"]', 'Password123!');
      await page.blur('[data-testid="password-input"]');
      
      await expect(page.locator('[data-testid="password-strength"]'))
        .toContainText('fuerte');
    });
  });

  test.describe('Inicio de Sesión', () => {
    test('debe permitir login con credenciales válidas', async ({ page }) => {
      await page.goto('/login');

      await page.fill('[data-testid="email-input"]', 'e2e-test@cnnchile.com');
      await page.fill('[data-testid="password-input"]', 'E2ETest123!');
      
      await page.click('[data-testid="login-button"]');
      
      // Verificar redirección exitosa
      await expect(page).toHaveURL(/.*\/dashboard/);
      
      // Verificar que aparece el menú de usuario
      await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
    });

    test('debe mostrar error con credenciales inválidas', async ({ page }) => {
      await page.goto('/login');

      await page.fill('[data-testid="email-input"]', 'invalido@example.com');
      await page.fill('[data-testid="password-input"]', 'WrongPassword');
      
      await page.click('[data-testid="login-button"]');
      
      // Verificar mensaje de error
      await expect(page.locator('[data-testid="login-error"]'))
        .toContainText('Credenciales inválidas');
    });

    test('debe funcionar "Recordar sesión"', async ({ page }) => {
      await page.goto('/login');

      await page.fill('[data-testid="email-input"]', 'e2e-test@cnnchile.com');
      await page.fill('[data-testid="password-input"]', 'E2ETest123!');
      await page.check('[data-testid="remember-me-checkbox"]');
      
      await page.click('[data-testid="login-button"]');
      
      // Verificar que se guardó la sesión
      await page.reload();
      await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
    });
  });

  test.describe('Recuperación de Contraseña', () => {
    test('debe enviar email de recuperación', async ({ page }) => {
      await page.goto('/login');
      
      await page.click('[data-testid="forgot-password-link"]');
      
      await expect(page).toHaveURL(/.*\/recuperar-password/);
      
      await page.fill('[data-testid="email-input"]', 'e2e-test@cnnchile.com');
      await page.click('[data-testid="send-reset-button"]');
      
      // Verificar mensaje de confirmación
      await expect(page.locator('[data-testid="reset-confirmation"]'))
        .toContainText('email de recuperación enviado');
    });
  });

  test.describe('Perfil de Usuario', () => {
    test.beforeEach(async ({ page }) => {
      // Login antes de cada test
      await page.goto('/login');
      await page.fill('[data-testid="email-input"]', 'e2e-test@cnnchile.com');
      await page.fill('[data-testid="password-input"]', 'E2ETest123!');
      await page.click('[data-testid="login-button"]');
      await expect(page).toHaveURL(/.*\/dashboard/);
    });

    test('debe mostrar información del perfil', async ({ page }) => {
      await page.click('[data-testid="user-menu"]');
      await page.click('[data-testid="profile-link"]');
      
      await expect(page).toHaveURL(/.*\/perfil/);
      
      // Verificar campos del perfil
      await expect(page.locator('[data-testid="profile-name"]')).toBeVisible();
      await expect(page.locator('[data-testid="profile-email"]')).toBeVisible();
      await expect(page.locator('[data-testid="profile-avatar"]')).toBeVisible();
    });

    test('debe permitir editar información personal', async ({ page }) => {
      await page.goto('/perfil');
      
      await page.click('[data-testid="edit-profile-button"]');
      
      // Cambiar nombre
      await page.fill('[data-testid="firstName-input"]', 'Juan Carlos');
      await page.fill('[data-testid="lastName-input"]', 'Pérez García');
      
      await page.click('[data-testid="save-profile-button"]');
      
      // Verificar mensaje de éxito
      await expect(page.locator('[data-testid="save-success"]'))
        .toContainText('Perfil actualizado');
    });

    test('debe permitir cambiar contraseña', async ({ page }) => {
      await page.goto('/perfil');
      
      await page.click('[data-testid="change-password-tab"]');
      
      await page.fill('[data-testid="current-password"]', 'E2ETest123!');
      await page.fill('[data-testid="new-password"]', 'NewPassword123!');
      await page.fill('[data-testid="confirm-password"]', 'NewPassword123!');
      
      await page.click('[data-testid="change-password-button"]');
      
      // Verificar mensaje de éxito
      await expect(page.locator('[data-testid="password-change-success"]'))
        .toContainText('Contraseña actualizada');
    });

    test('debe permitir subir avatar', async ({ page }) => {
      await page.goto('/perfil');
      
      // Simular subida de archivo
      const fileChooserPromise = page.waitForEvent('filechooser');
      await page.click('[data-testid="upload-avatar-button"]');
      const fileChooser = await fileChooserPromise;
      
      // En un test real, aquí usarías un archivo real
      // fileChooser.setFiles('path/to/test-image.jpg');
      
      // Por ahora, verificar que se abrió el selector
      expect(fileChooser).toBeTruthy();
    });
  });

  test.describe('Preferencias y Configuración', () => {
    test.beforeEach(async ({ page }) => {
      // Login antes de cada test
      await page.goto('/login');
      await page.fill('[data-testid="email-input"]', 'e2e-test@cnnchile.com');
      await page.fill('[data-testid="password-input"]', 'E2ETest123!');
      await page.click('[data-testid="login-button"]');
      await page.goto('/configuracion');
    });

    test('debe permitir configurar notificaciones', async ({ page }) => {
      // Desactivar notificaciones de email
      await page.uncheck('[data-testid="email-notifications"]');
      
      // Activar notificaciones push
      await page.check('[data-testid="push-notifications"]');
      
      await page.click('[data-testid="save-preferences-button"]');
      
      await expect(page.locator('[data-testid="preferences-saved"]'))
        .toContainText('Preferencias guardadas');
    });

    test('debe permitir seleccionar categorías de interés', async ({ page }) => {
      await page.click('[data-testid="interests-tab"]');
      
      // Seleccionar categorías
      await page.check('[data-testid="category-deportes"]');
      await page.check('[data-testid="category-tecnologia"]');
      await page.uncheck('[data-testid="category-economia"]');
      
      await page.click('[data-testid="save-interests-button"]');
      
      await expect(page.locator('[data-testid="interests-saved"]'))
        .toContainText('Intereses actualizados');
    });
  });

  test.describe('Logout', () => {
    test('debe cerrar sesión correctamente', async ({ page }) => {
      // Login primero
      await page.goto('/login');
      await page.fill('[data-testid="email-input"]', 'e2e-test@cnnchile.com');
      await page.fill('[data-testid="password-input"]', 'E2ETest123!');
      await page.click('[data-testid="login-button"]');
      
      // Logout
      await page.click('[data-testid="user-menu"]');
      await page.click('[data-testid="logout-button"]');
      
      // Verificar redirección a homepage
      await expect(page).toHaveURL(/.*\/(login)?$/);
      
      // Verificar que no hay menú de usuario
      await expect(page.locator('[data-testid="user-menu"]')).not.toBeVisible();
    });
  });

});
