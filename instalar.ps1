# ---------------------------------------------------------------------------
# SCHISMlab: instalador público para Windows 10/11. Instala WSL2 con Ubuntu si falta y, dentro de Ubuntu, ejecuta
# instalar.sh, que pide el token personal que da el profesor y descarga SCHISMlab en ~/schismlab.
# En PowerShell (se abre un asistente con ventanas; SCHISMLAB_CONSOLA=1 para hacerlo en la consola):
#   Set-ExecutionPolicy -Scope Process Bypass; irm https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.ps1 | iex
# Si hay que reiniciar, deja en el escritorio el acceso directo «Continuar instalación de SCHISMlab»; al terminar,
# los accesos directos «SCHISMlab» (escritorio y menú Inicio), que abren la interfaz.
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
function Test-Distro($name = $Distro) { try { wsl.exe -d $name -- true *> $null; return ($LASTEXITCODE -eq 0) } catch { return $false } }
$ContinueName = "Continuar instalación de SCHISMlab"

# =====================================================================================================================
# Asistente gráfico (ventanas de Windows): el mismo proceso que el de consola, por pantallas. Se usa siempre que hay
# alguien delante; SCHISMLAB_CONSOLA=1 (o sin escritorio, como en las pruebas automáticas) usa el de consola.
# Nada pide contraseña en una terminal: los paquetes de Ubuntu se instalan como root (wsl -u root) antes de
# instalar.sh, y la contraseña de Linux se fija con chpasswd. SCHISMLAB_DEMO=1 recorre las pantallas sin instalar nada.
# =====================================================================================================================
# las marcas de correcto y flecha como códigos: sus bytes en UTF-8 parecen comillas si PowerShell 5.1 lee el fichero como ANSI
$MarkOk = [char]0x2714; $Fl = [char]0x2192
$W = @{}            # estado del asistente (los manejadores de eventos lo comparten)
$Repo = if ($env:SCHISMLAB_REPO) { $env:SCHISMLAB_REPO } else { "DrAmores/SCHISMlab-Lite" }
$ProRepo = if ($env:SCHISMLAB_PRO_REPO) { $env:SCHISMLAB_PRO_REPO } else { "DrAmores/SCHISMlab-Pro" }
$IcoUrl = ($Url -replace '[^/]+$', '') + "schismlab.ico"
$PngUrl = ($Url -replace '[^/]+$', '') + "schismlab.png"

