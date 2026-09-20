#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN_FILE="$ROOT/Native/DiffSidecar/rust-toolchain.toml"
TOOLCHAIN="$(awk -F '"' '/^[[:space:]]*channel[[:space:]]*=/{print $2; exit}' "$TOOLCHAIN_FILE")"
# Fork-local: CMUX_DIFF_SIDECAR_TOOLCHAIN overrides the pin. Rust 1.88 emits
# proc-macro dylibs that macOS 27's dyld rejects ("mis-aligned LINKEDIT string
# pool") when MACOSX_DEPLOYMENT_TARGET=14.0, so Release builds here use stable.
TOOLCHAIN="${CMUX_DIFF_SIDECAR_TOOLCHAIN:-$TOOLCHAIN}"

if [[ -z "$TOOLCHAIN" ]]; then
  echo "error: missing Rust channel in $TOOLCHAIN_FILE" >&2
  exit 1
fi
if ! command -v rustup >/dev/null 2>&1; then
  echo "error: rustup is required for the pinned Rust $TOOLCHAIN toolchain" >&2
  exit 1
fi

exec rustup run "$TOOLCHAIN" cargo "$@"
