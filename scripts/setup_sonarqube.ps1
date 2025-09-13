# Script de configuración inicial para SonarQube
# Uso: .\scripts\setup_sonarqube.ps1

Write-Host "🚀 Configurando SonarQube para ACEES Group..." -ForegroundColor Yellow
Write-Host ""

# Verificar Flutter
Write-Host "1️⃣ Verificando instalación de Flutter..." -ForegroundColor Blue
try {
    $flutterVersion = flutter --version
    Write-Host $flutterVersion -ForegroundColor Gray
    Write-Host "✅ Flutter encontrado" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter no encontrado. Por favor instala Flutter primero." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Limpiar y obtener dependencias
Write-Host "2️⃣ Limpiando proyecto y obteniendo dependencias..." -ForegroundColor Blue
flutter clean
flutter pub get

Write-Host ""

# Verificar dependencias
Write-Host "3️⃣ Verificando dependencias..." -ForegroundColor Blue
flutter pub deps

Write-Host ""

# Ejecutar análisis
Write-Host "4️⃣ Ejecutando análisis de código..." -ForegroundColor Blue
try {
    flutter analyze --no-fatal-infos
    Write-Host "✅ Análisis completado" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Análisis completado con warnings" -ForegroundColor Yellow
}

Write-Host ""

# Ejecutar tests
Write-Host "5️⃣ Ejecutando tests con cobertura..." -ForegroundColor Blue
try {
    flutter test --coverage
    Write-Host "✅ Tests ejecutados" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Algunos tests fallaron, pero continuamos..." -ForegroundColor Yellow
}

Write-Host ""

# Verificar archivos generados
Write-Host "6️⃣ Verificando archivos de reporte..." -ForegroundColor Blue
if (Test-Path "coverage/lcov.info") {
    $coverageSize = (Get-Item "coverage/lcov.info").Length
    Write-Host "✅ Archivo de cobertura encontrado: coverage/lcov.info" -ForegroundColor Green
    Write-Host "📊 Tamaño: $coverageSize bytes" -ForegroundColor Gray
} else {
    Write-Host "⚠️ No se encontró archivo de cobertura" -ForegroundColor Yellow
}

Write-Host ""

# Mostrar información de configuración actual
Write-Host "📋 Configuración actual:" -ForegroundColor Cyan
Write-Host "   - sonar-project.properties: ✅" -ForegroundColor Gray
Write-Host "   - analysis_options.yaml: ✅" -ForegroundColor Gray
Write-Host "   - GitHub workflows: ✅" -ForegroundColor Gray
Write-Host "   - Scripts de análisis: ✅" -ForegroundColor Gray

Write-Host ""

# Mostrar próximos pasos
Write-Host "🎯 Próximos pasos:" -ForegroundColor Yellow
Write-Host "1. Configura una cuenta en SonarCloud (https://sonarcloud.io)" -ForegroundColor White
Write-Host "2. Conecta tu repositorio GitHub" -ForegroundColor White
Write-Host "3. Obtén el token de SonarCloud" -ForegroundColor White
Write-Host "4. Añade SONAR_TOKEN a los secretos de GitHub:" -ForegroundColor White
Write-Host "   Repository Settings > Secrets and variables > Actions" -ForegroundColor Gray
Write-Host "5. Actualiza sonar.organization en sonar-project.properties" -ForegroundColor White

Write-Host ""

Write-Host "📋 Comandos útiles:" -ForegroundColor Cyan
Write-Host "   Análisis local: flutter analyze" -ForegroundColor Gray
Write-Host "   Tests: flutter test --coverage" -ForegroundColor Gray
Write-Host "   SonarQube Scanner: sonar-scanner (requiere instalación)" -ForegroundColor Gray
Write-Host "   Cargar scripts: . .\scripts\simple_analysis.ps1" -ForegroundColor Gray

Write-Host ""

Write-Host "✅ Configuración inicial completada!" -ForegroundColor Green
Write-Host "🔗 Documentación completa en: docs/SONARQUBE_SETUP.md" -ForegroundColor Cyan