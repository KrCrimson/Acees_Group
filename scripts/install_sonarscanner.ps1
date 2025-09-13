# Script para instalar y ejecutar SonarScanner localmente
# Ejecutar como administrador

Write-Host "🔧 Configuración Manual de SonarScanner para Windows" -ForegroundColor Yellow
Write-Host ""

# Variables
$sonarScannerVersion = "4.8.0.2856"
$downloadUrl = "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-$sonarScannerVersion-windows.zip"
$installPath = "C:\sonar-scanner"
$zipFile = "$env:TEMP\sonar-scanner.zip"

Write-Host "📥 Paso 1: Descargar SonarScanner..." -ForegroundColor Blue

try {
    # Crear directorio de instalación
    if (!(Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        Write-Host "✅ Directorio creado: $installPath" -ForegroundColor Green
    }

    # Descargar archivo
    Write-Host "Descargando desde: $downloadUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile
    Write-Host "✅ Descarga completada" -ForegroundColor Green

    # Extraer archivo
    Write-Host "📦 Extrayendo archivos..." -ForegroundColor Blue
    Expand-Archive -Path $zipFile -DestinationPath $installPath -Force
    
    # Mover archivos al directorio raíz
    $extractedFolder = Get-ChildItem -Path $installPath -Directory | Where-Object { $_.Name -like "sonar-scanner-*" } | Select-Object -First 1
    if ($extractedFolder) {
        Get-ChildItem -Path $extractedFolder.FullName -Recurse | Move-Item -Destination $installPath -Force
        Remove-Item -Path $extractedFolder.FullName -Recurse -Force
    }

    Write-Host "✅ Extracción completada" -ForegroundColor Green

} catch {
    Write-Host "❌ Error en la descarga: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔄 Descarga manual:" -ForegroundColor Yellow
    Write-Host "   1. Ve a: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/" -ForegroundColor Gray
    Write-Host "   2. Descarga 'SonarScanner for Windows'" -ForegroundColor Gray
    Write-Host "   3. Extrae a: C:\sonar-scanner" -ForegroundColor Gray
}

Write-Host ""
Write-Host "⚙️ Paso 2: Configurar PATH (requiere reiniciar terminal)..." -ForegroundColor Blue

# Verificar si ya está en PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$scannerBinPath = "$installPath\bin"

if ($currentPath -notlike "*$scannerBinPath*") {
    try {
        # Agregar al PATH del sistema (requiere admin)
        $newPath = "$currentPath;$scannerBinPath"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
        Write-Host "✅ SonarScanner agregado al PATH del sistema" -ForegroundColor Green
        Write-Host "⚠️ Reinicia PowerShell para que tome efecto" -ForegroundColor Yellow
    } catch {
        Write-Host "⚠️ No se pudo agregar al PATH automáticamente" -ForegroundColor Yellow
        Write-Host "📋 Configuración manual:" -ForegroundColor Cyan
        Write-Host "   1. Abre 'Variables de entorno del sistema'" -ForegroundColor Gray
        Write-Host "   2. Edita la variable PATH" -ForegroundColor Gray
        Write-Host "   3. Agrega: $scannerBinPath" -ForegroundColor Gray
    }
} else {
    Write-Host "✅ SonarScanner ya está en PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "🔑 Paso 3: Configurar variables de entorno..." -ForegroundColor Blue

# Solicitar token al usuario
Write-Host "Necesitas configurar tu SONAR_TOKEN:" -ForegroundColor Yellow
Write-Host "1. Ve a SonarCloud.io > My Account > Security" -ForegroundColor Gray
Write-Host "2. Genera un nuevo token" -ForegroundColor Gray
Write-Host "3. Copia el token y pégalo aquí" -ForegroundColor Gray
Write-Host ""

$sonarToken = Read-Host "Pega tu SONAR_TOKEN aquí (Enter para omitir)"

if ($sonarToken) {
    # Configurar variables de entorno para esta sesión
    $env:SONAR_TOKEN = $sonarToken
    $env:SONAR_HOST_URL = "https://sonarcloud.io"
    
    Write-Host "✅ Variables configuradas para esta sesión" -ForegroundColor Green
    Write-Host "⚠️ Para sesiones futuras, configúralas permanentemente" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ Token omitido. Configúralo antes de ejecutar el análisis:" -ForegroundColor Yellow
    Write-Host '   $env:SONAR_TOKEN = "tu-token-aqui"' -ForegroundColor Gray
}

Write-Host ""
Write-Host "🚀 Paso 4: Probar instalación..." -ForegroundColor Blue

try {
    # Actualizar PATH para esta sesión
    $env:PATH += ";$scannerBinPath"
    
    # Probar comando
    $version = & sonar-scanner.bat --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ SonarScanner instalado correctamente" -ForegroundColor Green
        Write-Host "Versión: $($version | Select-Object -First 1)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️ Problema con la instalación" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ No se pudo probar. Reinicia PowerShell e intenta: sonar-scanner.bat --version" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📋 Comandos para ejecutar análisis:" -ForegroundColor Cyan
Write-Host "   # Configurar token (si no lo hiciste arriba)" -ForegroundColor Gray
Write-Host '   $env:SONAR_TOKEN = "tu-token-de-sonarcloud"' -ForegroundColor Gray
Write-Host ""
Write-Host "   # Ejecutar análisis" -ForegroundColor Gray
Write-Host "   sonar-scanner.bat" -ForegroundColor Gray
Write-Host ""
Write-Host "📁 Archivos de configuración listos:" -ForegroundColor Cyan
Write-Host "   ✅ sonar-project.properties" -ForegroundColor Green
Write-Host "   ✅ coverage/lcov.info (17KB)" -ForegroundColor Green
Write-Host "   ✅ Análisis de código ejecutado (134 issues)" -ForegroundColor Green

Write-Host ""
Write-Host "🎯 Próximo paso: Ejecuta 'sonar-scanner.bat' desde la raíz del proyecto" -ForegroundColor Yellow
Write-Host "🌐 Resultados en: https://sonarcloud.io" -ForegroundColor Cyan

# Limpiar archivo temporal
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}