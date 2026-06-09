#!/bin/sh
set -e

ACTION="$1"
VERSION="$2"

if [ -z "$ACTION" ] || [ -z "$VERSION" ]; then
  echo "usage: provision.sh <upsert|delete> <version>" >&2
  exit 1
fi

if [ -z "$JSON_INPUT" ]; then
  echo "JSON_INPUT environment variable is required" >&2
  exit 1
fi

os=linux
case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  CYGWIN* | MINGW* | MSYS*) os=windows ;;
esac

base_url="https://github.com/KaribuLab/terraform-aws-parameter-upsert/releases/download/${VERSION}"

case "$os" in
  linux)
    archive="ssm-parameter-linux-amd64-${VERSION}.tar.gz"
    curl -fsSL "${base_url}/ssm-parameter-linux-amd64.tar.gz" -o "$archive"
    tar -xzf "$archive"
    mv -f ssm-parameter-linux-amd64 ssm-parameter
    bin="./ssm-parameter"
    ;;
  darwin)
    archive="ssm-parameter-darwin-arm64-${VERSION}.tar.gz"
    curl -fsSL "${base_url}/ssm-parameter-darwin-arm64.tar.gz" -o "$archive"
    tar -xzf "$archive"
    mv -f ssm-parameter-darwin-arm64 ssm-parameter
    bin="./ssm-parameter"
    ;;
  windows)
    archive="ssm-parameter-windows-amd64-${VERSION}.zip"
    curl -fsSL "${base_url}/ssm-parameter-windows-amd64.zip" -o "$archive"
    unzip -o -q "$archive"
    mv -f ssm-parameter-windows-amd64.exe ssm-parameter.exe
    bin="./ssm-parameter.exe"
    ;;
esac

printf '%s' "$JSON_INPUT" > input.json

case "$ACTION" in
  upsert) "$bin" -input-path input.json ;;
  delete) "$bin" -input-path input.json -delete ;;
  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
