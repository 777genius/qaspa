import 'wallet_bridge.dart';

/// Version information and compatibility checking for the bridge.
class BridgeVersion {
  /// Bridge major version
  static const int major = 1;

  /// Bridge minor version
  static const int minor = 0;

  /// Bridge patch version
  static const int patch = 0;

  /// Minimum compatible Rust core version
  static const String minRustVersion = '1.0.0';

  /// Full version string
  static String get version => '$major.$minor.$patch';

  /// Check if the Rust core version is compatible
  static Future<void> checkCompatibility() async {
    final bridge = WalletBridge.instance;
    final rustVersion = await bridge.getRustVersion();

    if (!_isCompatible(rustVersion)) {
      throw IncompatibleVersionException(
        dartVersion: version,
        rustVersion: rustVersion,
      );
    }
  }

  static bool _isCompatible(String rustVersion) {
    final rustParts = rustVersion.split('.').map(int.tryParse).toList();
    final minParts = minRustVersion.split('.').map(int.tryParse).toList();

    if (rustParts.length < 3 || minParts.length < 3) return false;

    final rustMajor = rustParts[0] ?? 0;
    final rustMinor = rustParts[1] ?? 0;
    final minMajor = minParts[0] ?? 0;
    final minMinor = minParts[1] ?? 0;

    if (rustMajor > minMajor) return true;
    if (rustMajor < minMajor) return false;
    return rustMinor >= minMinor;
  }
}

/// Exception thrown when Dart and Rust versions are incompatible.
class IncompatibleVersionException implements Exception {
  final String dartVersion;
  final String rustVersion;

  const IncompatibleVersionException({
    required this.dartVersion,
    required this.rustVersion,
  });

  @override
  String toString() =>
      'Incompatible versions: Dart bridge $dartVersion, Rust core $rustVersion';
}
