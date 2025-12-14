import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'history_database.g.dart';

final _log = Logger('HistoryDatabase');

/// Transaction record table.
class TransactionRecords extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get kind => text()();
  TextColumn get networkId => text()();
  IntColumn get timestamp => integer()();

  /// Amount in SOMPI stored as TEXT for BigInt support
  TextColumn get amount => text()();

  /// Fee in SOMPI stored as TEXT for BigInt support (nullable)
  TextColumn get fee => text().nullable()();

  /// JSON-encoded list of addresses
  TextColumn get fromAddresses => text().nullable()();

  /// JSON-encoded list of addresses
  TextColumn get toAddresses => text().nullable()();

  TextColumn get note => text().nullable()();
  TextColumn get metadata => text().nullable()();
  IntColumn get acceptedDaaScore => integer().nullable()();
  BoolColumn get isConfirmed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database for transaction history storage.
@DriftDatabase(tables: [TransactionRecords])
class HistoryDatabase extends _$HistoryDatabase {
  HistoryDatabase(super.e);

  /// Create database with native executor.
  factory HistoryDatabase.open() {
    return HistoryDatabase(_openConnection());
  }

  /// Create in-memory database for testing.
  factory HistoryDatabase.inMemory() {
    return HistoryDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Create indexes for performance
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_account_id ON transaction_records(account_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_timestamp ON transaction_records(timestamp DESC)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_account_timestamp ON transaction_records(account_id, timestamp DESC)',
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Migration from v1 to v2: amount/fee changed from INT to TEXT
            // ATOMIC migration: wrapped in transaction to prevent data loss on crash
            await transaction(() async {
              // 1. Check if old table exists and has data
              final hasOldTable = await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='transaction_records'",
              ).get();

              if (hasOldTable.isNotEmpty) {
                // 2. Create backup table with old data
                await customStatement('''
                  CREATE TABLE IF NOT EXISTS transaction_records_backup AS
                  SELECT * FROM transaction_records
                ''');

                // 3. Drop old table
                await customStatement('DROP TABLE transaction_records');
              }

              // 4. Create new table with TEXT columns
              await m.createAll();

              // 5. Migrate data from backup (convert INT to TEXT for amounts)
              final hasBackup = await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='transaction_records_backup'",
              ).get();

              if (hasBackup.isNotEmpty) {
                _log.info('Starting data migration from backup table');

                // Use INSERT OR REPLACE to handle any potential duplicates
                await customStatement('''
                  INSERT OR REPLACE INTO transaction_records
                  (id, account_id, kind, network_id, timestamp, amount, fee,
                   from_addresses, to_addresses, note, metadata,
                   accepted_daa_score, is_confirmed)
                  SELECT
                    id, account_id, kind, network_id, timestamp,
                    CAST(amount AS TEXT),
                    CASE WHEN fee IS NOT NULL THEN CAST(fee AS TEXT) ELSE NULL END,
                    from_addresses, to_addresses, note, metadata,
                    accepted_daa_score, is_confirmed
                  FROM transaction_records_backup
                ''');

                // 6. Verify migration success before dropping backup
                final oldCount = await customSelect(
                  'SELECT COUNT(*) as cnt FROM transaction_records_backup',
                ).getSingle();
                final newCount = await customSelect(
                  'SELECT COUNT(*) as cnt FROM transaction_records',
                ).getSingle();

                final oldRowCount = oldCount.read<int>('cnt');
                final newRowCount = newCount.read<int>('cnt');

                if (newRowCount < oldRowCount) {
                  _log.severe(
                    'Migration verification failed: expected $oldRowCount rows, got $newRowCount. '
                    'Backup table preserved for manual recovery.',
                  );
                  throw Exception(
                    'Migration verification failed: '
                    'expected $oldRowCount rows, got $newRowCount',
                  );
                }

                _log.info(
                  'Migration successful: $newRowCount transactions migrated',
                );

                // 7. Drop backup table only after verification
                await customStatement('DROP TABLE transaction_records_backup');
                _log.info('Backup table dropped after successful migration');
              }

              // 8. Create indexes
              await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_tx_account_id ON transaction_records(account_id)',
              );
              await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_tx_timestamp ON transaction_records(timestamp DESC)',
              );
              await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_tx_account_timestamp ON transaction_records(account_id, timestamp DESC)',
              );
            });
          }
        },
      );

  // === Queries ===

  /// Insert or update a transaction.
  Future<void> insertTransaction(TransactionRecord record) async {
    await into(transactionRecords).insertOnConflictUpdate(
      TransactionRecordsCompanion.insert(
        id: record.id,
        accountId: record.accountId,
        kind: record.kind,
        networkId: record.networkId,
        timestamp: record.timestamp,
        amount: record.amount,
        fee: Value(record.fee),
        fromAddresses: Value(record.fromAddresses),
        toAddresses: Value(record.toAddresses),
        note: Value(record.note),
        metadata: Value(record.metadata),
        acceptedDaaScore: Value(record.acceptedDaaScore),
        isConfirmed: Value(record.isConfirmed),
      ),
    );
  }

  /// Get transactions for account with optional filters.
  Future<List<TransactionRecord>> getTransactions({
    required String accountId,
    int? limit,
    int? offset,
    String? kind,
  }) async {
    var query = select(transactionRecords)
      ..where((t) => t.accountId.equals(accountId))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);

    if (kind != null) {
      query = query..where((t) => t.kind.equals(kind));
    }

    if (limit != null) {
      query = query..limit(limit, offset: offset);
    }

    return query.get();
  }

  /// Watch transactions for account (reactive).
  /// [limit] defaults to 100 to prevent OOM with large transaction history.
  Stream<List<TransactionRecord>> watchTransactions({
    required String accountId,
    int limit = 100,
  }) {
    return (select(transactionRecords)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .watch();
  }

  /// Get single transaction by ID.
  Future<TransactionRecord?> getTransactionById(String id) async {
    return (select(transactionRecords)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Update transaction note.
  Future<void> updateTransactionNote(String id, String note) async {
    await (update(transactionRecords)..where((t) => t.id.equals(id)))
        .write(TransactionRecordsCompanion(note: Value(note)));
  }

  /// Mark transaction as confirmed.
  Future<void> markConfirmed(String id, int daaScore) async {
    await (update(transactionRecords)..where((t) => t.id.equals(id))).write(
      TransactionRecordsCompanion(
        isConfirmed: const Value(true),
        acceptedDaaScore: Value(daaScore),
      ),
    );
  }

  /// Get transaction count for account.
  Future<int> getTransactionCount(String accountId) async {
    final count = transactionRecords.id.count();
    final query = selectOnly(transactionRecords)
      ..addColumns([count])
      ..where(transactionRecords.accountId.equals(accountId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Delete all transactions for account.
  Future<void> deleteTransactionsForAccount(String accountId) async {
    await (delete(transactionRecords)
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }
}

// Note: TransactionRecord class is generated by Drift in history_database.g.dart

/// Whether the database is using in-memory fallback mode.
/// This happens when the file-based database fails to open (corrupted, permissions, etc.)
bool _isUsingInMemoryFallback = false;

/// Check if the database is using in-memory fallback mode.
bool get isHistoryDatabaseInMemory => _isUsingInMemoryFallback;

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'kaspa_wallet.db'));

      // Try to open the database with recovery options
      final database = NativeDatabase.createInBackground(
        file,
        setup: (rawDb) {
          // Enable WAL mode for better performance and crash recovery
          rawDb.execute('PRAGMA journal_mode=WAL');
          // Run integrity check on open
          rawDb.execute('PRAGMA integrity_check');
        },
      );

      _isUsingInMemoryFallback = false;
      _log.info('Database opened successfully: ${file.path}');
      return database;
    } catch (e, stack) {
      // Log the error
      _log.severe(
        'Failed to open database file, falling back to in-memory database. '
        'Data will not persist across app restarts.',
        e,
        stack,
      );

      // Try to delete corrupted file for next restart
      try {
        final dbFolder = await getApplicationDocumentsDirectory();
        final file = File(p.join(dbFolder.path, 'kaspa_wallet.db'));
        final walFile = File(p.join(dbFolder.path, 'kaspa_wallet.db-wal'));
        final shmFile = File(p.join(dbFolder.path, 'kaspa_wallet.db-shm'));

        if (await file.exists()) {
          // Rename instead of delete to preserve for debugging
          await file.rename('${file.path}.corrupted.${DateTime.now().millisecondsSinceEpoch}');
        }
        if (await walFile.exists()) await walFile.delete();
        if (await shmFile.exists()) await shmFile.delete();

        _log.info('Corrupted database files have been renamed for debugging');
      } catch (cleanupError) {
        _log.warning('Failed to cleanup corrupted database files', cleanupError);
      }

      // Fall back to in-memory database
      _isUsingInMemoryFallback = true;
      _log.warning('Using in-memory database as fallback');
      return NativeDatabase.memory();
    }
  });
}
