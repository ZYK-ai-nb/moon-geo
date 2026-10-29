#!/usr/bin/env bash
# Uses Python stdlib; compatible with the minimal Git-for-Windows shell.
set -euo pipefail
script_dir="${BASH_SOURCE[0]%/*}"
if [[ "$script_dir" == "${BASH_SOURCE[0]}" ]]; then script_dir="."; fi
exec python "$script_dir/rebind.py" "$@"
