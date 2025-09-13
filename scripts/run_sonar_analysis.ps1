# Script para ejecutar SonarScanner con token
param(
    [Parameter(Mandatory=$true)]
    [string]$SonarToken,
    
    [Parameter(Mandatory=$false)]
    [string]$Organization = "acees-group"
)

Write-Host "🚀 Ejecutando análisis SonarCloud..." -ForegroundColor Yellow
Write-Host ""

# Configurar variables de entorno
$env:SONAR_TOKEN = $SonarToken
$env:SONAR_HOST_URL = "https://sonarcloud.io"

Write-Host "✅ Token configurado" -ForegroundColor Green
Write-Host "🔍 Organización: $Organization" -ForegroundColor Cyan
Write-Host ""

# Verificar archivos necesarios
Write-Host "📋 Verificando archivos necesarios..." -ForegroundColor Blue

if (Test-Path "sonar-project.properties") {
    Write-Host "✅ sonar-project.properties encontrado" -ForegroundColor Green
} else {
    Write-Host "❌ sonar-project.properties NO encontrado" -ForegroundColor Red
    exit 1
}

if (Test-Path "coverage\lcov.info") {
    $size = (Get-Item "coverage\lcov.info").Length
    Write-Host "✅ coverage/lcov.info encontrado ($size bytes)" -ForegroundColor Green
} else {
    Write-Host "⚠️ coverage/lcov.info no encontrado (se ejecutará sin cobertura)" -ForegroundColor Yellow
}

Write-Host ""

# Buscar SonarScanner
$scannerPath = ""
if (Test-Path "sonar-scanner-4.8.0.2856-windows\bin\sonar-scanner.bat") {
    $scannerPath = ".\sonar-scanner-4.8.0.2856-windows\bin\sonar-scanner.bat"
    Write-Host "✅ SonarScanner encontrado (local)" -ForegroundColor Green
} elseif (Get-Command "sonar-scanner.bat" -ErrorAction SilentlyContinue) {
    $scannerPath = "sonar-scanner.bat"
    Write-Host "✅ SonarScanner encontrado (PATH)" -ForegroundColor Green
} else {
    Write-Host "❌ SonarScanner no encontrado" -ForegroundColor Red
    Write-Host "Intenta ejecutar primero: .\scripts\simple_installer.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🔍 Ejecutando análisis con SonarCloud..." -ForegroundColor Yellow
Write-Host "📁 Directorio: $PWD" -ForegroundColor Gray
Write-Host "🛠️ Scanner: $scannerPath" -ForegroundColor Gray
Write-Host ""

# Ejecutar SonarScanner
try {
    & $scannerPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "🎉 ¡Análisis completado exitosamente!" -ForegroundColor Green
        Write-Host "🌐 Ve los resultados en: https://sonarcloud.io/projects" -ForegroundColor Cyan
        Write-Host "🔍 Busca tu proyecto: ACEES Group" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "⚠️ El análisis completó con advertencias (código: $LASTEXITCODE)" -ForegroundColor Yellow
        Write-Host "🌐 Revisa los resultados en: https://sonarcloud.io/projects" -ForegroundColor Cyan
    }
} catch {
    Write-Host ""
    Write-Host "❌ Error ejecutando SonarScanner:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Posibles soluciones:" -ForegroundColor Yellow
    Write-Host "1. Verifica que el token sea correcto" -ForegroundColor White
    Write-Host "2. Verifica que el proyecto exista en SonarCloud" -ForegroundColor White
    Write-Host "3. Revisa sonar-project.properties" -ForegroundColor White
}

Write-Host ""
Write-Host "📋 Archivos analizados:" -ForegroundColor Cyan
Write-Host "   - Código fuente: lib/" -ForegroundColor Gray
Write-Host "   - Tests: test/" -ForegroundColor Gray
Write-Host "   - Configuración: sonar-project.properties" -ForegroundColor Gray
if (Test-Path "coverage\lcov.info") {
    Write-Host "   - Cobertura: coverage/lcov.info" -ForegroundColor Gray
}