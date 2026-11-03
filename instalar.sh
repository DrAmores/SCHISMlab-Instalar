#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SCHISMlab: instalador público (Linux, WSL2 y macOS). El código de SCHISMlab está en un repositorio privado: este
# script pide el token personal que da el profesor, lo comprueba, lo guarda solo en este ordenador
# (~/.schismlab/credentials/github_token, permisos 600), clona SCHISMlab en ~/schismlab y lanza su instalador.
#
#   curl -fsSL https://raw.githubusercontent.com/DrAmores/SCHISMlab-Instalar/main/instalar.sh | bash
#   bash instalar.sh [hydro|wwm]
#
# Variables opcionales: SCHISMLAB_TOKEN (no preguntar), SCHISMLAB_DIR (carpeta del clon, ~/schismlab),
# SCHISMLAB_REPO (propietario/nombre, DrAmores/SCHISMlab-Lite), SCHISMLAB_SOLO_DESCARGAR=1 (clonar sin instalar),
# SCHISMLAB_PRO_REPO (DrAmores/SCHISMlab-Pro). Si el token también da acceso a SCHISMlab Pro, se instala Pro a la vez.
# El token nunca se escribe en la línea de órdenes ni en .git/config: git lo lee con un ayudante de credenciales.
# ---------------------------------------------------------------------------
set -euo pipefail
REPO="${SCHISMLAB_REPO:-DrAmores/SCHISMlab-Lite}"
DEST="${SCHISMLAB_DIR:-$HOME/schismlab}"
VARIANT="${1:-hydro}"
GIT_URL="${SCHISMLAB_GIT_URL:-https://github.com/$REPO.git}"     # otra URL: pruebas
API="${SCHISMLAB_API:-https://api.github.com}"
CRED="$HOME/.schismlab/credentials"; TOKFILE="$CRED/github_token"; HELPER="$CRED/git-credential-schismlab"
KEY="credential.https://github.com.helper"
export GIT_TERMINAL_PROMPT=0

echo "== SCHISMlab: instalación ($REPO en $DEST)"

# SCHISM se ejecuta con OpenMPI, que no funciona como root: SCHISMlab se instala con un usuario normal
if [[ "$(id -u)" == "0" && -z "${SCHISMLAB_PERMITIR_ROOT:-}" ]]; then
  echo "ERROR: estás como root. SCHISMlab se instala con tu usuario normal (OpenMPI no ejecuta SCHISM como root)." >&2
  echo "       En Windows, vuelve a ejecutar instalar.ps1: crea el usuario de Linux si falta." >&2
  echo "       En Linux: crea un usuario (sudo adduser nombre), entra con él y vuelve a ejecutar el instalador." >&2
  exit 1
fi

# 0. git y curl ---------------------------------------------------------------------
# en macOS, /usr/bin/git existe aunque falten las Command Line Tools (solo abre un diálogo): se comprueban ellas
if [[ "$(uname -s)" == "Darwin" ]] && ! xcode-select -p >/dev/null 2>&1; then
  echo ">> faltan las Command Line Tools de Xcode: se abre una ventana para instalarlas."
  echo "   QUÉ HACER AHORA: en esa ventana pulsa «Instalar» y acepta la licencia (5-15 minutos)."
  echo "   No cierres esta terminal: la instalación de SCHISMlab sigue sola cuando terminen."
  xcode-select --install >/dev/null 2>&1 || true
  for _ in $(seq 1 240); do                       # hasta 2 horas
    xcode-select -p >/dev/null 2>&1 && break
    sleep 30; printf "."
  done; echo
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "ERROR: las Command Line Tools no se han instalado. Instálalas (xcode-select --install) y vuelve a pegar" >&2
    echo "       la misma orden de instalación: sigue por donde iba." >&2
    exit 1
  fi
  echo ">> Command Line Tools instaladas"
fi
if ! command -v git >/dev/null || ! command -v curl >/dev/null; then
  if command -v apt-get >/dev/null; then
    echo ">> instalando git y curl (se pedirá la contraseña de administrador)"
    sudo apt-get update -qq && sudo apt-get install -y -qq git curl
  else
    echo "ERROR: faltan git o curl" >&2; exit 1
  fi
fi

# 1. token --------------------------------------------------------------------------
check_token() {   # check_token TOKEN [REPO]  0: acceso; 1: sin acceso o caducado; 2: sin conexión
  local code slug="${2:-$REPO}"
  code=$(printf 'header = "Authorization: Bearer %s"\n' "$1" |
         curl -sS -K - -o /dev/null -w '%{http_code}' -H "User-Agent: SCHISMlab" -H "Accept: application/vnd.github+json" \
              "$API/repos/$slug" 2>/dev/null) || return 2
  case "$code" in
    200) return 0 ;;
    401) echo "   el token no es válido o ha caducado" >&2; return 1 ;;
    403|404) echo "   el token no da acceso a $slug" >&2; return 1 ;;
    000) return 2 ;;
    *) echo "   GitHub ha respondido $code" >&2; return 1 ;;
  esac
}
TOKEN="${SCHISMLAB_TOKEN:-}"
if [[ -z "$TOKEN" && -s "$TOKFILE" ]]; then
  TOKEN="$(cat "$TOKFILE")"; echo ">> se usa el token guardado en $TOKFILE"
