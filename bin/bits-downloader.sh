#!/usr/bin/env bash

# Legacy entrypoint kept for compatibility.
# Forward to the new dialog-based manager.

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$BIN_DIR/bits-manager.sh" "$@"
