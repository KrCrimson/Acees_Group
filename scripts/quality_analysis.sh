# Scripts para análisis de calidad de código

# Análisis local con Flutter Analyzer
analyze_local() {
    echo "🔍 Ejecutando análisis de código Flutter..."
    flutter analyze
}

# Generar reporte de análisis en JSON
analyze_json() {
    echo "📊 Generando reporte de análisis en JSON..."
    flutter analyze --write=dart_analysis_report.json --format=json
}

# Ejecutar tests con cobertura
test_coverage() {
    echo "🧪 Ejecutando tests con cobertura..."
    flutter test --coverage
    echo "📈 Reporte de cobertura generado en: coverage/lcov.info"
}

# Análisis completo local
full_analysis() {
    echo "🚀 Iniciando análisis completo de calidad de código..."
    echo ""
    
    echo "1️⃣ Limpiando proyecto..."
    flutter clean
    flutter pub get
    
    echo ""
    echo "2️⃣ Ejecutando análisis de código..."
    flutter analyze --write=dart_analysis_report.json --format=json
    
    echo ""
    echo "3️⃣ Ejecutando tests con cobertura..."
    flutter test --coverage
    
    echo ""
    echo "4️⃣ Mostrando métricas de cobertura..."
    if [ -f "coverage/lcov.info" ]; then
        echo "✅ Archivo de cobertura encontrado"
        # Contar líneas cubiertas/total (requiere lcov instalado)
        # lcov --summary coverage/lcov.info
    else
        echo "❌ No se encontró archivo de cobertura"
    fi
    
    echo ""
    echo "✅ Análisis completo finalizado"
    echo "📁 Archivos generados:"
    echo "   - dart_analysis_report.json"
    echo "   - coverage/lcov.info"
}

# Preparar para SonarQube local
prepare_sonar() {
    echo "🔧 Preparando análisis para SonarQube local..."
    
    # Ejecutar análisis completo
    full_analysis
    
    echo ""
    echo "📋 Para ejecutar SonarQube Scanner manualmente:"
    echo "   sonar-scanner"
    echo ""
    echo "🌐 Para usar SonarCloud:"
    echo "   1. Configura SONAR_TOKEN en tu entorno"
    echo "   2. Actualiza sonar.organization en sonar-project.properties"
    echo "   3. Ejecuta: sonar-scanner"
}

# Función de ayuda
help() {
    echo "📚 Scripts de análisis de calidad para Flutter"
    echo ""
    echo "Comandos disponibles:"
    echo "  analyze_local    - Análisis básico de Flutter"
    echo "  analyze_json     - Análisis con reporte JSON"
    echo "  test_coverage    - Tests con cobertura"
    echo "  full_analysis    - Análisis completo"
    echo "  prepare_sonar    - Preparar para SonarQube"
    echo "  help            - Mostrar esta ayuda"
    echo ""
    echo "Uso desde PowerShell:"
    echo "  . ./scripts/quality_analysis.ps1"
    echo "  full_analysis"
}

# Si se ejecuta directamente, mostrar ayuda
if [ "$1" = "" ]; then
    help
fi