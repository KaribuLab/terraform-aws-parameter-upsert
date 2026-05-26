#!/bin/sh
set -e

os=linux
case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  CYGWIN* | MINGW* | MSYS*) os=windows ;;
esac

printf '{"os":"%s"}' "$os"
