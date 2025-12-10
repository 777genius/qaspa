import 'package:injectable/injectable.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../datasources/rust_datasource.dart';

/// Implementation of [AccountRepository] using Rust bridge.
@modularityExportEnv
@LazySingleton(as: AccountRepository)
class AccountRepositoryImpl implements AccountRepository {
  final RustDatasource _rust;

  AccountRepositoryImpl(this._rust);

  /// Factory using singleton datasource.
  factory AccountRepositoryImpl.instance() =>
      AccountRepositoryImpl(RustDatasource.instance());

  @override
  Future<List<AccountDescriptor>> listAccounts({required String walletId}) =>
      _rust.listAccounts(walletId: walletId);

  @override
  Future<Account?> getAccount({required String accountId}) =>
      _rust.getAccount(accountId: accountId);

  @override
  Future<Account> createBip32Account({
    required String walletId,
    required String name,
  }) =>
      _rust.createAccount(
        walletId: walletId,
        name: name,
        kind: AccountKind.bip32,
      );

  @override
  Future<Account> createStealthAccount({
    required String walletId,
    required String name,
  }) =>
      _rust.createAccount(
        walletId: walletId,
        name: name,
        kind: AccountKind.stealth,
      );

  @override
  Future<Account> createWatchOnlyAccount({
    required String walletId,
    required String name,
    required Address address,
  }) {
    throw UnimplementedError('Watch-only account creation not yet implemented');
  }

  @override
  Future<void> activateAccount({required String accountId}) {
    // In Rust, accounts are activated by default
    return Future.value();
  }

  @override
  Future<void> deactivateAccount({required String accountId}) {
    throw UnimplementedError('Account deactivation not yet implemented');
  }

  @override
  Future<void> deleteAccount({required String accountId}) {
    throw UnimplementedError('Account deletion not yet implemented');
  }

  @override
  Future<Account> renameAccount({
    required String accountId,
    required String newName,
  }) {
    throw UnimplementedError('Account rename not yet implemented');
  }

  @override
  Future<Balance> getBalance({required String accountId}) =>
      _rust.getBalance(accountId: accountId);

  @override
  Stream<Balance> watchBalance({required String accountId}) =>
      _rust.watchBalance(accountId: accountId);

  @override
  Future<Address> getReceiveAddress({required String accountId}) =>
      _rust.getReceiveAddress(accountId: accountId);

  @override
  Future<Address> generateNewAddress({required String accountId}) =>
      _rust.generateNewAddress(accountId: accountId);

  @override
  Future<List<Address>> getAddresses({
    required String accountId,
    int? limit,
  }) {
    throw UnimplementedError('Get all addresses not yet implemented');
  }

  @override
  Future<void> scanStealthPayments({required String accountId}) =>
      _rust.scanStealthPayments(accountId: accountId);
}
