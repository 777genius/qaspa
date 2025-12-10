/// Use case for validating Kaspa addresses.
class ValidateAddressUseCase {
  /// Valid Bech32 characters (excluding 1, b, i, o for readability).
  static const _bech32Charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  /// Minimum address length: prefix (6-10) + separator (1) + data (minimum ~40).
  static const _minAddressLength = 50;

  /// Maximum address length for safety.
  static const _maxAddressLength = 120;

  /// Validate a Kaspa address.
  ///
  /// Returns true if the address is potentially valid.
  /// Note: Full validation including checksum requires the Rust bridge.
  bool call(String address) {
    if (address.isEmpty) return false;

    // Check length bounds
    if (address.length < _minAddressLength ||
        address.length > _maxAddressLength) {
      return false;
    }

    // Check prefix and extract data
    final String data;

    if (address.startsWith('kaspa:')) {
      data = address.substring(6);
    } else if (address.startsWith('kaspatest:')) {
      data = address.substring(10);
    } else {
      return false;
    }

    // Check data part is not empty
    if (data.isEmpty) return false;

    // Check all characters are valid bech32 (lowercase only)
    for (final char in data.toLowerCase().codeUnits) {
      final charStr = String.fromCharCode(char);
      if (!_bech32Charset.contains(charStr)) {
        return false;
      }
    }

    return true;
  }
}
