# Scripts de análisis de calidad para Flutter
Write-Host "📚 Scripts de análisis de calidad cargados" -ForegroundColor Green

function Analyze-Local {
    Write-Host "🔍 Ejecutando análisis de código Flutter..." -ForegroundColor Cyan
    flutter analyze
}

function Test-Coverage {
    Write-Host "🧪 Ejecutando tests con cobertura..." -ForegroundColor Cyan
    flutter test --coverage
}

function Full-Analysis {
    Write-Host "🚀 Análisis completo de calidad..." -ForegroundColor Yellow
    flutter clean
    flutter pub get
    flutter analyze --write=dart_analysis_report.json --format=json
    flutter test --coverage
    Write-Host "✅ Análisis completado" -ForegroundColor Green
}

Write-Host ""
Write-Host "Comandos disponibles:" -ForegroundColor Cyan
Write-Host "- Analyze-Local" -ForegroundColor Gray
Write-Host "- Test-Coverage" -ForegroundColor Gray  
Write-Host "- Full-Analysis" -ForegroundColor Gray