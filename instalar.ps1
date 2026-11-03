# ---------------------------------------------------------------------------
# SCHISMlab: instalador público para Windows 10/11. Instala WSL2 con Ubuntu si falta y, dentro de Ubuntu, ejecuta
# instalar.sh, que pide el token personal que da el profesor y descarga SCHISMlab en ~/schismlab.
# En PowerShell (mejor como administrador; si hace falta, se abre solo como administrador):
#   Set-ExecutionPolicy -Scope Process Bypass; irm https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.ps1 | iex
# Si hay que reiniciar, deja en el escritorio el acceso directo «Continuar instalación de SCHISMlab»; al terminar,
# el acceso directo «SCHISMlab», que abre la interfaz.
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Stop"
$Distro = if ($env:SCHISMLAB_DISTRO) { $env:SCHISMLAB_DISTRO } else { "Ubuntu-24.04" }
$Variant = if ($env:SCHISMLAB_VARIANT) { $env:SCHISMLAB_VARIANT } else { "hydro" }
$Url = if ($env:SCHISMLAB_INSTALAR_URL) { $env:SCHISMLAB_INSTALAR_URL } else { "https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.sh" }
$Ps1Url = $Url -replace '\.sh$', '.ps1'
$Again = "Set-ExecutionPolicy -Scope Process Bypass; irm $Ps1Url | iex"     # la orden para volver a ejecutarlo
$Interactive = [Environment]::UserInteractive -and -not $env:CI
# SCHISMLAB_TOKEN y SCHISMLAB_SOLO_DESCARGAR (si existen) pasan a Linux; sin token, instalar.sh lo pide en esta ventana
$pass = @("SCHISMLAB_TOKEN", "SCHISMLAB_SOLO_DESCARGAR") | Where-Object { [Environment]::GetEnvironmentVariable($_) }
if ($pass) { $env:WSLENV = (@($env:WSLENV) + ($pass | ForEach-Object { "$_/u" }) | Where-Object { $_ }) -join ":" }

function Test-Admin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Step($n, $text) { Write-Host ""; Write-Host "== Paso $n de 4: $text" -ForegroundColor Cyan }
function Stop-Here($lines) {   # parada con instrucciones claras: qué hacer y qué orden pegar
    Write-Host ""
    Write-Host "------------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host " QUÉ HACER AHORA" -ForegroundColor Yellow
    $lines | ForEach-Object { Write-Host " $_" }
    Write-Host "------------------------------------------------------------------" -ForegroundColor Yellow
}
function New-Shortcut($name, $target, $arguments, $description) {
    $desk = [Environment]::GetFolderPath("Desktop")
    if (-not $desk) { return $null }
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desk "$name.lnk"))
    $lnk.TargetPath = $target; $lnk.Arguments = $arguments; $lnk.Description = $description
    $lnk.WorkingDirectory = $env:USERPROFILE; $lnk.Save()
    return (Join-Path $desk "$name.lnk")
}
function Remove-Shortcut($name) {
    $desk = [Environment]::GetFolderPath("Desktop")
    if ($desk) { Remove-Item -ErrorAction SilentlyContinue (Join-Path $desk "$name.lnk") }
}
function Test-Distro { try { wsl.exe -d $Distro -- true *> $null; return ($LASTEXITCODE -eq 0) } catch { return $false } }
$ContinueName = "Continuar instalación de SCHISMlab"

Write-Host "== SCHISMlab: instalación en Windows (WSL2 + $Distro)"
Write-Host "   Si en algún momento se para, haz lo que diga el recuadro «QUÉ HACER AHORA». Se puede volver a ejecutar"
Write-Host "   siempre que haga falta: sigue por donde iba."

