import '../value_objects/amount.dart';

/// Base class for all wallet-related exceptions.
/// Maps to Rust errors from `wallet/core/src/error.rs`
sealed class WalletException implements Exception {
  String get code;
  String get message;
  Object? get originalError;

  @override
  String toString() => 'WalletException($code): $message';
}

// ============================================================================
// Network Exceptions
// ============================================================================

/// Network-related exceptions.
final class NotConnectedException extends WalletException {
  @override
  final String code = 'NOT_CONNECTED';
  @override
  final String message;
  @override
  final Object? originalError;

  NotConnectedException({
    this.message = 'Not connected to node',
    this.originalError,
  });
}

final class RpcException extends WalletException {
  @override
  final String code = 'RPC_ERROR';
  @override
  final String message;
  @override
  final Object? originalError;
  final int? rpcCode;

  RpcException({
    required this.message,
    this.originalError,
    this.rpcCode,
  });
}

final class TimeoutException extends WalletException {
  @override
  final String code = 'TIMEOUT';
  @override
  final String message;
  @override
  final Object? originalError;
  final Duration? timeout;

  TimeoutException({
    this.message = 'Network request timed out',
    this.originalError,
    this.timeout,
  });
}

final class NotSyncedException extends WalletException {
  @override
  final String code = 'NOT_SYNCED';
  @override
  final String message;
  @override
  final Object? originalError;
  final double? syncProgress;

  NotSyncedException({
    this.message = 'Node is not fully synced',
    this.originalError,
    this.syncProgress,
  });
}

// ============================================================================
// Validation Exceptions
// ============================================================================

/// Address validation failed.
final class InvalidAddressException extends WalletException {
  @override
  final String code = 'INVALID_ADDRESS';
  @override
  final String message;
  @override
  final Object? originalError;
  final String? address;
  final String? reason;

  InvalidAddressException({
    required this.message,
    this.originalError,
    this.address,
    this.reason,
  });

  factory InvalidAddressException.invalidPrefix(String address, String prefix) =>
      InvalidAddressException(
        message: 'Invalid address prefix: $prefix',
        address: address,
        reason: 'Invalid prefix',
      );

  factory InvalidAddressException.invalidChecksum(String address) =>
      InvalidAddressException(
        message: 'Invalid address checksum',
        address: address,
        reason: 'Invalid bech32 checksum',
      );

  factory InvalidAddressException.unknownType(String address) =>
      InvalidAddressException(
        message: 'Unknown address type',
        address: address,
        reason: 'Could not determine address type',
      );
}

/// Amount validation failed.
final class InvalidAmountException extends WalletException {
  @override
  final String code;
  @override
  final String message;
  @override
  final Object? originalError;

  InvalidAmountException({
    required this.code,
    required this.message,
    this.originalError,
  });
}

/// Password validation failed.
final class InvalidPasswordException extends WalletException {
  @override
  final String code;
  @override
  final String message;
  @override
  final Object? originalError;
  final int? minLength;

  InvalidPasswordException({
    required this.code,
    required this.message,
    this.originalError,
    this.minLength,
  });

  factory InvalidPasswordException.tooShort({int minLength = 8}) =>
      InvalidPasswordException(
        code: 'PASSWORD_TOO_SHORT',
        message: 'Password must be at least $minLength characters',
        minLength: minLength,
      );
}

/// Wallet name validation failed.
final class InvalidWalletNameException extends WalletException {
  @override
  final String code;
  @override
  final String message;
  @override
  final Object? originalError;
  final String? name;

  InvalidWalletNameException({
    required this.code,
    required this.message,
    this.originalError,
    this.name,
  });

  factory InvalidWalletNameException.empty() => InvalidWalletNameException(
        code: 'INVALID_WALLET_NAME',
        message: 'Wallet name cannot be empty',
      );

  factory InvalidWalletNameException.tooLong(String name, {int maxLength = 50}) =>
      InvalidWalletNameException(
        code: 'WALLET_NAME_TOO_LONG',
        message: 'Wallet name must be at most $maxLength characters',
        name: name,
      );
}

/// Insufficient funds for operation.
final class InsufficientFundsException extends WalletException {
  @override
  final String code;
  @override
  final String message;
  @override
  final Object? originalError;
  final Amount? available;
  final Amount? required;
  final Amount? fee;

  InsufficientFundsException({
    this.code = 'INSUFFICIENT_FUNDS',
    this.message = 'Insufficient funds',
    this.originalError,
    this.available,
    this.required,
    this.fee,
  });

  /// How much more is needed
  Amount? get additionalNeeded {
    final avail = available;
    final req = required;
    if (avail == null || req == null) return null;
    final totalRequired = fee != null ? req + fee! : req;
    if (totalRequired > avail) {
      return totalRequired.subtractSafe(avail);
    }
    return null;
  }
}

// ============================================================================
// Crypto Exceptions
// ============================================================================

/// Failed to decrypt wallet/data.
final class DecryptionFailedException extends WalletException {
  @override
  final String code = 'DECRYPTION_FAILED';
  @override
  final String message;
  @override
  final Object? originalError;

  DecryptionFailedException({
    this.message = 'Failed to decrypt wallet',
    this.originalError,
  });
}

