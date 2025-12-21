#!/bin/bash
# Auto hot reload for Flutter using entr
# Usage: ./scripts/watch.sh [device]
# Devices: chrome (default), macos, ios, android

set -e

DEVICE="${1:-chrome}"
PID_FILE="/tmp/flutter-admin-$$.pid"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/apps/admin"

# Check for entr
if ! command -v entr &> /dev/null; then
    echo "Error: entr not found. Install with: brew install entr"
    exit 1
fi

cleanup() {
    echo ""
    echo "Stopping watcher..."
    [ -n "$WATCHER_PID" ] && kill $WATCHER_PID 2>/dev/null
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup INT TERM

echo "Starting Flutter with auto hot reload..."
echo "Device: $DEVICE"
echo "Watching: apps/, packages/"
echo ""

# Watcher in background
(
    sleep 5  # Wait for Flutter to start
    echo "[watcher] Watching for .dart changes..."

    while true; do
        # Find all dart files in apps and packages
        find "$PROJECT_ROOT/apps" "$PROJECT_ROOT/packages" \
            -name '*.dart' \
            -not -path '*/.dart_tool/*' \
            -not -path '*/build/*' \
            -not -name '*.g.dart' \
            -not -name '*.freezed.dart' \
            2>/dev/null | \
        entr -d -p sh -c "
            PID=\$(cat \"$PID_FILE\" 2>/dev/null)
            if [ -n \"\$PID\" ] && kill -0 \$PID 2>/dev/null; then
                echo '[watcher] Change detected, hot reloading...'
                kill -USR1 \$PID
            fi
        " 2>/dev/null || true

        # entr exits with -d when new files are added, restart watching
        sleep 0.5
    done
) &
WATCHER_PID=$!

# Flutter in foreground (interactive)
cd "$APP_DIR"
flutter run -d "$DEVICE" --web-port=8082 --pid-file "$PID_FILE"

cleanup
