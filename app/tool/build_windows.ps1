# Compila DistiNode para Windows y genera el instalador y un ZIP portable.
# Uso (desde app/):  powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
# Requisitos: Flutter, Visual Studio Build Tools (C++), Inno Setup 6.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
Write-Host "DistiNode $version"

flutter build windows --release
if (-not $?) { throw 'flutter build windows falló' }

# Runtime de Visual C++ junto al .exe (despliegue local permitido por el redistribuible de Microsoft):
# así funciona en equipos sin el paquete "Visual C++ Redistributable" instalado.
$release = 'build\windows\x64\runner\Release'
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item "$env:WINDIR\System32\$dll" $release -Force
}

$iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'No se encuentra Inno Setup 6 (ISCC.exe)' }
& $iscc "/DAppVersion=$version" 'installer\windows\distinode.iss'
if (-not $?) { throw 'ISCC falló' }

New-Item -ItemType Directory -Force build\installer | Out-Null
$zip = "build\installer\DistiNode-$version-windows-x64-portable.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$release\*" -DestinationPath $zip
Get-ChildItem build\installer | Format-Table Name, Length
