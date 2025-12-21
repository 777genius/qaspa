#!/bin/bash

# Generate code for all packages in dependency order
PACKAGES=(
  "packages/core/admin_domain"
  "packages/core/admin_data"
  "packages/features/dashboard/dashboard_domain"
  "packages/features/dashboard/dashboard_presentation"
  "packages/features/nodes/nodes_domain"
  "packages/features/nodes/nodes_presentation"
  "packages/features/miners/miners_domain"
  "packages/features/miners/miners_presentation"
  "packages/features/logs/logs_domain"
  "packages/features/logs/logs_presentation"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Generating code for all packages ==="
echo "Root: $ROOT_DIR"

for pkg in "${PACKAGES[@]}"; do
  PKG_DIR="$ROOT_DIR/$pkg"
  if [ -d "$PKG_DIR" ]; then
    echo ""
    echo ">>> Processing $pkg"
    (cd "$PKG_DIR" && flutter pub get && dart run build_runner build --delete-conflicting-outputs) || echo "Warning: $pkg had errors"
  else
    echo "Warning: $pkg directory not found"
  fi
done

echo ""
echo "=== Generation complete ==="
