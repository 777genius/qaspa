import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart' as wallet_domain;

/// Use case for validating Kaspa addresses.
@injectable
class ValidateAddressUseCase {
  /// Minimum address length: prefix (6-10) + separator (1) + data (minimum ~40).
  static const _minAddressLength = 50;

  /// Maximum address length for safety.
  ///
  /// Kaspa MLDSA addresses are large (PubKeyMLDSA payload ~2100 chars), so keep
  /// this high enough to allow them.
  static const _maxAddressLength = 3000;

  /// Validate a Kaspa address.
  ///
  /// Returns true if the address is valid (checksum + payload length + type).
  bool call(String address) {
    if (address.isEmpty) return false;

    final trimmed = address.trim();

    // Check length bounds
    if (trimmed.length < _minAddressLength || trimmed.length > _maxAddressLength) {
      return false;
    }

    // Fast path: ensure prefix separator exists
    if (!trimmed.contains(':')) return false;

    // Full validation (checksum + payload length + type parsing)
    try {
      wallet_domain.Address.fromString(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }
}
