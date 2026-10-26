#!/bin/sh
# Downloads the on-device Gemma model that ships inside the app (not stored in git).
# The app works without it, but the word assistant needs it.
set -eu
cd "$(dirname "$0")/.."
FILE="Models/gemma-3-1b-it-Q4_K_M.gguf"
URL="https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf"
SHA256="8270790f3ab69fdfe860b7b64008d9a19986d8df7e407bb018184caa08798ebd"

mkdir -p Models
if [ -f "$FILE" ] && echo "$SHA256  $FILE" | shasum -a 256 -c - >/dev/null 2>&1; then
    echo "Model already present: $FILE"
    exit 0
fi
echo "Downloading Gemma 3 1B (806 MB)..."
curl -L --fail --retry 3 -C - -o "$FILE.part" "$URL"
echo "$SHA256  $FILE.part" | shasum -a 256 -c -
mv "$FILE.part" "$FILE"
echo "Saved $FILE"
