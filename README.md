# Instalador de SCHISMlab

SCHISMlab es el entorno de las prácticas de modelado numérico con [SCHISM](https://schism-dev.github.io/schism/).
El código está en un repositorio privado: para instalarlo necesitas el **token de acceso personal** que te da el
profesor (empieza por `github_pat_`). Es solo para ti: no lo compartas.

## Linux y macOS

```bash
curl -fsSL https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.sh | bash
```

## Windows 10/11

Abre PowerShell (mejor con botón derecho → *Ejecutar como administrador*) y pega:

```powershell
Set-ExecutionPolicy -Scope Process Bypass; irm https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.ps1 | iex
```

Va por pasos y, si tiene que pararse, lo dice en un recuadro **QUÉ HACER AHORA**. Se puede volver a ejecutar siempre
que haga falta: sigue por donde iba. En un ordenador sin WSL:

1. Si PowerShell no era de administrador, se abre sola otra ventana como administrador: sigue en ella.
2. Instala WSL y Ubuntu y pide **reiniciar**. Deja en el escritorio el acceso directo «Continuar instalación de
   SCHISMlab».
3. Tras el reinicio puede abrirse una ventana de Ubuntu que pide usuario y contraseña de Linux: rellénalos y ciérrala.
4. Doble clic en «Continuar instalación de SCHISMlab»: pide el token y lo instala todo (10–30 minutos). No cierres la
   ventana aunque algún mensaje hable de reiniciar la terminal.
5. Al terminar, el acceso directo «SCHISMlab» del escritorio abre la interfaz.

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
`pixi run schismlab gui`) y se abre <http://localhost:8765>. En Windows, el acceso directo «SCHISMlab».

Si el token caduca o te lo retiran, pide uno nuevo y pégalo en la interfaz, en **Instalación → Token de acceso**.
