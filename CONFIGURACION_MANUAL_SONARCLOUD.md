# 🔧 Configuración Manual de SonarCloud - Guía Paso a Paso

## ✅ Archivos de Reporte Generados

Hemos generado exitosamente los archivos necesarios para el análisis:

- ✅ **Análisis de código:** `flutter_analysis_report.txt` (134 issues encontrados)
- ✅ **Cobertura de tests:** `coverage/lcov.info` (17,411 bytes)
- ✅ **Configuración:** `sonar-project.properties` está listo

## 🌐 Paso 1: Configurar Cuenta en SonarCloud

### 1.1 Crear Cuenta
1. Ve a **https://sonarcloud.io**
2. Haz clic en **"Log in"**
3. Selecciona **"With GitHub"**
4. Autoriza SonarCloud para acceder a tu cuenta de GitHub

### 1.2 Configurar Organización
1. Una vez logueado, haz clic en **"+"** > **"Analyze new project"**
2. Selecciona tu repositorio **"Acees_Group"**
3. Escoge **"With GitHub Actions"** como método de análisis
4. Copia el **Organization Key** que aparece (ejemplo: `tu-usuario-github`)

### 1.3 Obtener Token
1. Ve a **My Account** > **Security**
2. En la sección **"Generate Tokens"**
3. Escribe un nombre: `Acees_Group_Token`
4. Haz clic en **"Generate"**
5. **¡IMPORTANTE!** Copia el token inmediatamente (solo se muestra una vez)

## 🔧 Paso 2: Configurar GitHub Secrets

### 2.1 Agregar Token a GitHub
1. Ve a tu repositorio en GitHub: **https://github.com/KrCrimson/Acees_Group**
2. Navega a **Settings** > **Secrets and variables** > **Actions**
3. Haz clic en **"New repository secret"**
4. Nombre: `SONAR_TOKEN`
5. Valor: El token que copiaste de SonarCloud
6. Haz clic en **"Add secret"**

## ⚙️ Paso 3: Actualizar Configuración Local

### 3.1 Editar sonar-project.properties
Necesitas actualizar el archivo con tu organización real:

```properties
# Cambia esta línea con tu organización real
sonar.organization=TU-ORGANIZATION-KEY-AQUI

# Cambia el project key si es necesario
sonar.projectKey=TU-USUARIO-acees-group
```

### 3.2 Verificar configuración actual
El archivo actual tiene:
```properties
sonar.organization=acees-group
sonar.projectKey=acees-group
```

**¡Necesitas cambiar `acees-group` por tu organization key real de SonarCloud!**

## 🚀 Paso 4: Ejecutar Análisis Manual

### 4.1 Opción A: Usar GitHub Actions (Recomendado)
1. Haz commit de los cambios:
   ```bash
   git add .
   git commit -m "feat: configurar SonarCloud"
   git push origin Arce
   ```

2. Ve a **Actions** en GitHub y verifica que el workflow se ejecute

### 4.2 Opción B: SonarScanner Local
1. **Descargar SonarScanner:**
   - Ve a: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/
   - Descarga la versión para Windows
   - Extrae a `C:\sonar-scanner`
   - Agrega `C:\sonar-scanner\bin` al PATH

2. **Configurar variables de entorno:**
   ```powershell
   $env:SONAR_TOKEN = "TU-TOKEN-AQUI"
   $env:SONAR_HOST_URL = "https://sonarcloud.io"
   ```

3. **Ejecutar análisis:**
   ```powershell
   # Desde la raíz del proyecto
   sonar-scanner.bat
   ```

## 📋 Paso 5: Verificar Resultados

### 5.1 En SonarCloud Dashboard
1. Ve a **https://sonarcloud.io/projects**
2. Busca tu proyecto **"ACEES Group"**
3. Revisa las métricas:
   - **Bugs**
   - **Vulnerabilities** 
   - **Code Smells**
   - **Coverage**
   - **Duplications**

### 5.2 Métricas Esperadas (Basado en nuestro análisis)
- **Issues de código:** ~134 problemas detectados
- **Cobertura:** Variable (depende de los tests)
- **Líneas de código:** ~2000+ líneas en lib/

## 🎯 Próximos Pasos Después del Setup

### 1. Corregir Issues Prioritarios
```dart
// Ejemplo: Eliminar prints de producción
// ANTES:
print('Debug: usuario logueado');

// DESPUÉS:
debugPrint('Debug: usuario logueado'); // Solo en debug
// O mejor: usar logging profesional
```

### 2. Mejorar Tests
- Crear tests reales para tu aplicación
- Aumentar cobertura de código
- Corregir el test por defecto

### 3. Configurar Quality Gates
- Definir umbrales de calidad
- Configurar reglas de bloqueo para PRs
- Establecer métricas objetivo

## 🆘 Solución de Problemas

### Error: "Project not found"
- Verifica que el `sonar.organization` sea correcto
- Asegúrate de que el proyecto existe en SonarCloud

### Error: "Authentication failed"
- Verifica que `SONAR_TOKEN` esté configurado correctamente
- Regenera el token si es necesario

### Error: "No coverage data"
- Asegúrate de que `coverage/lcov.info` existe
- Ejecuta `flutter test --coverage` antes del análisis

---

## 📞 ¿Necesitas Ayuda?

Si encuentras algún problema:
1. Revisa los logs de GitHub Actions
2. Verifica la configuración en SonarCloud
3. Asegúrate de que todos los archivos estén committeados

**¡Tu proyecto está listo para análisis de calidad profesional!** 🎉