import 'package:equatable/equatable.dart';

import '../errors/wallet_exception.dart';
import 'network_id.dart';

/// Address type enumeration.
enum AddressType {
  /// Pay-to-Public-Key (P2PK) - Schnorr signature
  p2pk,

  /// Pay-to-Public-Key-ECDSA
  p2pkEcdsa,

  /// Pay-to-Public-Key-MLDSA (post-quantum)
  p2pkMldsa,

  /// Pay-to-Script-Hash (P2SH)
  p2sh,

  /// Stealth address (private payments)
  stealth,
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
  static const validPrefixes = [
    'kaspa',
    'kaspatest',
    'kaspadev',
    'kaspasim',
    'qs',
    'qstest',
  ];

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
    } else if (lower.startsWith('qs:')) {
      network = NetworkId.mainnet;
      prefix = 'qs';
      payload = lower.substring(3);
    } else if (lower.startsWith('qstest:')) {
      network = NetworkId.testnet10;
      prefix = 'qstest';
      payload = lower.substring(7);
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

    // 5. Validate checksum (Kaspa bech32 variant with 8-char checksum)
    if (!_verifyKaspaChecksum(prefix, payload)) {
      throw InvalidAddressException.invalidChecksum(address);
    }

    // 6. Determine type from decoded version byte and validate payload length
    final type = _detectAddressType(prefix, payload, address);

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

  // --------------------------------------------------------------------------
  // Kaspa address payload decoding (40-bit checksum, 8 chars)
  // Matches Rust implementation in `crypto/addresses/src/bech32.rs`.
  // --------------------------------------------------------------------------

  static const int _checksumLengthU5 = 8;

  static final BigInt _polyMask = BigInt.parse('0x07ffffffff');
  static final BigInt _gen0 = BigInt.parse('0x98f2bc8e61');
  static final BigInt _gen1 = BigInt.parse('0x79b76d99e2');
  static final BigInt _gen2 = BigInt.parse('0xf33e5fb3c4');
  static final BigInt _gen3 = BigInt.parse('0xae2eabe2a8');
  static final BigInt _gen4 = BigInt.parse('0x1e4f43e470');

  static List<int> _prefixToU5(String prefix) {
    // Same as Rust: prefix bytes masked to 5-bit values.
    return prefix.codeUnits.map((c) => c & 0x1f).toList(growable: false);
  }

  static BigInt _polymodKaspa(List<int> values) {
    var c = BigInt.one;
    for (final d in values) {
      final c0 = c >> 35;
      c = ((c & _polyMask) << 5) ^ BigInt.from(d);
      if ((c0 & BigInt.one) != BigInt.zero) c ^= _gen0;
      if ((c0 & BigInt.from(2)) != BigInt.zero) c ^= _gen1;
      if ((c0 & BigInt.from(4)) != BigInt.zero) c ^= _gen2;
      if ((c0 & BigInt.from(8)) != BigInt.zero) c ^= _gen3;
      if ((c0 & BigInt.from(16)) != BigInt.zero) c ^= _gen4;
    }
    return c ^ BigInt.one;
  }

  static List<int> _convert8to5(List<int> payload) {
    final padding = payload.length % 5 == 0 ? 0 : 1;
    final outLen = (payload.length * 8) ~/ 5 + padding;
    final out = List<int>.filled(outLen, 0);

    var currentIdx = 0;
    var buff = 0;
    var bits = 0;
    for (final c in payload) {
      buff = (buff << 8) | (c & 0xff);
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out[currentIdx] = (buff >> bits) & 0x1f;
        buff &= (1 << bits) - 1;
        currentIdx += 1;
      }
    }
    if (bits > 0 && currentIdx < out.length) {
      out[currentIdx] = (buff << (5 - bits)) & 0x1f;
    }
    return out;
  }

  static List<int> _convert5to8(List<int> payload) {
    final outLen = (payload.length * 5) ~/ 8;
    final out = List<int>.filled(outLen, 0);

    var currentIdx = 0;
    var buff = 0;
    var bits = 0;
    for (final c in payload) {
      buff = (buff << 5) | (c & 0x1f);
      bits += 5;
      while (bits >= 8) {
        bits -= 8;
        out[currentIdx] = (buff >> bits) & 0xff;
        buff &= (1 << bits) - 1;
        currentIdx += 1;
      }
    }
    return out;
  }

  static List<int> _checksumU5(String prefix, List<int> payloadU5) {
    final prefixU5 = _prefixToU5(prefix);
    final values = <int>[
      ...prefixU5,
      0,
      ...payloadU5,
      ...List<int>.filled(_checksumLengthU5, 0),
    ];

    final check = _polymodKaspa(values);
    var tmp = check;
    final checksumBytes = List<int>.filled(5, 0);
    for (var i = 4; i >= 0; i--) {
      checksumBytes[i] = (tmp & BigInt.from(0xff)).toInt();
      tmp >>= 8;
    }
    return _convert8to5(checksumBytes);
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _verifyKaspaChecksum(String prefix, String payload) {
    final values = payload.split('').map(_bech32CharToValue).toList(growable: false);
    if (values.length < _checksumLengthU5) return false;
    final split = values.length - _checksumLengthU5;
    final payloadU5 = values.sublist(0, split);
    final checksumU5 = values.sublist(split);
    final expected = _checksumU5(prefix, payloadU5);
    return _listEquals(expected, checksumU5);
  }

  static AddressType _detectAddressType(String prefix, String payload, String address) {
    final values = payload.split('').map(_bech32CharToValue).toList(growable: false);
    if (values.length < _checksumLengthU5) {
      throw InvalidAddressException(
        message: 'Invalid address payload',
        address: address,
        reason: 'Payload too short',
      );
    }

    final split = values.length - _checksumLengthU5;
    final payloadU5 = values.sublist(0, split);
    final checksumU5 = values.sublist(split);
    final expectedChecksum = _checksumU5(prefix, payloadU5);
    if (!_listEquals(expectedChecksum, checksumU5)) {
      throw InvalidAddressException.invalidChecksum(address);
    }

    final payloadU8 = _convert5to8(payloadU5);
    if (payloadU8.isEmpty) {
      throw InvalidAddressException(
        message: 'Invalid address payload',
        address: address,
        reason: 'Missing version byte',
      );
    }

    final version = payloadU8.first;
    final payloadLen = payloadU8.length - 1;
    final expectedLen = switch (version) {
      0 => 32, // PubKey (Schnorr)
      1 => 33, // PubKeyECDSA
      2 => 1312, // PubKeyMLDSA (Level2)
      8 => 32, // ScriptHash
      16 => 64, // Stealth
      _ => null,
    };

    if (expectedLen == null) {
      throw InvalidAddressException.unknownType(address);
    }
    if (payloadLen != expectedLen) {
      throw InvalidAddressException(
        message: 'Invalid address payload length',
        address: address,
        reason: 'Expected $expectedLen bytes, got $payloadLen',
      );
    }

    return switch (version) {
      0 => AddressType.p2pk,
      1 => AddressType.p2pkEcdsa,
      2 => AddressType.p2pkMldsa,
      8 => AddressType.p2sh,
      16 => AddressType.stealth,
      _ => AddressType.p2pk, // unreachable due to checks above
    };
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