# 1. WSL2 y Ubuntu -----------------------------------------------------------------
Step 1 "WSL2 y $Distro"
if (-not (Test-Distro)) {
    $distros = @()
    try { $distros = (wsl.exe -l -q 2>$null) -replace "`0", "" | ForEach-Object { $_.Trim() } | Where-Object { $_ } } catch {}
    $wslOk = $false
    try { wsl.exe --status *> $null; $wslOk = ($LASTEXITCODE -eq 0) } catch {}
    if (-not $wslOk -and -not (Test-Admin)) {
        # instalar WSL necesita administrador: se abre otra ventana como administrador con la misma orden
        Write-Host ">> Para instalar WSL hacen falta permisos de administrador: se abre otra ventana de PowerShell"
        Write-Host "   como administrador (Windows pregunta si permites los cambios: pulsa Sí). Sigue en esa ventana."
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", "irm $Ps1Url | iex"
        } catch {
            Stop-Here @("Abre PowerShell como administrador (botón derecho sobre PowerShell > Ejecutar como administrador)",
                        "y pega esta orden:", "", "   $Again")
        }
        return
    }
    if ($distros -notcontains $Distro) {
        Write-Host ">> Instalando $Distro (unos minutos; puede abrirse una ventana de Ubuntu que pide un nombre de usuario"
        Write-Host "   y una contraseña: rellénalos; si no aparece, el usuario se crea en el paso 2)"
        wsl.exe --install -d $Distro
    }
    if (-not (Test-Distro)) {
        # WSL recién activado: Windows necesita reiniciarse antes de poder usar Ubuntu
        $lnk = New-Shortcut $ContinueName "powershell.exe" "-NoExit -ExecutionPolicy Bypass -Command `"irm $Ps1Url | iex`"" "Sigue la instalación de SCHISMlab"
        $msg = @("Hay que REINICIAR el ordenador para terminar de instalar WSL.", "",
                 "Después del reinicio:",
                 " 1. Puede abrirse sola una ventana de Ubuntu que pide un nombre de usuario y una contraseña:",
                 "    rellénalos (minúsculas y sin espacios; la contraseña no se ve al escribirla) y ciérrala.")
        if ($lnk) { $msg += " 2. Haz doble clic en el acceso directo «$ContinueName» del escritorio." }
        else { $msg += " 2. Abre PowerShell y pega:   $Again" }
        $msg += @("    La instalación sigue por donde iba.")
        Stop-Here $msg
        if ($Interactive -and ((Read-Host "¿Reiniciar ahora? (s/n)").Trim().ToLower() -eq "s")) { Restart-Computer }
        return
    }
}
Write-Host ">> $Distro funciona"

# 2. usuario normal de Linux (SCHISM se ejecuta con OpenMPI, que no funciona como root) --------------------
Step 2 "usuario de Linux"
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
} else {
    Write-Host ">> usuario de Linux: $(((wsl.exe -d $Distro -- id -un) -join '').Trim())"
}

# 3 y 4. token, descarga e instalación dentro de WSL (instalar.sh; pide el token en esta misma ventana) -----------
Step 3 "token de acceso y descarga (pega el token que te ha dado el profesor)"
wsl.exe -d $Distro -- bash -lc "command -v curl >/dev/null || (sudo apt-get update -qq && sudo apt-get install -y -qq curl git); curl -fsSL '$Url' -o /tmp/instalar_schismlab.sh && bash /tmp/instalar_schismlab.sh $Variant"
if ($LASTEXITCODE -ne 0) {
    Stop-Here @("La instalación dentro de Ubuntu se ha parado: el motivo está en los mensajes de arriba.",
                "Cuando lo resuelvas (o si se cortó la red), vuelve a pegar la misma orden; sigue por donde iba:", "", "   $Again")
    throw "La instalación dentro de WSL ha fallado."
}
Remove-Shortcut $ContinueName
if ($env:SCHISMLAB_SOLO_DESCARGAR) { return }

# acceso directo que abre la interfaz (la ruta completa de pixi: no depende de abrir una terminal nueva)
$gui = "cd ~/schismlab && ~/.pixi/bin/pixi run schismlab gui"
$lnk = New-Shortcut "SCHISMlab" "wsl.exe" "-d $Distro -- bash -lc `"$gui`"" "Abre la interfaz de SCHISMlab"
Write-Host ""
Write-Host "== SCHISMlab instalado." -ForegroundColor Green
if ($lnk) { Write-Host "   Para abrirlo: doble clic en el acceso directo «SCHISMlab» del escritorio (deja abierta la ventana negra)." }
Write-Host "   También desde Ubuntu:  $gui"
if ($Interactive -and ((Read-Host "¿Abrir SCHISMlab ahora? (s/n)").Trim().ToLower() -eq "s")) {
    Start-Process wsl.exe -ArgumentList "-d", $Distro, "--", "bash", "-lc", "`"$gui`""
}
