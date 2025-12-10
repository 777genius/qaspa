/// Data layer with repository implementations and datasources.
///
/// This package provides:
/// - Repository implementations for wallet_domain interfaces
/// - Local database (Drift) for transaction history
/// - Rust datasource bridging to wallet_rust_bridge
library wallet_data;

// DI
export 'di/wallet_data_injectable.dart';

// Repositories
export 'src/repositories/wallet_repository_impl.dart';
export 'src/repositories/account_repository_impl.dart';
export 'src/repositories/transaction_repository_impl.dart';

// Datasources
export 'src/datasources/rust_datasource.dart';
export 'src/datasources/local_datasource.dart';

// Database
export 'src/database/history_database.dart';
