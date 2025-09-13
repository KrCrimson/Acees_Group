Write-Host "🔧 Instalando SonarScanner de forma simple..." -ForegroundColor Yellow

# Crear directorio
$installPath = "C:\sonar-scanner"
New-Item -ItemType Directory -Path $installPath -Force | Out-Null

# URL de descarga
$url = "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-windows.zip"
$zipFile = "$env:TEMP\sonar-scanner.zip"

Write-Host "Descargando SonarScanner..." -ForegroundColor Blue
try {
    # Descargar
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($url, $zipFile)
    
    Write-Host "Extrayendo archivos..." -ForegroundColor Blue
    # Extraer
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $installPath)
    
    # Mover archivos de la subcarpeta
    $subFolder = Get-ChildItem "$installPath\sonar-scanner-*" | Select-Object -First 1
    if ($subFolder) {
        Get-ChildItem $subFolder.FullName -Recurse | Move-Item -Destination $installPath -Force
        Remove-Item $subFolder.FullName -Recurse -Force
    }
    
    Write-Host "✅ SonarScanner instalado en: $installPath" -ForegroundColor Green
    
    # Limpiar
    Remove-Item $zipFile -Force
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📋 Descarga manual:" -ForegroundColor Yellow
    Write-Host "1. Ve a: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/" -ForegroundColor Gray
    Write-Host "2. Descarga y extrae en C:\sonar-scanner" -ForegroundColor Gray
}