#!/bin/bash

PRESET_HASH_FILE="$HOME/x-tools/preset_hash"

# Calculate the hash of the preset file
CURRENT_PRESET_HASH=$(sha256sum $GITHUB_WORKSPACE/musl-toolchain/preset.sh | awk '{print $1}')

echo "Current preset hash: $CURRENT_PRESET_HASH"

# Traverse to working directory
cd $GITHUB_WORKSPACE/musl-toolchain

# Set the preset
source preset.sh

# If the toolchain is not installed or the preset has changed or the preset hash file does not exist
if [ ! -d "$HOME/x-tools" ] || [ ! -f "$PRESET_HASH_FILE" ] || [ "$(cat $PRESET_HASH_FILE)" != "$CURRENT_PRESET_HASH" ]; then
  # Install dependencies
  sudo apt-get update
  sudo apt-get install -y autoconf automake libtool  libtool-bin unzip help2man python3-dev gperf bison flex texinfo gawk libncurses5-dev
  
  # Clone crosstool-ng
  git clone https://github.com/crosstool-ng/crosstool-ng
  
  # Configure and build crosstool-ng
  cd crosstool-ng
  # Use version 1.26
  git checkout crosstool-ng-1.26.0
  ./bootstrap
  ./configure --prefix=$HOME/ctng
  make
  make install
  # Add crosstool-ng to PATH
  export PATH=$HOME/ctng/bin:$PATH

 

  # Load toolchainc configuration
  ct-ng $CTNG_PRESET
  
  # Build the toolchain
  ct-ng build > build.log 2>&1
  
  # Set status to the exit code of the build
  status=$?
  
  # We store the log in a file because it bloats the screen too much
  # on GitHub Actions. We print it only if the build fails.
  echo "Build result:"
  if [ $status -eq 0 ]; then
    echo "Build succeeded"
    ls -la $HOME/x-tools
    # Store the current hash of preset.sh after successful build
    echo "$CURRENT_PRESET_HASH" > "$PRESET_HASH_FILE"    
  else
    echo "Build failed, here's the log:"
    cat .config
    cat build.log
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