#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

run()  { echo "==> $*"; "$@"; }
have() { command -v "$1" >/dev/null 2>&1 || { echo "--- skipping: $1 not installed"; return 1; }; }

have omarchy          && run omarchy plugin validate .
have glslangValidator && run glslangValidator -S frag shaders/grayscale.glsl
have node             && run node --test tests/*.test.mjs
echo "All checks passed."
