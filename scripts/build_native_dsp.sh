#!/usr/bin/env bash
set -euo pipefail

# Script de compilacion automatizada para libtunner_dsp
# Compila la biblioteca nativa en C99 con optimizaciones SIMD (-O3)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/native/dsp"
BUILD_DIR="$ROOT_DIR/build/native"

echo "[tunner_dsp] Configurando compilacion en: $BUILD_DIR"
mkdir -p "$BUILD_DIR"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --config Release

echo "[tunner_dsp] Compilacion finalizada exitosamente."

# Localizacion y copia de la biblioteca para resolucion en tiempo de ejecucion
if [[ -f "$BUILD_DIR/libtunner_dsp.so" ]]; then
    cp "$BUILD_DIR/libtunner_dsp.so" "$ROOT_DIR/libtunner_dsp.so"
    echo "[tunner_dsp] Biblioteca copiada a: $ROOT_DIR/libtunner_dsp.so"
elif [[ -f "$BUILD_DIR/libtunner_dsp.dylib" ]]; then
    cp "$BUILD_DIR/libtunner_dsp.dylib" "$ROOT_DIR/libtunner_dsp.dylib"
    echo "[tunner_dsp] Biblioteca copiada a: $ROOT_DIR/libtunner_dsp.dylib"
elif [[ -f "$BUILD_DIR/Release/tunner_dsp.dll" ]]; then
    cp "$BUILD_DIR/Release/tunner_dsp.dll" "$ROOT_DIR/tunner_dsp.dll"
    echo "[tunner_dsp] Biblioteca copiada a: $ROOT_DIR/tunner_dsp.dll"
elif [[ -f "$BUILD_DIR/tunner_dsp.dll" ]]; then
    cp "$BUILD_DIR/tunner_dsp.dll" "$ROOT_DIR/tunner_dsp.dll"
    echo "[tunner_dsp] Biblioteca copiada a: $ROOT_DIR/tunner_dsp.dll"
fi
