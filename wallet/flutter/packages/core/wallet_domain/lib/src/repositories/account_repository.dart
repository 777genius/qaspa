import '../entities/account.dart';
import '../entities/balance.dart';
import '../value_objects/address.dart';

/// Repository interface for account operations.
/// Implementations: RustAccountRepository (wallet_data package)
abstract interface class AccountRepository {
  /// List all accounts for a wallet
  Future<List<AccountDescriptor>> listAccounts({required String walletId});

  /// Get account by ID
  Future<Account?> getAccount({required String accountId});

  /// Create a new BIP-32 derived account
  Future<Account> createBip32Account({
    required String walletId,
    required String name,
  });

  /// Create a stealth account
  Future<Account> createStealthAccount({
    required String walletId,
    required String name,
  });

  /// Create a watch-only account
  Future<Account> createWatchOnlyAccount({
    required String walletId,
    required String name,
    required Address address,
  });

  /// Activate an account (start tracking UTXOs)
  Future<void> activateAccount({required String accountId});

  /// Deactivate an account
  Future<void> deactivateAccount({required String accountId});

  /// Delete an account
  Future<void> deleteAccount({required String accountId});

  /// Rename an account
  Future<Account> renameAccount({
    required String accountId,
    required String newName,
  });

  /// Get current balance for an account
  Future<Balance> getBalance({required String accountId});

  /// Watch balance changes (reactive stream)
  Stream<Balance> watchBalance({required String accountId});

  /// Get receive address for an account
  Future<Address> getReceiveAddress({required String accountId});

  /// Generate new receive address (increments index)
  Future<Address> generateNewAddress({required String accountId});

  /// Get all addresses for an account
  Future<List<Address>> getAddresses({
    required String accountId,
    int? limit,
  });

  /// Scan for stealth payments (stealth accounts only)
  Future<void> scanStealthPayments({required String accountId});
}
