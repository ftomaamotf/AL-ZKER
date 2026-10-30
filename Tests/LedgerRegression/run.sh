#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
xcrun swiftc -module-cache-path "$TEMP_DIR/cache" "$ROOT/MyApp/1_ZekrModel.swift" "$ROOT/MyApp/DhikrLedger.swift" "$ROOT/Tests/LedgerRegression/main.swift" -o "$TEMP_DIR/regressions"
"$TEMP_DIR/regressions"
cmp "$ROOT/MyApp/DhikrLedger.swift" "$ROOT/WatchApp/DhikrLedger.swift"
