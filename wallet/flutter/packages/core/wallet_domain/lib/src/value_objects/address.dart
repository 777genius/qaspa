import 'package:equatable/equatable.dart';

import '../errors/wallet_exception.dart';
import 'network_id.dart';

/// Address type enumeration.
enum AddressType {
  /// Pay-to-Public-Key (P2PK) - Schnorr signature
  p2pk,

  /// Pay-to-Public-Key-ECDSA
  p2pkEcdsa,

  /// Pay-to-Script-Hash (P2SH)
  p2sh,
}

/// Kaspa address value object.
/// Validates address format including bech32 checksum and extracts network/type information.
class Address extends Equatable {
  final String value;
  final NetworkId networkId;
  final AddressType type;

  const Address._({
    required this.value,
    required this.networkId,
    required this.type,
  });

  /// Valid Kaspa address prefixes
  static const validPrefixes = ['kaspa', 'kaspatest', 'kaspadev', 'kaspasim'];

  /// Bech32 character set
  static const _bech32Charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  /// Minimum payload length for a valid Kaspa address
  /// - Version byte: 1 character
  /// - Public key (32 bytes): ~52 characters in bech32
  /// - Checksum: 8 characters (bech32m)
  /// Total: ~61 characters minimum
  static const _minPayloadLength = 61;

  /// Create and validate address from string
  factory Address.fromString(String address) {
    final lower = address.toLowerCase();

    // 1. Validate prefix
    final NetworkId network;
    final String prefix;
    final String payload;

    if (lower.startsWith('kaspa:')) {
      network = NetworkId.mainnet;
      prefix = 'kaspa';
      payload = lower.substring(6);
    } else if (lower.startsWith('kaspatest:')) {
      network = NetworkId.testnet10;
      prefix = 'kaspatest';
      payload = lower.substring(10);
    } else if (lower.startsWith('kaspadev:')) {
      network = NetworkId.devnet;
      prefix = 'kaspadev';
      payload = lower.substring(9);
    } else if (lower.startsWith('kaspasim:')) {
      network = NetworkId.simnet;
      prefix = 'kaspasim';
      payload = lower.substring(9);
    } else {
      final actualPrefix = lower.contains(':')
          ? lower.split(':').first
          : 'unknown';
      throw InvalidAddressException.invalidPrefix(address, actualPrefix);
    }

    // 2. Validate payload is not empty
    if (payload.isEmpty) {
      throw InvalidAddressException(
        message: 'Empty address payload',
        address: address,
        reason: 'Payload cannot be empty',
      );
    }

    // 3. Validate minimum payload length
    if (payload.length < _minPayloadLength) {
      throw InvalidAddressException(
        message: 'Address payload too short',
        address: address,
        reason: 'Payload must be at least $_minPayloadLength characters, '
            'got ${payload.length}',
      );
    }

    // 4. Validate bech32 characters
    if (!_isValidBech32Chars(payload)) {
      throw InvalidAddressException(
        message: 'Invalid bech32 characters in address',
        address: address,
        reason: 'Contains invalid characters',
      );
    }

    // 5. Validate bech32 checksum
    if (!_verifyBech32Checksum(prefix, payload)) {
      throw InvalidAddressException.invalidChecksum(address);
    }

    // 6. Determine type from payload version byte
    final type = _detectAddressType(payload);

    return Address._(
      value: address,
      networkId: network,
      type: type,
    );
  }

  /// Create address without validation (for trusted sources like Rust)
  factory Address.trusted(String address, NetworkId network, AddressType type) {
    return Address._(
      value: address,
      networkId: network,
      type: type,
    );
  }

  /// Validate bech32 characters
  static bool _isValidBech32Chars(String payload) {
    for (final char in payload.split('')) {
      if (!_bech32Charset.contains(char)) {
        return false;
      }
    }
    return true;
  }

  /// Decode bech32 character to 5-bit value
  static int _bech32CharToValue(String char) {
    return _bech32Charset.indexOf(char);
  }

  /// Expand prefix for checksum calculation
  static List<int> _expandPrefix(String prefix) {
    final result = <int>[];
    for (final char in prefix.split('')) {
      result.add(char.codeUnitAt(0) >> 5);
    }
    result.add(0);
    for (final char in prefix.split('')) {
      result.add(char.codeUnitAt(0) & 31);
    }
    return result;
  }

  /// Bech32 polymod function
  static int _polymod(List<int> values) {
    const generator = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    var chk = 1;
    for (final v in values) {
      final top = chk >> 25;
      chk = (chk & 0x1ffffff) << 5 ^ v;
      for (var i = 0; i < 5; i++) {
        if (((top >> i) & 1) != 0) {
          chk ^= generator[i];
        }
      }
    }
    return chk;
  }

  /// Verify bech32 checksum
  static bool _verifyBech32Checksum(String prefix, String payload) {
    final data = <int>[];
    data.addAll(_expandPrefix(prefix));
    for (final char in payload.split('')) {
      data.add(_bech32CharToValue(char));
    }
    return _polymod(data) == 1;
  }

  /// Detect address type from payload version byte
  static AddressType _detectAddressType(String payload) {
    if (payload.isEmpty) {
      throw InvalidAddressException.unknownType('');
    }

    // Kaspa address types based on version byte:
    // 'q' prefix (version 0) = P2PK (Schnorr)
    // 'p' prefix = P2SH
    // Other prefixes need proper mapping from Kaspa spec

    final firstChar = payload[0];
    switch (firstChar) {
      case 'q':
        // Version 0 - P2PK Schnorr (32-byte pubkey)
        return AddressType.p2pk;
      case 'p':
        // P2SH
        return AddressType.p2sh;
      case 'r':
      case 's':
      case 't':
        // ECDSA variants
        return AddressType.p2pkEcdsa;
      default:
        // Do NOT fallback - throw for unknown types
        throw InvalidAddressException.unknownType(payload);
    }
  }

  /// Whether this is a mainnet address
  bool get isMainnet => networkId.isMainnet;

  /// Whether this is a testnet address
  bool get isTestnet => networkId.isTestnet;

  /// Get shortened display address
  String get short {
    final prefixPart = value.split(':').first;
    final payloadPart = value.split(':').last;
    if (payloadPart.length <= 16) return value;
    return '$prefixPart:${payloadPart.substring(0, 8)}...${payloadPart.substring(payloadPart.length - 8)}';
  }

  /// Get address without prefix
  String get payload => value.split(':').last;

  /// Get prefix only
  String get prefix => value.split(':').first;

  @override
  String toString() => value;

  @override
  List<Object?> get props => [value];
}
