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

# 2. usuario normal de Linux (SCHISM se ejecuta con OpenMPI, que no funciona como root) --------------------
$uid = ((wsl.exe -d $Distro -- id -u) -join "").Trim()
if ($uid -eq "0") {
    Write-Host ">> En $Distro entras como root: SCHISMlab necesita un usuario normal de Linux. Se crea ahora."
    $user = $env:SCHISMLAB_LINUX_USER
    while (-not ($user -match '^[a-z_][a-z0-9_-]{0,31}$')) {
        $user = (Read-Host "Nombre del usuario de Linux (minúsculas y sin espacios, p. ej. ana)").Trim()
    }
    wsl.exe -d $Distro -u root -- bash -c "id -u $user >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo $user"
    if (-not $env:SCHISMLAB_LINUX_USER) {
        Write-Host ">> Elige la contraseña de $user (te la pedirá Linux al instalar paquetes; al escribirla no se ve)"
        do { wsl.exe -d $Distro -u root -- passwd $user } while ($LASTEXITCODE -ne 0)
    } else {
        wsl.exe -d $Distro -u root -- bash -c "echo '$user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-$user"   # sin contraseña: pruebas
    }
    # usuario por defecto de la distribución (/etc/wsl.conf, [user] default=...)
    wsl.exe -d $Distro -u root -- bash -c "touch /etc/wsl.conf; sed -i '/^default=/d' /etc/wsl.conf; grep -q '^\[user\]' /etc/wsl.conf || printf '\n[user]\n' >> /etc/wsl.conf; sed -i 's/^\[user\]/[user]\ndefault=$user/' /etc/wsl.conf"
    wsl.exe --terminate $Distro | Out-Null
    $uid = ((wsl.exe -d $Distro -- id -u) -join "").Trim()
    if ($uid -eq "0") { throw "No se ha podido cambiar el usuario por defecto de $Distro a $user." }
    Write-Host ">> Usuario $user creado; es el usuario por defecto de $Distro."
}

# 3. instalador de Linux dentro de WSL (pide el token en esta misma ventana) -------------------
wsl.exe -d $Distro -- bash -lc "command -v curl >/dev/null || (sudo apt-get update -qq && sudo apt-get install -y -qq curl git); curl -fsSL '$Url' -o /tmp/instalar_schismlab.sh && bash /tmp/instalar_schismlab.sh $Variant"
if ($LASTEXITCODE -ne 0) { throw "La instalación dentro de WSL ha fallado (mira los mensajes de arriba)." }
Write-Host "== SCHISMlab instalado en WSL ($Distro). Abre Ubuntu y ejecuta:  cd ~/schismlab && pixi run schismlab gui"
