#!/bin/bash
# Script de configuración inicial para SonarQube
# Uso: ./scripts/setup_sonarqube.sh

echo "🚀 Configurando SonarQube para ACEES Group..."
echo ""

# Verificar Flutter
echo "1️⃣ Verificando instalación de Flutter..."
if command -v flutter &> /dev/null; then
    flutter --version
    echo "✅ Flutter encontrado"
else
    echo "❌ Flutter no encontrado. Por favor instala Flutter primero."
    exit 1
fi

echo ""

# Limpiar y obtener dependencias
echo "2️⃣ Limpiando proyecto y obteniendo dependencias..."
flutter clean
flutter pub get

echo ""

# Verificar dependencias
echo "3️⃣ Verificando dependencias..."
flutter pub deps

echo ""

# Ejecutar análisis
echo "4️⃣ Ejecutando análisis de código..."
flutter analyze --no-fatal-infos

echo ""

# Ejecutar tests
echo "5️⃣ Ejecutando tests con cobertura..."
flutter test --coverage || echo "⚠️ Algunos tests fallaron, pero continuamos..."

echo ""

# Verificar archivos generados
echo "6️⃣ Verificando archivos de reporte..."
if [ -f "coverage/lcov.info" ]; then
    echo "✅ Archivo de cobertura encontrado: coverage/lcov.info"
    echo "📊 Tamaño: $(wc -l < coverage/lcov.info) líneas"
else
    echo "⚠️ No se encontró archivo de cobertura"
fi

echo ""

# Mostrar próximos pasos
echo "🎯 Próximos pasos:"
echo "1. Configura una cuenta en SonarCloud (https://sonarcloud.io)"
echo "2. Conecta tu repositorio GitHub"
echo "3. Obtén el token de SonarCloud"
echo "4. Añade SONAR_TOKEN a los secretos de GitHub"
echo "5. Actualiza sonar.organization en sonar-project.properties"
echo ""

echo "📋 Comandos útiles:"
echo "   Análisis local: flutter analyze"
echo "   Tests: flutter test --coverage"
echo "   SonarQube Scanner: sonar-scanner (requiere instalación)"
echo ""

echo "✅ Configuración inicial completada!"