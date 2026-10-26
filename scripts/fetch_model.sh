#!/bin/sh
# Downloads the on-device models that ship inside the app (not stored in git):
#   - Gemma 3 1B for the talking buddy (806 MB)
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

fetch "Models/gemma-3-1b-it-Q4_K_M.gguf" \
    "https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf" \
    "8270790f3ab69fdfe860b7b64008d9a19986d8df7e407bb018184caa08798ebd" \
    "Gemma 3 1B (806 MB)"

fetch "Models/kokoro-82m-q8.onnx" \
    "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/onnx/model_quantized.onnx" \
    "fbae9257e1e05ffc727e951ef9b9c98418e6d79f1c9b6b13bd59f5c9028a1478" \
    "Kokoro-82M voice (92 MB)"
