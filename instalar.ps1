# ---------------------------------------------------------------------------
# SCHISMlab: instalador público para Windows 10/11. Instala WSL2 con Ubuntu si falta y, dentro de Ubuntu, ejecuta
# instalar.sh, que pide el token personal que da el profesor y descarga SCHISMlab en ~/schismlab.
# En PowerShell como administrador:
#   Set-ExecutionPolicy -Scope Process Bypass; irm https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.ps1 | iex
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Stop"
$Distro = if ($env:SCHISMLAB_DISTRO) { $env:SCHISMLAB_DISTRO } else { "Ubuntu-24.04" }
$Variant = if ($env:SCHISMLAB_VARIANT) { $env:SCHISMLAB_VARIANT } else { "hydro" }
$Url = if ($env:SCHISMLAB_INSTALAR_URL) { $env:SCHISMLAB_INSTALAR_URL } else { "https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.sh" }
# SCHISMLAB_TOKEN y SCHISMLAB_SOLO_DESCARGAR (si existen) pasan a Linux; sin token, instalar.sh lo pide en esta ventana
$pass = @("SCHISMLAB_TOKEN", "SCHISMLAB_SOLO_DESCARGAR") | Where-Object { [Environment]::GetEnvironmentVariable($_) }
if ($pass) { $env:WSLENV = (@($env:WSLENV) + ($pass | ForEach-Object { "$_/u" }) | Where-Object { $_ }) -join ":" }

function Test-Admin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }

# 1. WSL2 --------------------------------------------------------------------------
$wslOk = $false
try { wsl.exe -l -q *> $null; $wslOk = ($LASTEXITCODE -eq 0) } catch {}
if (-not $wslOk) {
    if (-not (Test-Admin)) { throw "Falta WSL2: abre PowerShell como administrador y vuelve a ejecutar el instalador." }
    Write-Host ">> Instalando WSL2 + $Distro (puede pedir reiniciar; después, vuelve a ejecutar el instalador)"
    wsl.exe --install -d $Distro
    Write-Host ">> Reinicia el ordenador y vuelve a ejecutar el instalador"; return
}
$distros = (wsl.exe -l -q) -replace "`0", "" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($distros -notcontains $Distro) {
    Write-Host ">> Instalando la distribución $Distro (te pedirá crear un usuario de Linux)"
    wsl.exe --install -d $Distro
}

# 2. instalador de Linux dentro de WSL (pide el token en esta misma ventana) -------------------
wsl.exe -d $Distro -- bash -lc "command -v curl >/dev/null || (sudo apt-get update -qq && sudo apt-get install -y -qq curl git); curl -fsSL '$Url' -o /tmp/instalar_schismlab.sh && bash /tmp/instalar_schismlab.sh $Variant"
if ($LASTEXITCODE -ne 0) { throw "La instalación dentro de WSL ha fallado (mira los mensajes de arriba)." }
Write-Host "== SCHISMlab instalado en WSL ($Distro). Abre Ubuntu y ejecuta:  cd ~/schismlab && pixi run schismlab gui"