function W-Label($text, $y, $size = 10, [switch]$Bold, $color = $null, $height = 0) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $text; $l.Left = 28; $l.Top = $y; $l.Width = 660; $l.AutoSize = $false
    $style = if ($Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $l.Font = New-Object Drawing.Font("Segoe UI", $size, $style)
    if ($color) { $l.ForeColor = $color }
    $l.Height = if ($height) { $height } else { [Math]::Max(24, [int]($l.PreferredHeight * [Math]::Ceiling($l.PreferredWidth / 650.0)) + 4) }
    $W.body.Controls.Add($l); return $l
}
function W-Input($label, $y, [switch]$Secret) {
    W-Label $label $y 9.5 | Out-Null
    $t = New-Object Windows.Forms.TextBox
    $t.Left = 28; $t.Top = $y + 24; $t.Width = 420; $t.Font = New-Object Drawing.Font("Segoe UI", 11)
    if ($Secret) { $t.UseSystemPasswordChar = $true }
    $W.body.Controls.Add($t); return $t
}
function W-Button($text, $x, $y, $width = 220) {     # ojo: $w sería $W (PowerShell no distingue mayúsculas)
    $b = New-Object Windows.Forms.Button
    $b.Text = $text; $b.Left = $x; $b.Top = $y; $b.Width = $width; $b.Height = 34
    $b.FlatStyle = "Flat"; $b.BackColor = $W.grafito; $b.ForeColor = [Drawing.Color]::White
    $W.body.Controls.Add($b); return $b
}
function W-Log($y, $h) {
    $t = New-Object Windows.Forms.TextBox
    $t.Multiline = $true; $t.ReadOnly = $true; $t.ScrollBars = "Vertical"; $t.WordWrap = $false
    $t.Left = 28; $t.Top = $y; $t.Width = 660; $t.Height = $h; $t.BackColor = [Drawing.Color]::FromArgb(247, 247, 247)
    $t.Font = New-Object Drawing.Font("Consolas", 8.5)
    $W.body.Controls.Add($t); return $t
}
function W-Page($n, $title, $next = "Siguiente", [switch]$NoBack) {
    # pantalla nueva: título del paso en la cabecera y botones del pie
    # los controles de la pantalla anterior se destruyen (si no, uno que tuviera el foco impide cerrar la ventana)
    $W.next.Focus() | Out-Null
    $old = @($W.body.Controls); $W.body.Controls.Clear(); $old | ForEach-Object { $_.Dispose() }
    $W.step.Text = if ($n) { "Paso $n de 5 · $title" } else { $title }
    $W.next.Text = $next; $W.next.Enabled = $true; $W.next.Visible = $true
    $W.back.Visible = -not $NoBack; $W.back.Enabled = $true; $W.cancel.Enabled = $true
    $W.onNext = $null; $W.onBack = $null; $W.page = $title
}
function W-Run($label, $file, $arguments, $onDone) {
    # lanza un programa sin ventana, con su salida a un fichero que el temporizador va mostrando
    $log = Join-Path $env:TEMP ("schismlab_" + $label + ".log")
    $err = $log -replace '\.log$', '.err'
    Remove-Item -ErrorAction SilentlyContinue $log, $err
    $W.proc = Start-Process -FilePath $file -ArgumentList $arguments -WindowStyle Hidden -PassThru -WorkingDirectory $env:TEMP `
        -RedirectStandardOutput $log -RedirectStandardError $err
    $W.runLog = $log; $W.runErr = $err; $W.runPos = 0; $W.runErrPos = 0; $W.onDone = $onDone
    Add-Content -Path $W.fullLog -Value "`r`n===== $label ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) =====" -Encoding UTF8
    $W.timer.Start()
}
function W-ReadNew($path, $posKey) {
    if (-not (Test-Path $path)) { return "" }
    try {
        $fs = [IO.File]::Open($path, "Open", "Read", "ReadWrite")
        if ($fs.Length -le $W[$posKey]) { $fs.Close(); return "" }
        $fs.Seek($W[$posKey], "Begin") | Out-Null
        $buf = New-Object byte[] ($fs.Length - $W[$posKey]); $n = $fs.Read($buf, 0, $buf.Length); $fs.Close()
        $W[$posKey] += $n
        return ([Text.Encoding]::UTF8.GetString($buf, 0, $n)) -replace "`0", ""
    } catch { return "" }
}
function W-Tick {
    $new = (W-ReadNew $W.runLog "runPos") + (W-ReadNew $W.runErr "runErrPos")
    if ($new) {
        Add-Content -Path $W.fullLog -Value $new -NoNewline -Encoding UTF8
        if ($W.logBox -and -not $W.logBox.IsDisposed) {
            $W.logBox.AppendText(($new -replace "`r?`n", "`r`n"))
            if ($W.logBox.TextLength -gt 60000) { $W.logBox.Text = $W.logBox.Text.Substring($W.logBox.TextLength - 40000) }
        }
        $last = ($new -split "`r?`n" | Where-Object { $_ -match '^(>>|==) ' } | Select-Object -Last 1)
        if ($last -and $W.phase -and -not $W.phase.IsDisposed) { $W.phase.Text = ($last -replace '^(>>|==) ', '') }
    }
    if ($W.proc -and $W.proc.HasExited) {
        $W.timer.Stop(); $code = $W.proc.ExitCode; $W.proc = $null
        & $W.onDone $code
    }
}
function W-Wsl([string[]]$a) { if ($W.demo) { return "" } ; return ((& wsl.exe @a) -join "`n").Trim() }

# ---------------------------------------------------------------------------------------------------------- pantallas
function Show-Welcome {
    W-Page 0 "Bienvenida" -NoBack
    W-Label "Instalar SCHISMlab" 24 16 -Bold | Out-Null
    W-Label "SCHISMlab es el entorno de las prácticas de modelado del océano con SCHISM. Funciona dentro de Ubuntu (WSL2), que este asistente instala si hace falta." 66 | Out-Null
    W-Label "Lo que va a pasar:" 130 10 -Bold | Out-Null
    W-Label ("1. Ubuntu (WSL2). Si no estaba, se instala; puede que haya que reiniciar el ordenador una vez.`n" +
             "2. Un usuario de Linux, con su contraseña.`n" +
             "3. Tu token de acceso: te lo da el profesor (empieza por github_pat_).`n" +
             "4. La instalación de SCHISMlab: 10-30 minutos, sin que tengas que hacer nada.`n" +
             "5. Al terminar, el icono SCHISMlab en el escritorio y en el menú Inicio.") 156 10 -height 130 | Out-Null
    W-Label "Si te vas o se corta algo, vuelve a abrir el instalador: sigue por donde iba." 300 9.5 -color $W.gris | Out-Null
    $l = New-Object Windows.Forms.LinkLabel; $l.Text = "Borrar una instalación de SCHISMlab (por ejemplo, una de prueba)"
    $l.Left = 28; $l.Top = 336; $l.Width = 600; $l.Add_LinkClicked({ Show-Uninstall }); $W.body.Controls.Add($l)
    $W.onNext = { Show-Wsl }
}

