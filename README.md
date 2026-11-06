# Instalador de SCHISMlab

SCHISMlab es el entorno de las prácticas de modelado numérico con [SCHISM](https://schism-dev.github.io/schism/).
El código está en un repositorio privado: para instalarlo necesitas el **token de acceso personal** que te da el
profesor (empieza por `github_pat_`). Es solo para ti: no lo compartas. Si tu token también da acceso a SCHISMlab
Pro, se instala Pro a la vez.

## Windows 10/11

Abre PowerShell (menú Inicio → escribe «PowerShell») y pega:

```powershell
Set-ExecutionPolicy -Scope Process Bypass; irm https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.ps1 | iex
```

Se abre un **asistente con ventanas** que va por pasos y dice en cada momento lo que hay que hacer:

1. **Ubuntu (WSL2).** Si no estaba, lo instala (si hace falta, pide permiso de administrador y, a veces, reiniciar:
   deja en el escritorio el acceso directo «Continuar instalación de SCHISMlab» para seguir después del reinicio).
   Si ya hay Ubuntu, deja elegir entre usarlo o instalar uno nuevo solo para SCHISMlab, con nombre propio.
2. **Usuario de Linux**, con su contraseña.
3. **Token de acceso**, que se comprueba con GitHub.
4. **Instalación** (10–30 minutos), sin que tengas que hacer nada.
5. **Listo**: el icono «SCHISMlab» del escritorio y del menú Inicio abre la interfaz en el navegador, sin ninguna
   ventana negra. Se cierra desde el menú ⋮ → Cerrar SCHISMlab.

Se puede cerrar y volver a abrir: sigue por donde iba. La primera pantalla tiene *Borrar una instalación de
SCHISMlab*, que quita entero un Ubuntu con sus iconos (o, a mano, `wsl --unregister <nombre>`). Con
`$env:SCHISMLAB_CONSOLA=1` antes de la orden se hace en la consola, sin ventanas.

## Linux y macOS

```bash
curl -fsSL https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.sh | bash
```

Pide el token (al pegarlo no se ve) y lo instala todo. En macOS, si faltan las *Command Line Tools* de Xcode, se abre
una ventana para instalarlas: pulsa *Instalar* y no cierres la terminal; la instalación sigue sola. Al terminar queda
el icono «SCHISMlab» (menú de aplicaciones en Linux; `~/Applications` y Launchpad en macOS). Desde la terminal:
`cd ~/schismlab && ~/.pixi/bin/pixi run schismlab gui`.

## Qué hace

1. Comprueba con GitHub que el token da acceso y lo guarda solo en tu ordenador
   (`~/.schismlab/credentials/github_token`, permisos 600).
2. Descarga SCHISMlab en `~/schismlab` (y SCHISMlab Pro en `~/.schismlab/pro`, si el token da acceso).
3. Instala el entorno (pixi), descarga SCHISM ya compilado (o lo compila) y ejecuta un caso de prueba.
4. Crea los accesos directos.

Si el token caduca o te lo retiran, pide uno nuevo y pégalo en la interfaz, en **Instalación → Token de acceso**.
