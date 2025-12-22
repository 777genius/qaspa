import 'package:freezed_annotation/freezed_annotation.dart';

part 'network_info.freezed.dart';
part 'network_info.g.dart';

/// Network type enum matching backend
enum NetworkType {
  mainnet,
  testnet,
  devnet,
  simnet;

  String get displayName {
    switch (this) {
      case NetworkType.mainnet:
        return 'Mainnet';
      case NetworkType.testnet:
        return 'Testnet';
      case NetworkType.devnet:
        return 'Devnet';
      case NetworkType.simnet:
        return 'Simnet';
    }
  }
}

/// Network information from cluster API
@freezed
sealed class NetworkInfo with _$NetworkInfo {
  const NetworkInfo._();

  const factory NetworkInfo({
    required NetworkType networkType,
    required String addressPrefix,
    required String defaultAddress,
  }) = _NetworkInfo;

  factory NetworkInfo.fromJson(Map<String, dynamic> json) =>
      _$NetworkInfoFromJson(json);

  /// Validate if address has correct prefix for this network
  bool isValidAddressPrefix(String address) {
    return address.startsWith(addressPrefix);
  }

  /// Get validation error message for address
  String? validateAddress(String? address) {
    if (address == null || address.isEmpty) {
      return 'Required';
    }
    if (!address.startsWith(addressPrefix)) {
      return 'Must start with "$addressPrefix" (${networkType.displayName})';
    }
    if (address.length < 50) {
      return 'Invalid address format';
    }
    return null;
  }
}