function Get-Distros {
    if ($W.demo) { return @("Ubuntu", "Ubuntu-24.04") }
    $env:WSL_UTF8 = "1"
    try { return @((wsl.exe -l -q 2>$null) -replace "`0", "" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } catch { return @() }
}

function Show-Wsl {
    W-Page 1 "Ubuntu (WSL2)"
    W-Label "Ubuntu dentro de Windows" 24 14 -Bold | Out-Null
    $W.next.Enabled = $false; $W.onBack = { Show-Welcome }
    $distros = Get-Distros
    # elección hecha (por SCHISMLAB_DISTRO, el acceso directo de después del reinicio o Atrás): seguir con ella
    $ready = if ($W.demo) { $W.chosen } else { $W.chosen -and (Test-Distro $W.distro) }
    if ($ready -or ($env:SCHISMLAB_DISTRO -and -not $W.demo -and (Test-Distro $W.distro))) {
        W-Label "$MarkOk «$($W.distro)» está instalado y funciona." 70 11 -color $W.verde | Out-Null
        W-Button "Elegir otro" 28 110 160 | ForEach-Object { $_.Add_Click({ $W.chosen = $false; $env:SCHISMLAB_DISTRO = $null; Show-Wsl }) }
        $W.next.Enabled = $true; $W.onNext = { Show-User }; return
    }
    $wslOk = $W.demo
    if (-not $W.demo) { try { wsl.exe --status *> $null; $wslOk = ($LASTEXITCODE -eq 0) } catch {} }
    if (-not $wslOk -and -not (Test-Admin)) {
        W-Label "Hay que instalar WSL, y eso necesita permiso de administrador." 70 | Out-Null
        W-Label "Al pulsar el botón, Windows pregunta si permites los cambios: pulsa «Sí». El instalador se vuelve a abrir con permiso y sigue desde aquí." 100 | Out-Null
        $b = W-Button "Continuar como administrador" 28 170 260
        $b.Add_Click({
            try {
                Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy", "Bypass", "-Command", "irm $Ps1Url | iex"
                $W.form.Close()
            } catch { [Windows.Forms.MessageBox]::Show("Sin permiso de administrador no se puede instalar WSL.", "SCHISMlab") | Out-Null }
        })
        return
    }
    $W.optUse = $null
    $y = 66
    if ($distros.Count) {
        W-Label "Este ordenador ya tiene Ubuntu. Puedes instalar SCHISMlab en uno de ellos o en un Ubuntu nuevo, solo para SCHISMlab: así queda separado y se puede borrar entero cuando quieras (en la primera pantalla del instalador)." $y | Out-Null
        $y += 62
        $W.optUse = New-Object Windows.Forms.RadioButton; $W.optUse.Text = "Usar el que ya hay:"; $W.optUse.Left = 28; $W.optUse.Top = $y; $W.optUse.Width = 200
        $W.pick = New-Object Windows.Forms.ComboBox; $W.pick.DropDownStyle = "DropDownList"; $W.pick.Left = 232; $W.pick.Top = $y - 2; $W.pick.Width = 240
        $distros | ForEach-Object { [void]$W.pick.Items.Add($_) }
        $W.pick.SelectedItem = if ($distros -contains $Distro) { $Distro } else { $distros[0] }
        $W.body.Controls.AddRange(@($W.optUse, $W.pick)); $y += 36
    } else {
        W-Label "Se va a instalar Ubuntu (unos minutos; la descarga ocupa ~500 MB)." $y | Out-Null; $y += 36
    }
    $W.optNew = New-Object Windows.Forms.RadioButton; $W.optNew.Text = "Instalar un Ubuntu nuevo, con el nombre:"; $W.optNew.Left = 28; $W.optNew.Top = $y; $W.optNew.Width = 300
    $W.newName = New-Object Windows.Forms.TextBox; $W.newName.Left = 332; $W.newName.Top = $y - 2; $W.newName.Width = 200
    $W.newName.Text = if ($distros -notcontains "SCHISMlab") { "SCHISMlab" } else { "SCHISMlab-" + (Get-Date -Format "MMdd-HHmm") }
    $W.body.Controls.AddRange(@($W.optNew, $W.newName))
    if ($W.optUse) { $W.optUse.Checked = $true } else { $W.optNew.Checked = $true; $W.optNew.Visible = $false; $W.newName.Visible = $false; $W.newName.Text = $Distro }
    $W.newName.Add_TextChanged({ $W.optNew.Checked = $true }); if ($W.pick) { $W.pick.Add_SelectedIndexChanged({ $W.optUse.Checked = $true }) }
    $W.msg = W-Label "" ($y + 34) 9.5 -color $W.naranja
    $W.phase = W-Label "" ($y + 60) 9.5 -color $W.gris
    $W.logBox = W-Log ($y + 88) ([Math]::Max(80, 372 - ($y + 88))); $W.logBox.Visible = $false
    $W.next.Enabled = $true; $W.next.Text = "Siguiente"
    $W.onNext = {
        if ($W.optUse -and $W.optUse.Checked) {
            $W.distro = [string]$W.pick.SelectedItem; $W.chosen = $true
            if ($W.demo -or (Test-Distro $W.distro)) { Show-User } else { $W.msg.Text = "«$($W.distro)» no arranca: elige otro o instala uno nuevo." }
            return
        }
        $n = $W.newName.Text.Trim()
        if (-not ($n -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')) { $W.msg.Text = "El nombre solo puede tener letras sin acentos, números, punto, - y _."; return }
        if ($distros -contains $n) { $W.msg.Text = "Ya hay un Ubuntu que se llama «$n»: elige otro nombre."; return }
        $named = if ($n -ne $W.base) { @("--name", $n) } else { @() }
        $W.distro = $n; $W.chosen = $true; $W.msg.Text = ""
        $W.next.Enabled = $false; $W.back.Enabled = $false; $W.phase.Text = "Instalando Ubuntu «$n»…"; $W.logBox.Visible = $true
        if ($W.demo) { W-Run "wsl" "cmd.exe" @("/c", "echo instalando Ubuntu (demostracion) & ping -n 3 127.0.0.1 >nul") { param($code) Show-User }; return }
        $env:WSL_UTF8 = "1"
        W-Run "wsl" "wsl.exe" (@("--install", "-d", $W.base) + $named + @("--no-launch")) {
            param($code)
            if (Test-Distro $W.distro) { Show-User } else { Show-Reboot }
        }
    }
}

function Show-Uninstall {
    W-Page 0 "Borrar una instalación"
    W-Label "Borrar una instalación de SCHISMlab" 24 14 -Bold | Out-Null
    $W.onBack = { Show-Welcome }
    W-Label "Borra un Ubuntu entero (con SCHISMlab, sus casos y sus resultados) y los iconos de SCHISMlab que lo abren. No se puede deshacer: copia antes lo que quieras conservar." 66 | Out-Null
    $W.pick = New-Object Windows.Forms.ComboBox; $W.pick.DropDownStyle = "DropDownList"; $W.pick.Left = 28; $W.pick.Top = 130; $W.pick.Width = 300
    Get-Distros | ForEach-Object { [void]$W.pick.Items.Add($_) }
    $W.body.Controls.Add($W.pick)
    $first = @($W.pick.Items | Where-Object { $_ -like "SCHISMlab*" })[0]
    if ($first) { $W.pick.SelectedItem = $first }         # si no hay ninguno «SCHISMlab…», no se preselecciona nada
    $W.msg = W-Label "" 170 10
    $W.next.Text = "Borrar"; $W.next.BackColor = $W.naranja
    $W.onNext = {
        $n = [string]$W.pick.SelectedItem
        if (-not $n) { $W.msg.ForeColor = $W.naranja; $W.msg.Text = "Elige el Ubuntu que quieres borrar."; return }
        $r = [Windows.Forms.MessageBox]::Show("Se va a borrar el Ubuntu «$n» entero, con todo lo que tiene dentro. ¿Seguro?", "SCHISMlab", "YesNo", "Warning")
        if ($r -ne "Yes") { return }
        if (-not $W.demo) { wsl.exe --terminate $n *> $null; wsl.exe --unregister $n *> $null }
        $gone = @()
        foreach ($d in @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Programs"))) {
            foreach ($f in @("SCHISMlab.lnk", "$ContinueName.lnk")) {
                $p = Join-Path $d $f
                if (Test-Path $p) {
                    $a = (New-Object -ComObject WScript.Shell).CreateShortcut($p).Arguments
                    if ($a -match "-d $([regex]::Escape($n))( |$)" -or $f -ne "SCHISMlab.lnk") { if (-not $W.demo) { Remove-Item $p }; $gone += $f }
                }
            }
        }
        $W.msg.ForeColor = $W.verde
        $W.msg.Text = "$MarkOk Borrado «$n»" + $(if ($gone) { " y sus iconos." } else { "." })
        $W.pick.Items.Remove($n)
    }
}

function Show-Reboot {
    W-Page 1 "Reiniciar" "Reiniciar ahora" -NoBack
    W-Label "Hay que reiniciar el ordenador" 24 14 -Bold | Out-Null
    W-Label "Windows necesita reiniciarse para terminar de instalar WSL." 70 | Out-Null
    W-Label "Después del reinicio, haz doble clic en el icono «$ContinueName» del escritorio: el instalador se abre y sigue por donde iba." 104 | Out-Null
    W-Label "Puede que tras el reinicio se abra sola una ventana de Ubuntu que pide un nombre de usuario: si aparece, ciérrala (el usuario se crea en el paso siguiente del instalador)." 170 9.5 -color $W.gris | Out-Null
    if (-not $W.demo) { New-Shortcut $ContinueName "powershell.exe" "-ExecutionPolicy Bypass -Command `"`$env:SCHISMLAB_DISTRO='$($W.distro)'; irm $Ps1Url | iex`"" "Sigue la instalación de SCHISMlab" | Out-Null }
    $W.cancel.Text = "Reiniciar más tarde"
    $W.onNext = { if (-not $W.demo) { Restart-Computer -Force } ; $W.form.Close() }
}

function Show-User {
    W-Page 2 "Usuario de Linux"
    W-Label "Usuario de Linux" 24 14 -Bold | Out-Null
    $W.onBack = { Show-Wsl }
    $uid = if ($W.demo) { "0" } else { W-Wsl @("-d", $W.distro, "--", "id", "-u") }
    if ($uid -ne "0") {
        $name = W-Wsl @("-d", $W.distro, "--", "id", "-un")
        W-Label "$MarkOk Ubuntu ya tiene usuario: $name" 70 11 -color $W.verde | Out-Null
        $W.onNext = { Show-Token }; return
    }
    W-Label "SCHISM no puede ejecutarse como administrador (root): hace falta un usuario normal de Linux. Elige un nombre (minúsculas, sin espacios ni acentos) y una contraseña; Linux la pide para instalar programas." 66 | Out-Null
    $u = W-Input "Nombre de usuario (p. ej. ana)" 130
    $p1 = W-Input "Contraseña" 190 -Secret
    $p2 = W-Input "Repite la contraseña" 250 -Secret
    $msg = W-Label "" 316 9.5 -color $W.naranja
    $W.u = $u; $W.p1 = $p1; $W.p2 = $p2; $W.msg = $msg
    $W.onNext = {
        $name = $W.u.Text.Trim().ToLower()
        if (-not ($name -match '^[a-z_][a-z0-9_-]{0,31}$')) { $W.msg.Text = "El nombre solo puede tener minúsculas, números, - y _ (y empezar por una letra)."; return }
        if (-not $W.p1.Text) { $W.msg.Text = "Escribe una contraseña."; return }
        if ($W.p1.Text -ne $W.p2.Text) { $W.msg.Text = "Las dos contraseñas no coinciden."; return }
        $W.msg.ForeColor = $W.gris; $W.msg.Text = "Creando el usuario…"; $W.form.Refresh()
        if (-not $W.demo) {
            wsl.exe -d $W.distro -u root -- bash -c "id -u $name >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo $name"
            "${name}:$($W.p1.Text)" | wsl.exe -d $W.distro -u root -- chpasswd
            wsl.exe -d $W.distro -u root -- bash -c "touch /etc/wsl.conf; sed -i '/^default=/d' /etc/wsl.conf; grep -q '^\[user\]' /etc/wsl.conf || printf '\n[user]\n' >> /etc/wsl.conf; sed -i 's/^\[user\]/[user]\ndefault=$name/' /etc/wsl.conf"
            wsl.exe --terminate $W.distro | Out-Null
            if ((W-Wsl @("-d", $W.distro, "--", "id", "-u")) -eq "0") { $W.msg.ForeColor = $W.naranja; $W.msg.Text = "No se ha podido crear el usuario $name."; return }
        }
        Show-Token
    }
}

function Show-Token {
    W-Page 3 "Token de acceso"
    W-Label "Tu token de acceso" 24 14 -Bold | Out-Null
    $W.onBack = { Show-User }
    $saved = if ($W.demo) { "" } else { W-Wsl @("-d", $W.distro, "--", "bash", "-c", "test -s ~/.schismlab/credentials/github_token && echo si") }
    W-Label "El código de SCHISMlab está en un repositorio privado. Pega aquí el token personal que te ha dado el profesor (empieza por github_pat_). Es solo para ti: no lo compartas. Se guarda solo en este ordenador." 66 | Out-Null
    $t = W-Input "Token (botón derecho $Fl Pegar, o Ctrl+V)" 136 -Secret
    $W.tok = $t
    $W.msg = W-Label "" 200 9.5 -color $W.naranja
    if ($saved -eq "si") { $W.msg.ForeColor = $W.gris; $W.msg.Text = "Ya hay un token guardado en Ubuntu: deja la casilla vacía para usarlo." }
    $W.saved = ($saved -eq "si")
    $W.onNext = {
        $tok = ($W.tok.Text -replace '\s', '')
        if (-not $tok -and $W.saved) { $W.token = ""; $W.edition = "SCHISMlab"; Show-Install; return }
        if (-not $tok.StartsWith("github_pat_") -and -not $tok.StartsWith("ghp_")) { $W.msg.ForeColor = $W.naranja; $W.msg.Text = "Eso no parece un token: empieza por github_pat_."; return }
        $W.msg.ForeColor = $W.gris; $W.msg.Text = "Comprobando con GitHub…"; $W.form.Refresh()
        if ($W.demo) { $W.token = $tok; $W.edition = "SCHISMlab Lite"; Show-Install; return }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $h = @{ Authorization = "Bearer $tok"; "User-Agent" = "SCHISMlab"; Accept = "application/vnd.github+json" }
        try { Invoke-RestMethod -Headers $h "https://api.github.com/repos/$Repo" | Out-Null }
        catch {
            $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
            $W.msg.ForeColor = $W.naranja
            $W.msg.Text = if ($code -eq 401) { "El token no es válido o ha caducado: pide uno nuevo al profesor." }
                          elseif ($code -eq 403 -or $code -eq 404) { "Este token no da acceso a SCHISMlab: comprueba que lo has copiado entero o pide otro." }
                          else { "No se ha podido comprobar el token (¿hay conexión a Internet?)." }
            return
        }
        $pro = $false
        try { Invoke-RestMethod -Headers $h "https://api.github.com/repos/$ProRepo" | Out-Null; $pro = $true } catch {}
        $W.token = $tok; $W.edition = if ($pro) { "SCHISMlab Pro" } else { "SCHISMlab Lite" }
        Show-Install
    }
}

function Show-Install {
    W-Page 4 "Instalación" "Instalando…" -NoBack
    W-Label "Instalando $($W.edition)" 24 14 -Bold | Out-Null
    W-Label "Tarda 10-30 minutos (más si hay que compilar SCHISM). No hace falta que hagas nada; puedes minimizar la ventana, pero no la cierres." 62 | Out-Null
    $W.next.Enabled = $false
    $bar = New-Object Windows.Forms.ProgressBar
    $bar.Left = 28; $bar.Top = 112; $bar.Width = 660; $bar.Height = 14; $bar.Style = "Marquee"; $bar.MarqueeAnimationSpeed = 30
    $W.body.Controls.Add($bar)
    $W.phase = W-Label "Preparando Ubuntu…" 134 9.5 -color $W.gris
    $W.logBox = W-Log 162 190
    if ($W.token) { $env:SCHISMLAB_TOKEN = $W.token; if ($env:WSLENV -notmatch 'SCHISMLAB_TOKEN') { $env:WSLENV = (@($env:WSLENV, "SCHISMLAB_TOKEN/u") | Where-Object { $_ }) -join ":" } }
    $user = { W-Run "instalar" "wsl.exe" @("-d", $W.distro, "--", "bash", "-lc", "`"export PYTHONUNBUFFERED=1; curl -fsSL '$Url' -o /tmp/instalar_schismlab.sh && bash /tmp/instalar_schismlab.sh $Variant`"") { param($code) if ($code -eq 0) { Show-Done } else { Show-Failed $code } } }
    if ($W.demo) {
        W-Run "demo" "cmd.exe" @("/c", "for /l %i in (1,1,6) do @(echo ^>^> paso de demostracion %i & ping -n 2 127.0.0.1 >nul)") { param($code) Show-Done }
        return
    }
    # paquetes del sistema como root (sin contraseña): así instalar.sh e install.sh no necesitan sudo
    $W.userStep = $user
    W-Run "paquetes" "wsl.exe" @("-d", $W.distro, "-u", "root", "--", "bash", "-c", "`"export DEBIAN_FRONTEND=noninteractive; echo '>> paquetes de Ubuntu (git, curl, compiladores de apoyo)'; apt-get update -qq && apt-get install -y -qq git curl subversion autoconf automake libtool`"") {
        param($code)
        if ($code -eq 0) { & $W.userStep } else { Show-Failed $code }
    }
}

function Show-Done {
    W-Page 5 "Listo" "Terminar" -NoBack
    $env:SCHISMLAB_TOKEN = $null
    Remove-Shortcut $ContinueName
    W-Label "$MarkOk $($W.edition) está instalado" 24 14 -Bold -color $W.verde | Out-Null
    W-Label "Para abrirlo, haz doble clic en el icono «SCHISMlab» del escritorio o del menú Inicio (se puede anclar a la barra de tareas). Se abre en el navegador, sin ninguna ventana negra." 70 | Out-Null
    W-Label "Para cerrarlo: en SCHISMlab, menú ⋮ (arriba a la derecha) $Fl Cerrar SCHISMlab. Si algo falla, el menú ⋮ $Fl Registro dice por qué." 136 | Out-Null
    W-Label "Está en el Ubuntu «$($W.distro)». Para borrarlo entero, abre otra vez este instalador $Fl «Borrar una instalación de SCHISMlab»." 250 9.5 -color $W.gris | Out-Null
    $c = New-Object Windows.Forms.CheckBox
    $c.Text = "Abrir SCHISMlab ahora"; $c.Checked = $true; $c.Left = 28; $c.Top = 200; $c.Width = 400
    $c.Font = New-Object Drawing.Font("Segoe UI", 10); $W.body.Controls.Add($c); $W.openNow = $c
    $W.cancel.Visible = $false
    $W.onNext = {
        if ($W.openNow.Checked -and -not $W.demo) {
            $lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "SCHISMlab.lnk"
            if (Test-Path $lnk) { Invoke-Item $lnk }
            else { Start-Process wsl.exe -WindowStyle Hidden -ArgumentList "-d", $W.distro, "--", "bash", "-lc", "`"cd ~/schismlab && ~/.pixi/bin/pixi run schismlab abrir`"" }
        }
        $W.form.Close()
    }
}

function Show-Failed($code) {
    W-Page 4 "La instalación se ha parado" "Reintentar" -NoBack
    $env:SCHISMLAB_TOKEN = $null
    W-Label "La instalación se ha parado" 24 14 -Bold -color $W.naranja | Out-Null
    W-Label "El motivo suele estar en las últimas líneas. Si se cortó la conexión, pulsa Reintentar: sigue por donde iba. Si se repite, manda el registro completo al profesor." 64 | Out-Null
    $box = W-Log 124 190
    try { $box.Text = ((Get-Content $W.fullLog -Tail 40 -Encoding UTF8) -join "`r`n"); $box.SelectionStart = $box.TextLength; $box.ScrollToCaret() } catch {}
    $b = W-Button "Abrir el registro completo" 28 326 240
    $b.Add_Click({ Start-Process notepad.exe $W.fullLog })
    $W.onNext = { Show-Token }
}

function Start-Wizard {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()
    $W.demo = [bool]$env:SCHISMLAB_DEMO
    $W.distro = $Distro; $W.base = "Ubuntu-24.04"; $W.chosen = [bool]$env:SCHISMLAB_DISTRO
    $W.grafito = [Drawing.Color]::FromArgb(43, 43, 43); $W.turquesa = [Drawing.Color]::FromArgb(14, 154, 167)
    $W.verde = [Drawing.Color]::FromArgb(47, 143, 91); $W.naranja = [Drawing.Color]::FromArgb(216, 84, 43)
    $W.gris = [Drawing.Color]::FromArgb(106, 106, 106)
    $W.fullLog = Join-Path $env:TEMP "schismlab_instalacion.log"
    Add-Content -Path $W.fullLog -Value "`r`n##### instalador de SCHISMlab $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8

    $f = New-Object Windows.Forms.Form
    $f.Text = "Instalar SCHISMlab"; $f.ClientSize = New-Object Drawing.Size(720, 520); $f.StartPosition = "CenterScreen"
    $f.FormBorderStyle = "FixedSingle"; $f.MaximizeBox = $false; $f.BackColor = [Drawing.Color]::White
    $f.Font = New-Object Drawing.Font("Segoe UI", 10)
    $ico = Join-Path $env:TEMP "schismlab.ico"
    try { if (-not (Test-Path $ico)) { Invoke-WebRequest -UseBasicParsing $IcoUrl -OutFile $ico }; $f.Icon = New-Object Drawing.Icon($ico) } catch {}
    $W.form = $f

    $head = New-Object Windows.Forms.Panel; $head.Dock = "Top"; $head.Height = 72; $head.BackColor = $W.grafito
    $png = Join-Path $env:TEMP "schismlab.png"           # el .ico lleva PNG dentro, que Icon.ToBitmap no sabe leer
    try {
        if (-not (Test-Path $png)) { Invoke-WebRequest -UseBasicParsing $PngUrl -OutFile $png }
        $pic = New-Object Windows.Forms.PictureBox; $pic.Left = 20; $pic.Top = 12; $pic.Width = 48; $pic.Height = 48
        $pic.SizeMode = "Zoom"; $pic.Image = [Drawing.Image]::FromFile($png); $head.Controls.Add($pic)
    } catch {}
    $t1 = New-Object Windows.Forms.Label; $t1.Text = "SCHISMlab"; $t1.ForeColor = [Drawing.Color]::White
    $t1.Font = New-Object Drawing.Font("Segoe UI Semibold", 16); $t1.Left = 80; $t1.Top = 8; $t1.AutoSize = $true; $head.Controls.Add($t1)
    $W.step = New-Object Windows.Forms.Label; $W.step.ForeColor = [Drawing.Color]::FromArgb(190, 230, 233)
    $W.step.Font = New-Object Drawing.Font("Segoe UI", 9.5); $W.step.Left = 82; $W.step.Top = 42; $W.step.Width = 600; $head.Controls.Add($W.step)
    $line = New-Object Windows.Forms.Panel; $line.Dock = "Top"; $line.Height = 3; $line.BackColor = $W.turquesa

    $foot = New-Object Windows.Forms.Panel; $foot.Dock = "Bottom"; $foot.Height = 58; $foot.BackColor = [Drawing.Color]::FromArgb(239, 239, 239)
    $W.cancel = New-Object Windows.Forms.Button; $W.cancel.Text = "Cancelar"; $W.cancel.Left = 20; $W.cancel.Top = 12; $W.cancel.Width = 150; $W.cancel.Height = 34
    $W.back = New-Object Windows.Forms.Button; $W.back.Text = "Atrás"; $W.back.Left = 410; $W.back.Top = 12; $W.back.Width = 130; $W.back.Height = 34
    $W.next = New-Object Windows.Forms.Button; $W.next.Left = 550; $W.next.Top = 12; $W.next.Width = 150; $W.next.Height = 34
    $W.next.FlatStyle = "Flat"; $W.next.BackColor = $W.turquesa; $W.next.ForeColor = [Drawing.Color]::White
    $foot.Controls.AddRange(@($W.cancel, $W.back, $W.next))
    $W.body = New-Object Windows.Forms.Panel; $W.body.Dock = "Fill"
    $f.Controls.AddRange(@($W.body, $line, $head, $foot))
    $f.AcceptButton = $W.next

    $W.next.Add_Click({ if ($W.onNext) { & $W.onNext } })
    $W.back.Add_Click({ if ($W.onBack) { & $W.onBack } })
    $W.cancel.Add_Click({ $W.form.Close() })
    $f.Add_FormClosing({
        param($s, $e)
        if ($W.proc -and -not $W.proc.HasExited) {
            $r = [Windows.Forms.MessageBox]::Show("La instalación está en marcha. Si cierras, se para (puedes seguir después abriendo el instalador otra vez). ¿Cerrar?", "SCHISMlab", "YesNo", "Warning")
            if ($r -ne "Yes") { $e.Cancel = $true; return }
            try { $W.proc.Kill() } catch {}
        }
        $env:SCHISMLAB_TOKEN = $null
    })
    $W.timer = New-Object Windows.Forms.Timer; $W.timer.Interval = 500; $W.timer.Add_Tick({ W-Tick })
    if ($env:SCHISMLAB_DEMO_CAPTURA) { Start-DemoCapture }
    Show-Welcome
    [void]$f.ShowDialog()
}

function Start-DemoCapture {
    # SCHISMLAB_DEMO=1 y SCHISMLAB_DEMO_CAPTURA=<carpeta>: recorre las pantallas sola y guarda una imagen de cada una
    $W.form.StartPosition = "Manual"; $W.form.Location = New-Object Drawing.Point(-4000, -4000); $W.form.ShowInTaskbar = $false
    $W.shots = 0; $W.extra = @("reboot", "failed", "uninstall")
    $W.cap = New-Object Windows.Forms.Timer; $W.cap.Interval = 1600
    $W.cap.Add_Tick({
        if ($W.proc -and $W.lastShot -eq $W.page) { return }       # instalando: una captura a mitad y se espera
        $W.lastShot = $W.page
        $W.shots++; $bmp = New-Object Drawing.Bitmap($W.form.Width, $W.form.Height)
        $W.form.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0, 0, $W.form.Width, $W.form.Height)))
        $bmp.Save((Join-Path $env:SCHISMLAB_DEMO_CAPTURA ("{0:D2}_{1}.png" -f $W.shots, ($W.page -replace '[^\w]+', '_')))); $bmp.Dispose()
        switch ($W.page) {
            "Usuario de Linux" { $W.u.Text = "ana"; $W.p1.Text = "x"; $W.p2.Text = "x" }
            "Token de acceso" { $W.tok.Text = "github_pat_demostracion" }
        }
        if ($W.page -eq "Listo") {
            if ($W.extra.Count) { $x = $W.extra[0]; $W.extra = @($W.extra | Select-Object -Skip 1); if ($x -eq "reboot") { Show-Reboot } elseif ($x -eq "uninstall") { Show-Uninstall } else { Show-Failed 1 } ; return }
            $W.cap.Stop(); $W.openNow.Checked = $false; $W.next.PerformClick(); return
        }
        if ($W.page -in @("Reiniciar", "La instalación se ha parado", "Borrar una instalación")) { Show-Done; $W.extra = @($W.extra); return }
        if ($W.next.Enabled) { $W.next.PerformClick() }
    })
    $W.cap.Start()
}

if ($Interactive -and -not $env:SCHISMLAB_CONSOLA) {
    try { Start-Wizard; return }
    catch { Write-Host "No se ha podido abrir el asistente ($($_.Exception.Message)); sigue en la consola." -ForegroundColor Yellow }
}

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

# los accesos directos «SCHISMlab» (escritorio y menú Inicio) los crea install.sh (schismlab accesos), sin ventana negra
$desk = [Environment]::GetFolderPath("Desktop")
$lnk = if ($desk) { Join-Path $desk "SCHISMlab.lnk" } else { $null }
Write-Host ""
Write-Host "== SCHISMlab instalado." -ForegroundColor Green
if ($lnk -and (Test-Path $lnk)) {
    Write-Host "   Para abrirlo: doble clic en el icono «SCHISMlab» del escritorio o del menú Inicio. Se abre en el navegador;"
    Write-Host "   para cerrarlo, menú ⋮ $Fl Cerrar SCHISMlab."
} else {
    Write-Host "   Para abrirlo, en Ubuntu:  cd ~/schismlab && ~/.pixi/bin/pixi run schismlab abrir"
}
if ($Interactive -and ((Read-Host "¿Abrir SCHISMlab ahora? (s/n)").Trim().ToLower() -eq "s")) {
    if ($lnk -and (Test-Path $lnk)) { Invoke-Item $lnk }
    else { Start-Process wsl.exe -ArgumentList "-d", $Distro, "--", "bash", "-lc", "`"cd ~/schismlab && ~/.pixi/bin/pixi run schismlab abrir`"" }
}
