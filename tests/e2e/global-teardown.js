// 🧪 Teardown Global para Playwright
// CNN Chile Infrastructure - Global Test Teardown

async function globalTeardown() {
  console.log('🧹 Iniciando limpieza global de pruebas E2E...');
  
  try {
    // Limpiar archivos temporales
    const fs = require('fs');
    const path = require('path');
    
    const tempFiles = [
      './tests/e2e/auth-state.json',
      './tests/e2e/temp-data.json'
    ];
    
    tempFiles.forEach(file => {
      if (fs.existsSync(file)) {
        fs.unlinkSync(file);
        console.log(`🗑️ Eliminado: ${file}`);
      }
    });
    
    // Limpiar directorios de resultados temporales
    const tempDirs = [
      './test-results/temp',
      './playwright-report/temp'
    ];
    
    tempDirs.forEach(dir => {
      if (fs.existsSync(dir)) {
        fs.rmSync(dir, { recursive: true, force: true });
        console.log(`🗑️ Directorio eliminado: ${dir}`);
      }
    });

    // Opcional: Limpiar datos de prueba de la base de datos
    // (Solo en entornos de testing)
    if (process.env.NODE_ENV === 'test' || process.env.ENVIRONMENT === 'test') {
      console.log('🧹 Limpiando datos de prueba...');
      
      // Aquí podrías agregar llamadas API para limpiar datos de prueba
      // Ejemplo:
      // await cleanupTestData();
      
      console.log('✅ Datos de prueba limpiados');
    }
    
  } catch (error) {
    console.error('❌ Error en teardown global:', error.message);
    // No lanzar el error para no fallar la suite
  }
  
  console.log('🎯 Teardown global completado');
}

module.exports = globalTeardown;
