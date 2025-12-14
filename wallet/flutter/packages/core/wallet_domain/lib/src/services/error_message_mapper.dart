import '../errors/wallet_exception.dart';

/// Maps domain exceptions to user-friendly error messages.
///
/// This centralizes error message logic that was previously duplicated
/// across multiple stores (SendStore, StealthStore, SettingsStore).
abstract interface class ErrorMessageMapper {
  /// Maps transaction-related errors to user messages.
  String mapTransactionError(Object error);

  /// Maps wallet management errors to user messages.
  String mapWalletError(Object error);

  /// Maps generic errors to user messages.
  String mapGenericError(Object error);
}

/// Default implementation of [ErrorMessageMapper].
class ErrorMessageMapperImpl implements ErrorMessageMapper {
  const ErrorMessageMapperImpl();

  @override
  String mapTransactionError(Object error) {
    return switch (error) {
      InsufficientFundsException() => 'Insufficient funds for this transaction',
      InvalidPasswordException() => 'Invalid password',
      InvalidAddressException() => 'Invalid recipient address',
      InvalidAmountException() => 'Invalid amount',
      NotConnectedException() => 'Network error. Please check your connection',
      RpcException() => 'Network error. Please check your connection',
      TimeoutException() => 'Request timed out. Please try again',
      NotSyncedException() => 'Node is not fully synced. Please wait',
      SigningFailedException() => 'Failed to sign transaction',
      TransactionRejectedException() => 'Transaction was rejected by the network',
      _ => 'Transaction failed. Please try again',
    };
  }

  @override
  String mapWalletError(Object error) {
    return switch (error) {
      InvalidPasswordException() => 'Invalid password',
      WalletNotFoundException() => 'Wallet not found',
      WalletAlreadyExistsException() => 'Wallet with this name already exists',
      WalletAlreadyOpenException() => 'A wallet is already open',
      DecryptionFailedException() => 'Failed to decrypt wallet. Check your password',
      InvalidMnemonicException() => 'Invalid recovery phrase',
      CorruptedDataException() => 'Wallet data is corrupted',
      NotConnectedException() => 'Network error. Please check your connection',
      RpcException() => 'Network error. Please check your connection',
      _ => 'Wallet operation failed. Please try again',
    };
  }

  @override
  String mapGenericError(Object error) {
    return switch (error) {
      WalletException e => e.message,
      _ => 'An unexpected error occurred',
    };
  }
}
