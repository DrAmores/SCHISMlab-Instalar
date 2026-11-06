# Instalador de SCHISMlab

SCHISMlab es el entorno de las prácticas de modelado numérico con [SCHISM](https://schism-dev.github.io/schism/).
El código está en un repositorio privado: para instalarlo necesitas el **token de acceso personal** que te da el
profesor (empieza por `github_pat_`). Es solo para ti: no lo compartas.

## Linux y macOS

```bash
curl -fsSL https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.sh | bash
```

## Windows 10/11

Abre PowerShell (menú Inicio → escribe «PowerShell») y pega:

```powershell
Set-ExecutionPolicy -Scope Process Bypass; irm https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.ps1 | iex
```

Se abre un **asistente con ventanas** que va por pasos (Ubuntu, usuario de Linux, token, instalación) y dice en cada
momento lo que hay que hacer. Se puede cerrar y volver a abrir: sigue por donde iba. Si Windows tiene que
reiniciarse, deja en el escritorio el acceso directo «Continuar instalación de SCHISMlab» para después del reinicio.
Al terminar, el icono «SCHISMlab» del escritorio y del menú Inicio abre la interfaz (sin ventana negra; se cierra
desde el menú ⋮ → Cerrar SCHISMlab). Si ya hay Ubuntu, deja elegir entre usarlo o instalar uno nuevo solo para SCHISMlab, con nombre propio (por
defecto «SCHISMlab»); la primera pantalla tiene *Borrar una instalación de SCHISMlab*, que lo quita entero con sus
iconos (o `wsl --unregister SCHISMlab`). Con `$env:SCHISMLAB_CONSOLA=1` se hace en la consola, sin ventanas.

## macOS

Si faltan las *Command Line Tools* de Xcode, se abre una ventana para instalarlas: pulsa *Instalar* y no cierres la
terminal; la instalación sigue sola.

## Qué hace

1. Te pide el token, comprueba con GitHub que da acceso y lo guarda solo en tu ordenador
   (`~/.schismlab/credentials/github_token`).
2. Descarga SCHISMlab en `~/schismlab`. Si el token también da acceso a SCHISMlab Pro, descarga Pro en
   `~/.schismlab/pro` y lo instala a la vez.
3. Instala el entorno (pixi), descarga o compila SCHISM y ejecuta un caso de prueba.

Al terminar: `cd ~/schismlab && ~/.pixi/bin/pixi run schismlab gui` (en la misma terminal; en las nuevas basta con
`pixi run schismlab gui`) y se abre <http://localhost:8765>. En los tres sistemas, el instalador crea además el icono «SCHISMlab» (escritorio y
menú), que lo abre sin terminal.

Si el token caduca o te lo retiran, pide uno nuevo y pégalo en la interfaz, en **Instalación → Token de acceso**.