fi
for intento in 1 2 3; do
  if [[ -z "$TOKEN" ]]; then
    if [[ ! -r /dev/tty ]]; then echo "ERROR: sin terminal para pedir el token: usa SCHISMLAB_TOKEN=..." >&2; exit 1; fi
    printf "Pega tu token de acceso a SCHISMlab (empieza por github_pat_; no se ve al pegarlo) y pulsa Intro: " > /dev/tty
    IFS= read -rs TOKEN < /dev/tty; echo > /dev/tty
    TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]')"
  fi
  set +e; check_token "$TOKEN"; rc=$?; set -e
  if [[ $rc -eq 0 ]]; then break; fi
  if [[ $rc -eq 2 ]]; then echo "ERROR: no hay conexión con GitHub" >&2; exit 1; fi
  TOKEN=""
  if [[ $intento -eq 3 ]]; then echo "ERROR: ningún token válido; pide uno al profesor" >&2; exit 1; fi
done
echo ">> token comprobado: acceso a $REPO"
( umask 077; mkdir -p "$CRED"; printf '%s\n' "$TOKEN" > "$TOKFILE" )
chmod 700 "$CRED"; chmod 600 "$TOKFILE"
cat > "$HELPER" <<'HLP'
#!/bin/sh
# Ayudante de credenciales de git de SCHISMlab: entrega el token guardado (solo en el clon de SCHISMlab).
test "$1" = get || exit 0
tok="$(cat "$(dirname "$0")/github_token" 2>/dev/null)"
test -n "$tok" || exit 0
echo username=x-access-token
echo "password=$tok"
HLP
chmod 700 "$HELPER"

# 2. clon ---------------------------------------------------------------------------
if [[ -d "$DEST/.git" ]]; then
  echo ">> ya hay un clon en $DEST: se actualiza"
else
  echo ">> descargando SCHISMlab en $DEST"
  git -c "$KEY=" -c "$KEY=$HELPER" clone -q "$GIT_URL" "$DEST"
fi
git -C "$DEST" config --local --unset-all "$KEY" 2>/dev/null || true
git -C "$DEST" config --local --add "$KEY" ""
git -C "$DEST" config --local --add "$KEY" "$HELPER"
[[ -d "$DEST/.git" ]] && git -C "$DEST" pull -q --ff-only || true

# 3. SCHISMlab Pro, si el token también da acceso (un solo token para las dos partes) ------------------
# Se clona donde lo dejaría Instalación → SCHISMlab Pro (schismlab/activate.py), antes del instalador: así este ya
# instala lo de Pro (modelos de oleaje, costa OSM) en la misma pasada.
PRO_REPO="${SCHISMLAB_PRO_REPO:-DrAmores/SCHISMlab-Pro}"
PRO_URL="${SCHISMLAB_PRO_GIT_URL:-https://github.com/$PRO_REPO.git}"
PRO_HOME="${SCHISMLAB_PRO_HOME:-$HOME/.schismlab/pro}"
PRO_TOK="${SCHISMLAB_PRO_TOKEN_FILE:-$CRED/pro_token}"
set +e; check_token "$TOKEN" "$PRO_REPO" 2>/dev/null; prc=$?; set -e
if [[ $prc -eq 0 ]]; then
  if [[ -d "$PRO_HOME/.git" ]]; then
    echo ">> el token también da acceso a SCHISMlab Pro: se actualiza $PRO_HOME"
    git -c "$KEY=" -c "$KEY=$HELPER" -C "$PRO_HOME" pull -q --ff-only || true
  else
    echo ">> el token también da acceso a SCHISMlab Pro: descargando en $PRO_HOME"
    rm -rf "$PRO_HOME.tmp"; mkdir -p "$(dirname "$PRO_HOME")"
    git -c "$KEY=" -c "$KEY=$HELPER" clone -q --depth 1 "$PRO_URL" "$PRO_HOME.tmp"
    rm -rf "$PRO_HOME"; mv "$PRO_HOME.tmp" "$PRO_HOME"
  fi
  git -C "$PRO_HOME" config --local --unset-all "$KEY" 2>/dev/null || true
  git -C "$PRO_HOME" config --local --add "$KEY" ""
  git -C "$PRO_HOME" config --local --add "$KEY" "$HELPER"
  ( umask 077; printf '%s\n' "$TOKEN" > "$PRO_TOK" ); chmod 600 "$PRO_TOK"
  EDICION="SCHISMlab Pro"
else
  EDICION="SCHISMlab Lite"
  echo ">> el token es de SCHISMlab Lite (para Pro hace falta un token que incluya también $PRO_REPO)"
fi

# 4. instalador de SCHISMlab (pixi, entorno, SCHISM, prueba) ----------------------------
cd "$DEST"
if [[ -n "${SCHISMLAB_SOLO_DESCARGAR:-}" ]]; then echo "== $EDICION descargado en $DEST (sin instalar)"; exit 0; fi
echo ">> instalando $EDICION: entorno, SCHISM y prueba (la primera vez, 10-30 minutos; no cierres esta ventana)"
exec bash install/install.sh "$VARIANT"
