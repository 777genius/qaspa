/// FFI/WASM bridge to kaspa-wallet-core Rust library.
///
/// This package provides a platform-abstracted interface to the Kaspa wallet
/// Rust core. On native platforms (Mobile/Desktop), it uses flutter_rust_bridge
/// for FFI. On web platforms (Web/Extension), it uses WASM.
library wallet_rust_bridge;

export 'src/wallet_bridge.dart';
export 'src/wallet_config.dart';
export 'src/bridge_version.dart';
export 'src/events/wallet_events.dart';
