#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$TEMP_DIR/cache" "$ROOT/MyApp/WatchPurchaseAccess.swift" "$ROOT/Tests/WatchPurchaseRegression/Main.swift" -o "$TEMP_DIR/regressions"
"$TEMP_DIR/regressions"
cmp "$ROOT/MyApp/WatchPurchaseAccess.swift" "$ROOT/WatchApp/WatchPurchaseAccess.swift"
cmp "$ROOT/MyApp/WatchPurchaseView.swift" "$ROOT/WatchApp/WatchPurchaseView.swift"
