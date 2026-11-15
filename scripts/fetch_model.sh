#!/bin/sh
# Downloads the on-device models that ship inside the app (not stored in git):
#   - Qwen 2.5 1.5B Instruct for the talking buddy (1.1 GB, Apache-2.0), strong in English and Chinese
#   - Kokoro-82M, the natural reading voice (92 MB, Apache-2.0)
# The app works without them (falling back to simpler features), but ships with both.
set -eu
cd "$(dirname "$0")/.."
mkdir -p Models

fetch() {
    file="$1"; url="$2"; sha256="$3"; label="$4"
    if [ -f "$file" ] && echo "$sha256  $file" | shasum -a 256 -c - >/dev/null 2>&1; then
        echo "Already present: $file"
        return
    fi
    echo "Downloading $label..."
    curl -L --fail --retry 3 -C - -o "$file.part" "$url"
    echo "$sha256  $file.part" | shasum -a 256 -c -
    mv "$file.part" "$file"
    echo "Saved $file"
}

fetch "Models/qwen2.5-1.5b-instruct-q4_k_m.gguf" \
    "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf" \
    "6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e" \
    "Qwen 2.5 1.5B Instruct (1.1 GB)"

fetch "Models/kokoro-82m-q8.onnx" \
    "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/onnx/model_quantized.onnx" \
    "fbae9257e1e05ffc727e951ef9b9c98418e6d79f1c9b6b13bd59f5c9028a1478" \
    "Kokoro-82M voice (92 MB)"
