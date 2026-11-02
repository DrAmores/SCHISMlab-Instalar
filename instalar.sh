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
# SCHISMLAB_REPO (propietario/nombre, DrAmores/SCHISMlab-Lite), SCHISMLAB_SOLO_DESCARGAR=1 (clonar sin instalar).
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

# 0. git y curl ---------------------------------------------------------------------
# en macOS, /usr/bin/git existe aunque falten las Command Line Tools (solo abre un diálogo): se comprueban ellas
if [[ "$(uname -s)" == "Darwin" ]] && ! xcode-select -p >/dev/null 2>&1; then
  echo ">> faltan las Command Line Tools de Xcode: se abre el diálogo para instalarlas."
  echo "   Cuando terminen, vuelve a ejecutar este instalador."
  xcode-select --install || true; exit 1
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
check_token() {   # 0: acceso; 1: sin acceso o caducado; 2: sin conexión
  local code
  code=$(printf 'header = "Authorization: Bearer %s"\n' "$1" |
         curl -sS -K - -o /dev/null -w '%{http_code}' -H "User-Agent: SCHISMlab" -H "Accept: application/vnd.github+json" \
              "$API/repos/$REPO" 2>/dev/null) || return 2
  case "$code" in
    200) return 0 ;;
    401) echo "   el token no es válido o ha caducado" >&2; return 1 ;;
    403|404) echo "   el token no da acceso a $REPO" >&2; return 1 ;;
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

# 3. instalador de SCHISMlab (pixi, entorno, SCHISM, prueba) ----------------------------
cd "$DEST"
if [[ -n "${SCHISMLAB_SOLO_DESCARGAR:-}" ]]; then echo "== SCHISMlab descargado en $DEST (sin instalar)"; exit 0; fi
exec bash install/install.sh "$VARIANT"
