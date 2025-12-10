import 'package:wallet_domain/wallet_domain.dart';

/// Storage backend options.
enum StorageBackend {
  /// Native file system storage
  native,

  /// IndexedDB (Web)
  indexedDb,

  /// Chrome extension storage
  chromeStorage,
}

/// Configuration for wallet bridge initialization.
class WalletConfig {
  /// WebSocket URL for Kaspa node
  final String nodeUrl;

  /// Network ID (mainnet/testnet)
  final NetworkId networkId;

  /// Storage path for wallet data (null for web)
  final String? storagePath;

  /// Storage backend to use
  final StorageBackend storageBackend;

  /// Enable debug logging
  final bool debugLogging;

  const WalletConfig({
    required this.nodeUrl,
    required this.networkId,
    this.storagePath,
    this.storageBackend = StorageBackend.native,
    this.debugLogging = false,
  });

  /// Default mainnet configuration
  factory WalletConfig.mainnet({
    String nodeUrl = 'wss://mainnet.kaspa.org',
    String? storagePath,
  }) {
    return WalletConfig(
      nodeUrl: nodeUrl,
      networkId: NetworkId.mainnet,
      storagePath: storagePath,
    );
  }

  /// Default testnet configuration
  factory WalletConfig.testnet({
    String nodeUrl = 'wss://testnet-10.kaspa.org',
    String? storagePath,
  }) {
    return WalletConfig(
      nodeUrl: nodeUrl,
      networkId: NetworkId.testnet10,
      storagePath: storagePath,
    );
  }
}
