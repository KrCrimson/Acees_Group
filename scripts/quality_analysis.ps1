# Scripts para análisis de calidad de código en Flutter
# Uso: . .\scripts\quality_analysis.ps1

function Analyze-Local {
    Write-Host "🔍 Ejecutando análisis de código Flutter..." -ForegroundColor Cyan
    flutter analyze
}

function Analyze-Json {
    Write-Host "📊 Generando reporte de análisis en JSON..." -ForegroundColor Cyan
    flutter analyze --write=dart_analysis_report.json --format=json
}

function Test-Coverage {
    Write-Host "🧪 Ejecutando tests con cobertura..." -ForegroundColor Cyan
    flutter test --coverage
    Write-Host "📈 Reporte de cobertura generado en: coverage/lcov.info" -ForegroundColor Green
}

function Full-Analysis {
    Write-Host "🚀 Iniciando análisis completo de calidad de código..." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "1️⃣ Limpiando proyecto..." -ForegroundColor Blue
    flutter clean
    flutter pub get
    
    Write-Host ""
    Write-Host "2️⃣ Ejecutando análisis de código..." -ForegroundColor Blue
    flutter analyze --write=dart_analysis_report.json --format=json
    
    Write-Host ""
    Write-Host "3️⃣ Ejecutando tests con cobertura..." -ForegroundColor Blue
    flutter test --coverage
    
    Write-Host ""
    Write-Host "4️⃣ Verificando archivos generados..." -ForegroundColor Blue
    if (Test-Path "coverage/lcov.info") {
        Write-Host "✅ Archivo de cobertura encontrado" -ForegroundColor Green
        $coverageSize = (Get-Item "coverage/lcov.info").Length
        Write-Host "📊 Tamaño del archivo de cobertura: $coverageSize bytes" -ForegroundColor Gray
    } else {
        Write-Host "❌ No se encontró archivo de cobertura" -ForegroundColor Red
    }
    
    if (Test-Path "dart_analysis_report.json") {
        Write-Host "✅ Reporte de análisis generado" -ForegroundColor Green
    } else {
        Write-Host "❌ No se encontró reporte de análisis" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "✅ Análisis completo finalizado" -ForegroundColor Green
    Write-Host "📁 Archivos generados:" -ForegroundColor Cyan
    Write-Host "   - dart_analysis_report.json" -ForegroundColor Gray
    Write-Host "   - coverage/lcov.info" -ForegroundColor Gray
}

function Prepare-Sonar {
    Write-Host "🔧 Preparando análisis para SonarQube..." -ForegroundColor Cyan
    
    # Ejecutar análisis completo
    Full-Analysis
    
    Write-Host ""
    Write-Host "📋 Para ejecutar SonarQube Scanner:" -ForegroundColor Yellow
    Write-Host "   sonar-scanner.bat" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🌐 Para usar SonarCloud:" -ForegroundColor Yellow
    Write-Host "   1. Configura SONAR_TOKEN en variables de entorno" -ForegroundColor Gray
    Write-Host "   2. Actualiza sonar.organization en sonar-project.properties" -ForegroundColor Gray
    Write-Host "   3. Ejecuta: sonar-scanner.bat" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔗 GitHub Actions:" -ForegroundColor Yellow
    Write-Host "   - Los workflows se ejecutarán automáticamente en push/PR" -ForegroundColor Gray
    Write-Host "   - Configura SONAR_TOKEN como secret en GitHub" -ForegroundColor Gray
}

function Show-Help {
    Write-Host "📚 Scripts de análisis de calidad para Flutter" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Comandos disponibles:" -ForegroundColor Yellow
    Write-Host "  Analyze-Local     - Análisis básico de Flutter" -ForegroundColor Gray
    Write-Host "  Analyze-Json      - Análisis con reporte JSON" -ForegroundColor Gray
    Write-Host "  Test-Coverage     - Tests con cobertura" -ForegroundColor Gray
    Write-Host "  Full-Analysis     - Análisis completo" -ForegroundColor Gray
    Write-Host "  Prepare-Sonar     - Preparar para SonarQube" -ForegroundColor Gray
    Write-Host "  Show-Help         - Mostrar esta ayuda" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host "  . .\scripts\quality_analysis.ps1" -ForegroundColor Gray
    Write-Host "  Full-Analysis" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📊 Verificar estado actual del proyecto:" -ForegroundColor Yellow
    Write-Host "  flutter doctor -v" -ForegroundColor Gray
    Write-Host "  flutter analyze" -ForegroundColor Gray
}

# Mostrar ayuda por defecto
Show-Help