#!/bin/sh
set -e

ACTION="$1"
VERSION="$2"

if [ -z "$ACTION" ] || [ -z "$VERSION" ]; then
  echo "usage: provision.sh <upsert|delete> <version> [bin_dir]" >&2
  exit 1
fi

if [ -z "$JSON_INPUT" ]; then
  echo "JSON_INPUT environment variable is required" >&2
  exit 1
fi

# Detectar SO y arquitectura del host que ejecuta el script. Mantenemos el
# mismo mapa que main.tf usa en sus locals (bin_dir_linux/darwin/windows) para
# que CREATE y DESTROY operen sobre el mismo bin_dir sin tener que pasarlo
# desde Terraform (local.* no es valido en destroy provisioners).
os=linux
case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  CYGWIN* | MINGW* | MSYS*) os=windows ;;
esac

case "$os" in
  darwin)  arch=arm64 ;;  # solo publicamos darwin-arm64
  windows) arch=amd64 ;;
  linux)   arch=amd64 ;;
esac

# Default: misma convencion que main.tf. Se puede sobreescribir pasando el
# 3er argumento (util si el caller quiere un path distinto).
default_bin_dir="bin/${VERSION}/ssm_parameter_${os}_${arch}"
BIN_DIR="${3:-$default_bin_dir}"

base_url="https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${VERSION}"

# Cada invocacion opera dentro de su propio bin_dir para evitar la carrera
# cuando varios modulos o workspaces destruyen en paralelo.
mkdir -p "$BIN_DIR"

case "$os" in
  linux)
    archive="$BIN_DIR/ssm-parameter-linux-amd64-${VERSION}.tar.gz"
    curl -fsSL "${base_url}/ssm-parameter-linux-amd64.tar.gz" -o "$archive"
    tar -xzf "$archive" -C "$BIN_DIR"
    mv -f "$BIN_DIR/ssm-parameter-linux-amd64" "$BIN_DIR/ssm-parameter"
    bin="$BIN_DIR/ssm-parameter"
    ;;
  darwin)
    archive="$BIN_DIR/ssm-parameter-darwin-arm64-${VERSION}.tar.gz"
    curl -fsSL "${base_url}/ssm-parameter-darwin-arm64.tar.gz" -o "$archive"
    tar -xzf "$archive" -C "$BIN_DIR"
    mv -f "$BIN_DIR/ssm-parameter-darwin-arm64" "$BIN_DIR/ssm-parameter"
    bin="$BIN_DIR/ssm-parameter"
    ;;
  windows)
    archive="$BIN_DIR/ssm-parameter-windows-amd64-${VERSION}.zip"
    curl -fsSL "${base_url}/ssm-parameter-windows-amd64.zip" -o "$archive"
    unzip -o -q "$archive" -d "$BIN_DIR"
    mv -f "$BIN_DIR/ssm-parameter-windows-amd64.exe" "$BIN_DIR/ssm-parameter.exe"
    bin="$BIN_DIR/ssm-parameter.exe"
    ;;
esac

printf '%s' "$JSON_INPUT" > "$BIN_DIR/input.json"

case "$ACTION" in
  upsert) "$bin" -input-path "$BIN_DIR/input.json" ;;
  delete) "$bin" -input-path "$BIN_DIR/input.json" -delete ;;
  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac