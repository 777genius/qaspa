import 'package:wallet_domain/wallet_domain.dart';

/// Base class for all wallet events from Rust.
sealed class WalletEvent {
  /// Event timestamp - captured at creation time.
  final DateTime timestamp;

  WalletEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

// ============================================================================
// WALLET LIFECYCLE EVENTS
// ============================================================================

/// Wallet opened event.
final class WalletOpenEvent extends WalletEvent {
  final String walletId;
  final String walletName;

  WalletOpenEvent({
    required this.walletId,
    required this.walletName,
    super.timestamp,
  });
}

/// Wallet closed event.
final class WalletCloseEvent extends WalletEvent {
  final String walletId;

  WalletCloseEvent({required this.walletId, super.timestamp});
}

// ============================================================================
// ACCOUNT EVENTS
// ============================================================================

/// Account activation changed event.
final class AccountActivationEvent extends WalletEvent {
  final List<String> activatedAccounts;
  final List<String> deactivatedAccounts;

  AccountActivationEvent({
    this.activatedAccounts = const [],
    this.deactivatedAccounts = const [],
    super.timestamp,
  });
}

/// Address generated event.
final class AddressGeneratedEvent extends WalletEvent {
  final String accountId;
  final Address address;

  AddressGeneratedEvent({
    required this.accountId,
    required this.address,
    super.timestamp,
  });
}

// ============================================================================
// BALANCE & UTXO EVENTS
// ============================================================================

/// Balance update event.
final class BalanceUpdateEvent extends WalletEvent {
  final String accountId;
  final Balance balance;

  BalanceUpdateEvent({
    required this.accountId,
    required this.balance,
    super.timestamp,
  });
}

/// UTXO update event.
final class UtxoUpdateEvent extends WalletEvent {
  final String accountId;
  final int matureCount;
  final int pendingCount;
  final int stasisCount;

  UtxoUpdateEvent({
    required this.accountId,
    required this.matureCount,
    required this.pendingCount,
    this.stasisCount = 0,
    super.timestamp,
  });
}

// ============================================================================
// TRANSACTION EVENTS
// ============================================================================

/// New transaction received/sent event.
final class TransactionEvent extends WalletEvent {
  final String accountId;
  final Transaction transaction;

  TransactionEvent({
    required this.accountId,
    required this.transaction,
    super.timestamp,
  });
}

/// Pending transaction event (submitted but not confirmed).
final class PendingTransactionEvent extends WalletEvent {
  final String accountId;
  final TransactionId transactionId;
  final Amount amount;
  final Address destination;

  PendingTransactionEvent({
    required this.accountId,
    required this.transactionId,
    required this.amount,
    required this.destination,
    super.timestamp,
  });
}

/// Transaction confirmed event.
final class TransactionConfirmedEvent extends WalletEvent {
  final TransactionId transactionId;
  final int confirmations;
  final int daaScore;

  TransactionConfirmedEvent({
    required this.transactionId,
    required this.confirmations,
    required this.daaScore,
    super.timestamp,
  });
}

/// Transaction failed event.
final class TransactionFailedEvent extends WalletEvent {
  final TransactionId transactionId;
  final String reason;
  final WalletException? exception;

  TransactionFailedEvent({
    required this.transactionId,
    required this.reason,
    this.exception,
    super.timestamp,
  });
}

// ============================================================================
// SYNC & CONNECTION EVENTS
// ============================================================================

/// Sync state changed event.
final class SyncStateEvent extends WalletEvent {
  final SyncState state;

  SyncStateEvent({required this.state, super.timestamp});
}

/// Connection state changed event.
final class ConnectionEvent extends WalletEvent {
  final bool isConnected;
  final String? nodeUrl;
  final String? error;

  ConnectionEvent({
    required this.isConnected,
    this.nodeUrl,
    this.error,
    super.timestamp,
  });
}

/// DAA score update event.
final class DaaScoreEvent extends WalletEvent {
  final int currentDaaScore;

  DaaScoreEvent({required this.currentDaaScore, super.timestamp});
}

// ============================================================================
// STEALTH EVENTS
// ============================================================================

/// Stealth payment discovered event.
final class StealthPaymentEvent extends WalletEvent {
  final String accountId;
  final BigInt amount;
  final String? sender;
  final TransactionId? transactionId;

  StealthPaymentEvent({
    required this.accountId,
    required this.amount,
    this.sender,
    this.transactionId,
    super.timestamp,
  });
}

/// Stealth scan progress event.
final class StealthScanEvent extends WalletEvent {
  final String accountId;
  final int scannedBlocks;
  final int totalBlocks;
  final int foundPayments;
  final bool isComplete;

  StealthScanEvent({
    required this.accountId,
    required this.scannedBlocks,
    required this.totalBlocks,
    required this.foundPayments,
    required this.isComplete,
    super.timestamp,
  });

  double get progress =>
      totalBlocks > 0 ? scannedBlocks / totalBlocks : 0.0;
}

// ============================================================================
// ERROR EVENTS
// ============================================================================

/// Error event for async operation failures.
final class ErrorEvent extends WalletEvent {
  final WalletException exception;
  final String? context;

  ErrorEvent({
    required this.exception,
    this.context,
    super.timestamp,
  });
}