/// Invalid mnemonic phrase.
final class InvalidMnemonicException extends WalletException {
  @override
  final String code = 'INVALID_MNEMONIC';
  @override
  final String message;
  @override
  final Object? originalError;
  final int? wordCount;
  final String? invalidWord;

  InvalidMnemonicException({
    this.message = 'Invalid mnemonic phrase',
    this.originalError,
    this.wordCount,
    this.invalidWord,
  });
}

/// Transaction signing failed.
final class SigningFailedException extends WalletException {
  @override
  final String code = 'SIGNING_FAILED';
  @override
  final String message;
  @override
  final Object? originalError;

  SigningFailedException({
    this.message = 'Failed to sign transaction',
    this.originalError,
  });
}

/// Key derivation failed.
final class KeyDerivationFailedException extends WalletException {
  @override
  final String code = 'KEY_DERIVATION_FAILED';
  @override
  final String message;
  @override
  final Object? originalError;

  KeyDerivationFailedException({
    this.message = 'Failed to derive keys',
    this.originalError,
  });
}

// ============================================================================
// Storage Exceptions
// ============================================================================

/// Wallet not found.
final class WalletNotFoundException extends WalletException {
  @override
  final String code = 'WALLET_NOT_FOUND';
  @override
  final String message;
  @override
  final Object? originalError;
  final String? walletId;

  WalletNotFoundException({
    this.message = 'Wallet not found',
    this.originalError,
    this.walletId,
  });
}

/// Wallet already exists.
final class WalletAlreadyExistsException extends WalletException {
  @override
  final String code = 'WALLET_EXISTS';
  @override
  final String message;
  @override
  final Object? originalError;
  final String? walletName;

  WalletAlreadyExistsException({
    this.message = 'Wallet already exists',
    this.originalError,
    this.walletName,
  });
}

/// Wallet is already open.
final class WalletAlreadyOpenException extends WalletException {
  @override
  final String code = 'WALLET_ALREADY_OPEN';
  @override
  final String message;
  @override
  final Object? originalError;
  final String? walletId;

  WalletAlreadyOpenException({
    this.message = 'A wallet is already open',
    this.originalError,
    this.walletId,
  });
}

/// Account not found.
final class AccountNotFoundException extends WalletException {
  @override
  final String code = 'ACCOUNT_NOT_FOUND';
  @override
  final String message;
  @override
  final Object? originalError;
  final String? accountId;

  AccountNotFoundException({
    this.message = 'Account not found',
    this.originalError,
    this.accountId,
  });
}

/// Corrupted data.
final class CorruptedDataException extends WalletException {
  @override
  final String code = 'CORRUPTED_DATA';
  @override
  final String message;
  @override
  final Object? originalError;

  CorruptedDataException({
    this.message = 'Wallet data is corrupted',
    this.originalError,
  });
}

// ============================================================================
// Internal Exception
// ============================================================================

/// Unexpected internal error.
final class InternalException extends WalletException {
  @override
  final String code = 'INTERNAL_ERROR';
  @override
  final String message;
  @override
  final Object? originalError;

  InternalException({
    this.message = 'An unexpected error occurred',
    this.originalError,
  });

  factory InternalException.unexpected(Object error) => InternalException(
        message: 'An unexpected error occurred',
        originalError: error,
      );
}

// ============================================================================
// Transaction Exceptions
// ============================================================================

/// Transaction was rejected.
final class TransactionRejectedException extends WalletException {
  @override
  final String code = 'TRANSACTION_REJECTED';
  @override
  final String message;
  @override
  final Object? originalError;
  final String? txId;
  final String? reason;

  TransactionRejectedException({
    this.message = 'Transaction was rejected',
    this.originalError,
    this.txId,
    this.reason,
  });
}

/// Transaction not found.
final class TransactionNotFoundException extends WalletException {
  @override
  final String code = 'TRANSACTION_NOT_FOUND';
  @override
  final String message;
  @override
  final Object? originalError;
  final String? txId;

  TransactionNotFoundException({
    this.message = 'Transaction not found',
    this.originalError,
    this.txId,
  });
}

// ============================================================================
// Bridge Exceptions
// ============================================================================

/// Incompatible Rust bridge version.
final class IncompatibleVersionException extends WalletException {
  @override
  final String code = 'INCOMPATIBLE_VERSION';
  @override
  final String message;
  @override
  final Object? originalError;
  final String? dartVersion;
  final String? rustVersion;

  IncompatibleVersionException({
    this.message = 'Incompatible Rust bridge version',
    this.originalError,
    this.dartVersion,
    this.rustVersion,
  });
}

/// Bridge not initialized.
final class BridgeNotInitializedException extends WalletException {
  @override
  final String code = 'BRIDGE_NOT_INITIALIZED';
  @override
  final String message = 'WalletBridge not initialized. Call initialize() first.';
  @override
  final Object? originalError = null;

  BridgeNotInitializedException();
}

/// Bridge initialization failed after all retries.
final class BridgeInitializationException extends WalletException {
  @override
  final String code = 'BRIDGE_INIT_FAILED';
  @override
  final String message;
  @override
  final Object? originalError;

  BridgeInitializationException(
    this.message, {
    this.originalError,
  });
}
