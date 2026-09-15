#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output="$("$SCRIPT_DIR"/../src/*.sh)"
[[ -n "$output" ]] && echo "ok"
