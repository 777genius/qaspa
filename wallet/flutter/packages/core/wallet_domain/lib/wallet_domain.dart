/// Core domain layer with entities, value objects, and repository interfaces
library wallet_domain;

// Entities
export 'src/entities/balance.dart';
export 'src/entities/wallet.dart';
export 'src/entities/account.dart';
export 'src/entities/transaction.dart';
export 'src/entities/sync_state.dart';
export 'src/entities/network_info.dart';
export 'src/entities/utxo.dart';
export 'src/entities/stealth_scan_progress.dart';

// Converters
export 'src/converters/bigint_converter.dart';

// Value Objects
export 'src/value_objects/address.dart';
export 'src/value_objects/mnemonic.dart';
export 'src/value_objects/amount.dart';
export 'src/value_objects/network_id.dart';
export 'src/value_objects/transaction_id.dart';

// Repositories
export 'src/repositories/wallet_repository.dart';
export 'src/repositories/account_repository.dart';
export 'src/repositories/transaction_repository.dart'
    show TransactionRepository, SendRequest, TransactionEstimate;

// Errors
export 'src/errors/wallet_exception.dart';
