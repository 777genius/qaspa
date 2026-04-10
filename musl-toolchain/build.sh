#!/bin/bash
set -euo pipefail

UPSTREAM_REPO="kaspanet/rusty-kaspa"
TOOLCHAIN_TAG="musl-toolchain-v1"

# Calculate the hash of the preset file
CURRENT_PRESET_HASH=$(sha256sum $GITHUB_WORKSPACE/musl-toolchain/preset.sh | awk '{print $1}')
PRESET_HASH_FILE="$HOME/x-tools/preset_hash"

echo "Current preset hash: $CURRENT_PRESET_HASH"

# Traverse to working directory
cd $GITHUB_WORKSPACE/musl-toolchain

# Set the preset
source preset.sh

# Check if the toolchain is already installed and up-to-date
if [ -d "$HOME/x-tools" ] && [ -f "$PRESET_HASH_FILE" ] && [ "$(cat $PRESET_HASH_FILE)" = "$CURRENT_PRESET_HASH" ]; then
  echo "Toolchain already installed and up-to-date, skipping"
else
  rm -rf "$HOME/x-tools"
  TOOLCHAIN_INSTALLED=false

  # Try downloading and verifying from a repo. Cleans up on hash mismatch.
  try_download_toolchain() {
    local repo="$1"
    echo "Trying to download toolchain from $repo..."

    local download_url="https://github.com/$repo/releases/download/$TOOLCHAIN_TAG/x-tools.tar.zst"
    if ! curl -fsSL -o /tmp/x-tools.tar.zst "$download_url"; then
      echo "  No release found in $repo"
      rm -f /tmp/x-tools.tar.zst
      return 1
    fi

    echo "  Extracting..."
    tar --use-compress-program=zstd -xf /tmp/x-tools.tar.zst -C "$HOME"
    rm -f /tmp/x-tools.tar.zst

    if [ -f "$PRESET_HASH_FILE" ] && [ "$(cat "$PRESET_HASH_FILE")" = "$CURRENT_PRESET_HASH" ]; then
      echo "  Preset hash matches, toolchain ready"
      return 0
    fi

    echo "  Preset hash mismatch (expected: $CURRENT_PRESET_HASH, got: $(cat "$PRESET_HASH_FILE" 2>/dev/null || echo 'missing'))"
    rm -rf "$HOME/x-tools"
    return 1
  }

  # Try upstream first, then fall back to the current repo (for fork-based toolchain testing)
  if try_download_toolchain "$UPSTREAM_REPO"; then
    TOOLCHAIN_INSTALLED=true
  elif [ "$GITHUB_REPOSITORY" != "$UPSTREAM_REPO" ] && try_download_toolchain "$GITHUB_REPOSITORY"; then
    TOOLCHAIN_INSTALLED=true
  fi

  if [ "$TOOLCHAIN_INSTALLED" != "true" ]; then
    echo "ERROR: Could not download a matching toolchain from $UPSTREAM_REPO or $GITHUB_REPOSITORY"
    echo "Run the 'Build musl toolchain' workflow to create/update the release."
    exit 1
  fi
fi

# Update toolchain variables: C compiler, C++ compiler, linker, and archiver
export CC=$HOME/x-tools/$CTNG_PRESET/bin/$CTNG_PRESET-gcc
export CXX=$HOME/x-tools/$CTNG_PRESET/bin/$CTNG_PRESET-g++
export LD=$HOME/x-tools/$CTNG_PRESET/bin/$CTNG_PRESET-ld
export AR=$HOME/x-tools/$CTNG_PRESET/bin/$CTNG_PRESET-ar

# Exports for cc crate
# https://docs.rs/cc/latest/cc/#external-configuration-via-environment-variables
export RANLIB_x86_64_unknown_linux_musl=$HOME/x-tools/$CTNG_PRESET/bin/$CTNG_PRESET-ranlib
export CC_x86_64_unknown_linux_musl=$CC
export CXX_x86_64_unknown_linux_musl=$CXX
export AR_x86_64_unknown_linux_musl=$AR
export LD_x86_64_unknown_linux_musl=$LD

# Build OpenSSL for musl target
OPENSSL_VERSION="3.2.1"
OPENSSL_DIR="$HOME/openssl-musl"

if [ ! -d "$OPENSSL_DIR" ]; then
  echo "Building OpenSSL $OPENSSL_VERSION for musl..."

  # Ensure curl is available
  sudo apt-get install -y curl

  cd /tmp
  curl -LO "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
  tar xzf "openssl-${OPENSSL_VERSION}.tar.gz"
  cd "openssl-${OPENSSL_VERSION}"

  # Configure OpenSSL for musl cross-compilation
  ./Configure linux-x86_64 \
    --prefix="$OPENSSL_DIR" \
    --openssldir="$OPENSSL_DIR" \
    no-shared \
    no-async \
    CC="$CC" \
    AR="$AR" \
    RANLIB="$HOME/x-tools/$CTNG_PRESET/bin/$CTNG_PRESET-ranlib"

  make -j$(nproc)
  make install_sw

  echo "OpenSSL built successfully at $OPENSSL_DIR"
  cd $GITHUB_WORKSPACE/musl-toolchain
fi

# Determine OpenSSL lib directory (lib or lib64)
if [ -d "$OPENSSL_DIR/lib64" ]; then
  OPENSSL_LIB_PATH="$OPENSSL_DIR/lib64"
else
  OPENSSL_LIB_PATH="$OPENSSL_DIR/lib"
fi

# Set OpenSSL environment variables for Rust
export OPENSSL_DIR="$OPENSSL_DIR"
export OPENSSL_LIB_DIR="$OPENSSL_LIB_PATH"
export OPENSSL_INCLUDE_DIR="$OPENSSL_DIR/include"
export OPENSSL_STATIC=true

# Also set for the specific target
export X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_DIR="$OPENSSL_DIR"
export X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_LIB_DIR="$OPENSSL_LIB_PATH"
export X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_INCLUDE_DIR="$OPENSSL_DIR/include"
export X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_STATIC=1

# Set environment variables for static linking
export RUSTFLAGS="-C link-arg=-static"

# We specify the compiler that will invoke linker
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=$CC

# Add target
rustup target add x86_64-unknown-linux-musl

# Install missing dependencies
cargo fetch --target x86_64-unknown-linux-musl
