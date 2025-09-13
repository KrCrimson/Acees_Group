Write-Host "🚀 Configurando SonarQube para ACEES Group..." -ForegroundColor Yellow
Write-Host ""

Write-Host "1️⃣ Verificando Flutter..." -ForegroundColor Blue
flutter --version

Write-Host ""
Write-Host "2️⃣ Obteniendo dependencias..." -ForegroundColor Blue
flutter pub get

Write-Host ""
Write-Host "3️⃣ Ejecutando análisis..." -ForegroundColor Blue
flutter analyze --no-fatal-infos

Write-Host ""
Write-Host "4️⃣ Ejecutando tests..." -ForegroundColor Blue
flutter test --coverage

Write-Host ""
Write-Host "✅ Configuración completada!" -ForegroundColor Green
Write-Host "📁 Archivos de reporte generados en coverage/" -ForegroundColor Cyan