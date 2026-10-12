#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

run()  { echo "==> $*"; "$@"; }
have() { command -v "$1" >/dev/null 2>&1 || { echo "--- skipping: $1 not installed"; return 1; }; }

have omarchy          && run omarchy plugin validate .
if have glslangValidator; then
  for f in shaders/*.glsl; do run glslangValidator -S frag "$f"; done
fi

have node             && run node --test tests/*.test.mjs
echo "All checks passed."
