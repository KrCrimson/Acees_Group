# Guía de Configuración SonarQube/SonarCloud

## 🎯 Objetivo

Esta guía te ayuda a configurar y usar SonarQube/SonarCloud para análisis continuo de calidad de código en el proyecto ACEES Group.

## 📋 Archivos de Configuración

### Archivos Principales
- `sonar-project.properties` - Configuración principal de SonarQube
- `analysis_options.yaml` - Reglas de análisis de Dart/Flutter
- `.github/workflows/flutter-ci.yml` - CI/CD con SonarCloud
- `scripts/quality_analysis.ps1` - Scripts para análisis local

## 🚀 Configuración Rápida

### 1. SonarCloud (Recomendado - Gratis para proyectos públicos)

1. **Crear cuenta en SonarCloud:**
   - Ir a [sonarcloud.io](https://sonarcloud.io)
   - Conectar con GitHub
   - Importar repositorio `Acees_Group`

2. **Configurar organización:**
   - Editar `sonar-project.properties`
   - Cambiar `sonar.organization=acees-group` por tu organización

3. **Configurar GitHub Secrets:**
   - Ir a Settings > Secrets and variables > Actions
   - Agregar `SONAR_TOKEN` con el token de SonarCloud

4. **Activar análisis automático:**
   - Los workflows se ejecutarán en cada push/PR
   - Ver resultados en SonarCloud dashboard

### 2. SonarQube Local

1. **Instalar SonarQube:**
   ```bash
   # Usando Docker
   docker run -d --name sonarqube -p 9000:9000 sonarqube:latest
   ```

2. **Instalar SonarQube Scanner:**
   - Descargar desde [sonarsource.com](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/)
   - Agregar al PATH

3. **Configurar:**
   - Editar `sonar-project.properties`
   - Descomentar `sonar.host.url=http://localhost:9000`

4. **Ejecutar análisis:**
   ```powershell
   . .\scripts\quality_analysis.ps1
   Prepare-Sonar
   sonar-scanner.bat
   ```

## 📊 Métricas Analizadas

### Categorías Principales
- **🐛 Bugs**: Errores que pueden causar problemas
- **🔒 Vulnerabilidades**: Problemas de seguridad
- **👃 Code Smells**: Problemas de mantenibilidad
- **📈 Cobertura**: Porcentaje de código con tests
- **🔄 Duplicación**: Código duplicado
- **📏 Complejidad**: Complejidad ciclomática

### Umbrales de Calidad (Quality Gates)
- Cobertura mínima: 80%
- Duplicación máxima: 3%
- Mantenibilidad: A
- Confiabilidad: A
- Seguridad: A

## 🛠️ Scripts de Análisis Local

### Comandos Disponibles

```powershell
# Cargar scripts
. .\scripts\quality_analysis.ps1

# Ver ayuda
Show-Help

# Análisis completo
Full-Analysis

# Solo análisis de código
Analyze-Local

# Solo tests con cobertura
Test-Coverage

# Preparar para SonarQube
Prepare-Sonar
```

### Análisis Manual

```bash
# Limpiar proyecto
flutter clean
flutter pub get

# Análisis de código
flutter analyze --write=dart_analysis_report.json --format=json

# Tests con cobertura
flutter test --coverage

# Verificar archivos generados
ls -la coverage/lcov.info
ls -la dart_analysis_report.json
```

## 🔧 Configuración Avanzada

### Exclusiones Personalizadas

Editar `sonar-project.properties`:

```properties
# Excluir archivos adicionales
sonar.exclusions=**/*.g.dart,**/*.freezed.dart,lib/experimental/**

# Excluir de cobertura
sonar.coverage.exclusions=lib/main.dart,lib/dev_tools/**
```

### Reglas Específicas de Dart

Editar `analysis_options.yaml`:

```yaml
linter:
  rules:
    # Activar regla específica
    prefer_single_quotes: true
    
    # Desactivar regla conflictiva
    lines_longer_than_80_chars: false
```

## 📈 Integración con GitHub

### Pull Request Decoration

SonarCloud comentará automáticamente en PRs con:
- Nuevos bugs/vulnerabilidades
- Cambios en cobertura
- Estado del Quality Gate

### Badges para README

```markdown
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=tu-proyecto&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=tu-proyecto)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=tu-proyecto&metric=coverage)](https://sonarcloud.io/summary/new_code?id=tu-proyecto)
```

## 🐛 Solución de Problemas

### Errores Comunes

1. **"Command not found: sonar-scanner"**
   - Instalar SonarQube Scanner
   - Agregar al PATH del sistema

2. **"SONAR_TOKEN not found"**
   - Configurar token en GitHub Secrets
   - Verificar variable de entorno local

3. **"No coverage data found"**
   - Ejecutar `flutter test --coverage`
   - Verificar archivo `coverage/lcov.info`

4. **"Analysis failed"**
   - Verificar `flutter analyze` sin errores
   - Revisar logs de SonarQube

### Logs y Debugging

```bash
# Verificar configuración
flutter doctor -v

# Análisis verbose
flutter analyze --verbose

# Logs de SonarQube
sonar-scanner -X
```

## 📚 Recursos Adicionales

- [SonarQube Documentation](https://docs.sonarqube.org/)
- [SonarCloud Documentation](https://sonarcloud.io/documentation)
- [Flutter Lints](https://pub.dev/packages/flutter_lints)
- [Dart Analysis Options](https://dart.dev/guides/language/analysis-options)

## 🎯 Mejores Prácticas

1. **Ejecutar análisis antes de commits**
2. **Revisar Quality Gate antes de merge**
3. **Mantener cobertura > 80%**
4. **Resolver bugs de alta prioridad primero**
5. **Usar `// ignore:` solo cuando sea necesario**
6. **Revisar code smells regularmente**

---

*Configuración optimizada para Flutter + Firebase + SonarQube*