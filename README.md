# Instalador de SCHISMlab

SCHISMlab es el entorno de las prácticas de modelado numérico con [SCHISM](https://schism-dev.github.io/schism/).
El código está en un repositorio privado: para instalarlo necesitas el **token de acceso personal** que te da el
profesor (empieza por `github_pat_`). Es solo para ti: no lo compartas.

## Linux y macOS

```bash
curl -fsSL https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.sh | bash
```

## Windows 10/11

Abre PowerShell **como administrador** y ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass; irm https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.ps1 | iex
```

Si WSL2 no estaba instalado, el ordenador pedirá reiniciarse: después, vuelve a ejecutar la misma orden.

## Qué hace

1. Te pide el token, comprueba con GitHub que da acceso y lo guarda solo en tu ordenador
   (`~/.schismlab/credentials/github_token`).
2. Descarga SCHISMlab en `~/schismlab`.
3. Instala el entorno (pixi), descarga o compila SCHISM y ejecuta un caso de prueba.

Al terminar: `cd ~/schismlab && pixi run schismlab gui` y abre <http://localhost:8765>.

Si el token caduca o te lo retiran, pide uno nuevo y pégalo en la interfaz, en **Instalación → Token de acceso**.
