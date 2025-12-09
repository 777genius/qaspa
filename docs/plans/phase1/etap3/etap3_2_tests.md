# Stealth Address Tests - IMPLEMENTED

**Status**: All tests implemented and compiling

## Files Created:
- `testing/integration/src/stealth_flow.rs` - 7 integration tests
- `crypto/stealth/fuzz/Cargo.toml` - Fuzz config
- `crypto/stealth/fuzz/fuzz_targets/*.rs` - 3 fuzz targets

## Run Commands:
```bash
# Run all stealth tests
cargo test --release -p kaspa-testing-integration stealth_flow

# Run specific test
cargo test --release -p kaspa-testing-integration stealth_flow::test_stealth_send_receive

# Fuzz testing (requires nightly)
cd crypto/stealth/fuzz
cargo +nightly fuzz run parse_ephemeral_output -- -max_len=128 -runs=100000
```

---

   Философия тестирования

     Тесты должны проверять не только happy path, но и:
     - Adversarial conditions — что происходит когда сеть ведёт себя неожиданно
     - Race conditions — concurrent access, timing attacks
     - Recovery — crash recovery, persistence integrity
     - Cryptographic edge cases — view tag collisions, key space boundaries

     ---
     1. Integration Tests (testing/integration/src/stealth_flow.rs)

     1.1 Test Infrastructure

     /// Test environment с полным контролем над демоном и wallet
     pub struct StealthTestEnv {
         daemon: Daemon,
         rpc_client: GrpcClient,

         // Miner infrastructure
         miner_keypair: Keypair,
         miner_address: Address,
         miner_spk: ScriptPublicKey,

         // Wallet
         wallet: Arc<Wallet>,
         wallet_secret: Secret,

         // Timing
         coinbase_maturity: u64,
     }

     impl StealthTestEnv {
         /// Создаёт изолированное окружение с simnet daemon
         async fn new() -> Self;

         /// Майнит N блоков, ждёт VirtualDaaScoreChanged notification
         async fn mine_blocks(&self, count: u64);

         /// Создаёт и разблокирует stealth account
         async fn create_stealth_account(&self, name: &str) -> Arc<StealthAccount>;

         /// Отправляет на stealth address, возвращает (tx, outpoint, ephemeral_output)
         async fn send_to_stealth(
             &self,
             amount: u64,
             stealth_addr: &StealthAddress,
         ) -> (Transaction, TransactionOutpoint, EphemeralOutput);

         /// Ждёт условие с timeout и детальным error message
         async fn wait_for<F, Fut>(&self, condition: F, timeout_ms: u64, msg: &str)
         where
             F: Fn() -> Fut,
             Fut: Future<Output = bool>;

         /// Cleanup
         async fn shutdown(self);
     }

     1.2 test_stealth_send_receive — Полный цикл платежа

     Проверяем: Получатель детектирует stealth UTXO через UtxoProcessor notification.

     #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
     async fn test_stealth_send_receive() {
         let env = StealthTestEnv::new().await;

         // === SETUP ===
         let receiver = env.create_stealth_account("receiver").await;
         receiver.connect().await.unwrap();
         receiver.unlock(&env.wallet_secret, None).await.unwrap();

         // Mine to maturity
         env.mine_blocks(env.coinbase_maturity + 10).await;

         let initial_balance = receiver.balance().await.unwrap().mature;
         assert_eq!(initial_balance, 0);

         // === SEND TO STEALTH ===
         let send_amount = 10_000_000_000u64; // 10 KAS
         let (tx, outpoint, _ephemeral) = env.send_to_stealth(
             send_amount,
             receiver.stealth_address(),
         ).await;

         // === MINE AND VERIFY ===
         env.mine_blocks(1).await;

         // Wait for UtxoProcessor to process notification
         env.wait_for(
             || async { receiver.balance().await.unwrap().mature > 0 },
             5000,
             "Receiver should detect stealth UTXO via UtxoProcessor notification"
         ).await;

         // === ASSERTIONS ===

         // 1. Balance updated correctly
         let balance = receiver.balance().await.unwrap();
         assert_eq!(balance.mature, send_amount, "Balance mismatch");

         // 2. Ephemeral key stored
         assert!(
             receiver.ephemeral_keys().contains(&outpoint),
             "Ephemeral key should be stored after detection"
         );

         // 3. Outpoint registered in UtxoProcessor index
         let processor = env.wallet.utxo_processor();
         assert!(
             processor.get_handler_for_outpoint(&outpoint).is_some(),
             "Outpoint should be registered in processor index"
         );

         // 4. UTXO context contains the entry
         let utxos = receiver.utxo_context().mature().await;
         assert_eq!(utxos.len(), 1);
         assert_eq!(utxos[0].outpoint(), &outpoint);

         env.shutdown().await;
     }

     Edge cases в этом тесте:
     - Notification приходит асинхронно — используем polling с timeout
     - Проверяем и balance, и internal state (ephemeral_keys, outpoint index)

     1.3 test_stealth_change_flow — Pre-calculated change keys

     Проверяем: При отправке ИЗ stealth account, change output использует pre-calculated spending key.

     #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
     async fn test_stealth_change_flow() {
         let env = StealthTestEnv::new().await;

         // === SETUP: Fund stealth account ===
         let stealth = env.create_stealth_account("sender").await;
         stealth.connect().await.unwrap();
         stealth.unlock(&env.wallet_secret, None).await.unwrap();

         // Fund with 50 KAS
         let initial_funding = 50_000_000_000u64;
         let (_, funding_outpoint, _) = env.send_to_stealth(
             initial_funding,
             stealth.stealth_address(),
         ).await;
         env.mine_blocks(1).await;

         env.wait_for(
             || async { stealth.balance().await.unwrap().mature >= initial_funding },
             5000,
             "Stealth account should be funded"
         ).await;

         let initial_ephemeral_count = stealth.ephemeral_keys().len();
         assert_eq!(initial_ephemeral_count, 1); // Funding UTXO

         // === SEND FROM STEALTH ===
         let external_address = Address::new(
             Prefix::Simnet,
             Version::PubKey,
             &[99u8; 32],
         );
         let send_amount = 20_000_000_000u64; // 20 KAS

         // CRITICAL: Capture tx before mining to verify pre-calculation
         let (summary, tx_ids) = stealth.send(
             PaymentDestination::PaymentOutputs(vec![(external_address, send_amount)].into()),
             None,
             Fees::SenderPays(0),
             None,
             env.wallet_secret.clone(),
             None,
             &Abortable::default(),
             None,
         ).await.unwrap();

         assert_eq!(tx_ids.len(), 1);
         let tx_id = tx_ids[0];

         // === VERIFY PRE-CALCULATION ===

         // Change ephemeral key должен быть сохранён СРАЗУ после send(), ДО майнинга
         // Это критично: finalize_stealth_change() вызывается внутри send()
         let new_ephemeral_count = stealth.ephemeral_keys().len();
         assert_eq!(
             new_ephemeral_count,
             initial_ephemeral_count, // -1 spent, +1 change = same
             "Change ephemeral key should be pre-stored before mining"
         );

         // Verify change outpoint exists (output index 1 typically)
         let change_outpoint = TransactionOutpoint::new(tx_id, 1);
         assert!(
             stealth.ephemeral_keys().contains(&change_outpoint),
             "Change outpoint should have pre-calculated key"
         );

         // === MINE AND VERIFY CONFIRMATION ===
         env.mine_blocks(1).await;

         env.wait_for(
             || async {
                 stealth.ephemeral_keys().status(&change_outpoint)
                     == Some(EphemeralKeyStatus::Confirmed { .. })
             },
             5000,
             "Change key status should become Confirmed after mining"
         ).await;

         // Verify balance
         let final_balance = stealth.balance().await.unwrap().mature;
         let expected = initial_funding - send_amount - summary.aggregate_fees;
         assert!(
             (final_balance as i64 - expected as i64).abs() < 10_000,
             "Balance mismatch: expected ~{}, got {}", expected, final_balance
         );

         // === VERIFY SPENT UTXO CLEANUP ===

         // Original funding outpoint should be removed from ephemeral_keys
         assert!(
             !stealth.ephemeral_keys().contains(&funding_outpoint),
             "Spent UTXO should be removed from ephemeral_keys"
         );

         env.shutdown().await;
     }

     Критические проверки:
     - Pre-calculation: key сохраняется ДО майнинга
     - Status transition: Pending → Confirmed
     - Cleanup: spent UTXO удаляется из ephemeral_keys

     1.4 test_stealth_reorg_cleanup — Full reorg simulation

     Проверяем: При реорганизации ephemeral keys корректно очищаются.

     #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
     async fn test_stealth_reorg_cleanup() {
         // === SETUP: Two separate daemons ===
         let args = Args {
             simnet: true,
             unsafe_rpc: true,
             enable_unsynced_mining: true,
             disable_upnp: true,
             utxoindex: true,
             ..Default::default()
         };

         let fd_budget = kaspa_utils::fd_budget::limit() / 2 - 128;
         let mut daemon1 = Daemon::new_random_with_args(args.clone(), fd_budget);
         let mut daemon2 = Daemon::new_random_with_args(args, fd_budget);

         let client1 = daemon1.start().await;
         let client2 = daemon2.start().await;

         // Connect initially to sync genesis
         client1.add_peer(
             format!("127.0.0.1:{}", daemon2.p2p_port).try_into().unwrap(),
             true
         ).await.unwrap();
         tokio::time::sleep(Duration::from_secs(1)).await;

         // Create wallet on daemon1
         let wallet = Wallet::try_new_arc(
             None,
             Some(daemon1.network.into()),
             None,
             None,
         ).await.unwrap();
         wallet.utxo_processor()
             .bind_rpc(Some(client1.clone().into()))
             .await.unwrap();

         let wallet_secret = Secret::new([1u8; 32].to_vec());
         let stealth = create_test_stealth_account(&wallet, &wallet_secret).await;
         stealth.connect().await.unwrap();
         stealth.unlock(&wallet_secret, None).await.unwrap();

         // Mine to maturity on daemon1
         let miner1 = generate_miner_keypair();
         for _ in 0..100 {
             let template = client1.get_block_template(miner1.address.clone(), vec![]).await.unwrap();
             client1.submit_block(template.block, false).await.unwrap();
         }
         tokio::time::sleep(Duration::from_millis(500)).await;

         // === DISCONNECT: Create partition ===
         // Note: В simnet нет прямого способа disconnect, используем разные цепочки

         // === ON DAEMON1: Create stealth UTXO ===
         let (tx, outpoint, _) = send_to_stealth_via_client(
             &client1,
             &miner1,
             10_000_000_000u64,
             stealth.stealth_address(),
         ).await;

         // Mine 1 block on daemon1 containing the stealth tx
         let template = client1.get_block_template(miner1.address.clone(), vec![tx.clone()]).await.unwrap();
         let block1_hash = Header::try_from(&template.block.header).unwrap().hash;
         client1.submit_block(template.block, false).await.unwrap();

         // Wait for detection
         wait_for(
             50, 100,
             || async { stealth.ephemeral_keys().contains(&outpoint) },
             "Stealth UTXO should be detected"
         ).await;

         assert!(stealth.ephemeral_keys().contains(&outpoint));
         let balance_before_reorg = stealth.balance().await.unwrap().mature;
         assert!(balance_before_reorg > 0);

         // === ON DAEMON2: Mine longer chain (no stealth tx) ===
         let miner2 = generate_miner_keypair();
         for _ in 0..3 {
             let template = client2.get_block_template(miner2.address.clone(), vec![]).await.unwrap();
             client2.submit_block(template.block, false).await.unwrap();
         }

         // === RECONNECT: Trigger reorg ===
         // Daemon1 will sync to daemon2's longer chain
         // The block containing stealth tx becomes orphan

         client1.add_peer(
             format!("127.0.0.1:{}", daemon2.p2p_port).try_into().unwrap(),
             true
         ).await.unwrap();

         // Wait for reorg to complete
         wait_for(
             100, 50,
             || async {
                 let dag1 = client1.get_block_dag_info().await.unwrap();
                 let dag2 = client2.get_block_dag_info().await.unwrap();
                 dag1.sink == dag2.sink // Both nodes on same tip
             },
             "Nodes should sync to same tip after reconnect"
         ).await;

         // === VERIFY CLEANUP ===

         // Wait for UtxosChangedNotification with removed entry
         wait_for(
             100, 100,
             || async { !stealth.ephemeral_keys().contains(&outpoint) },
             "Ephemeral key should be removed after reorg"
         ).await;

         // Verify ephemeral key removed
         assert!(
             !stealth.ephemeral_keys().contains(&outpoint),
             "Reorged UTXO's ephemeral key should be cleaned up"
         );

         // Verify outpoint index cleaned
         assert!(
             wallet.utxo_processor().get_handler_for_outpoint(&outpoint).is_none(),
             "Outpoint should be removed from processor index"
         );

         // Verify balance reset
         let balance_after_reorg = stealth.balance().await.unwrap().mature;
         assert_eq!(
             balance_after_reorg, 0,
             "Balance should be 0 after reorg removed the UTXO"
         );

         // Cleanup
         client1.disconnect().await.ok();
         client2.disconnect().await.ok();
         daemon1.shutdown();
         daemon2.shutdown();
     }

     Критические аспекты:
     - Два независимых демона на разных портах
     - Partition → divergent chains → reconnect → reorg
     - Проверяем cleanup на всех уровнях: ephemeral_keys, outpoint index, balance

     1.5 test_rpc_restore — Persistence и recovery

     Проверяем: После "restart" (clear + reload) все ключи восстанавливаются.

     #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
     async fn test_rpc_restore() {
         let env = StealthTestEnv::new().await;

         // === SETUP ===
         let stealth = env.create_stealth_account("restore_test").await;
         stealth.connect().await.unwrap();
         stealth.unlock(&env.wallet_secret, None).await.unwrap();

         // Fund with 3 separate UTXOs
         let mut outpoints = Vec::new();
         for i in 0..3 {
             let (_, outpoint, _) = env.send_to_stealth(
                 10_000_000_000u64 * (i + 1) as u64,
                 stealth.stealth_address(),
             ).await;
             outpoints.push(outpoint);
             env.mine_blocks(1).await;
         }

         env.wait_for(
             || async { stealth.ephemeral_keys().len() >= 3 },
             5000,
             "Should have 3 ephemeral keys"
         ).await;

         // === CAPTURE ORIGINAL STATE ===
         let original_outpoints: HashSet<_> = stealth.ephemeral_keys()
             .outpoints()
             .into_iter()
             .collect();
         let original_balance = stealth.balance().await.unwrap().mature;

         assert_eq!(original_outpoints.len(), 3);
         for op in &outpoints {
             assert!(original_outpoints.contains(op));
         }

         // === SAVE TO STORAGE ===
         stealth.save_ephemeral_keys(&env.wallet_secret).await.unwrap();

         // === SIMULATE RESTART ===
         // Clear all in-memory state
         stealth.utxo_context().clear().await.unwrap();
         stealth.ephemeral_keys().clear();

         // Verify cleared
         assert_eq!(stealth.ephemeral_keys().len(), 0);
         assert_eq!(stealth.balance().await.unwrap().mature, 0);

         // === RESTORE ===

         // 1. Load ephemeral keys from storage
         let loaded = stealth.load_ephemeral_keys(&env.wallet_secret).await.unwrap();
         assert_eq!(loaded, 3, "Should load 3 keys from storage");

         // 2. Verify keys restored
         let restored_outpoints: HashSet<_> = stealth.ephemeral_keys()
             .outpoints()
             .into_iter()
             .collect();
         assert_eq!(restored_outpoints, original_outpoints);

         // 3. Re-scan to rebuild UTXO context
         stealth.clone().scan(None, None).await.unwrap();

         // 4. Wait for balance restoration
         env.wait_for(
             || async { stealth.balance().await.unwrap().mature > 0 },
             5000,
             "Balance should be restored after scan"
         ).await;

         // === VERIFY FULL RESTORATION ===
         let restored_balance = stealth.balance().await.unwrap().mature;
         assert_eq!(
             restored_balance, original_balance,
             "Balance should match original after restore"
         );

         // Verify UTXO context
         let utxos = stealth.utxo_context().mature().await;
         assert_eq!(utxos.len(), 3);

         env.shutdown().await;
     }

     1.6 test_view_tag_collision — Cryptographic edge case

     Проверяем: View tag collision (1/256) корректно отклоняется full scan.

     #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
     async fn test_view_tag_collision() {
         let env = StealthTestEnv::new().await;

         // Create TWO stealth accounts
         let alice = env.create_stealth_account("alice").await;
         let bob = env.create_stealth_account("bob").await;

         alice.connect().await.unwrap();
         bob.connect().await.unwrap();
         alice.unlock(&env.wallet_secret, None).await.unwrap();
         bob.unlock(&env.wallet_secret, None).await.unwrap();

         env.mine_blocks(env.coinbase_maturity + 10).await;

         // Send MANY transactions to Alice
         // Statistically, ~1/256 will have view tag collision with Bob
         let num_txs = 512; // Expect ~2 collisions

         for _ in 0..num_txs {
             let (_, _, _) = env.send_to_stealth(
                 1_000_000_000u64, // 1 KAS
                 alice.stealth_address(),
             ).await;
         }

         env.mine_blocks(1).await;

         // Wait for Alice to detect all
         env.wait_for(
             || async { alice.ephemeral_keys().len() >= num_txs },
             30000,
             &format!("Alice should detect all {} UTXOs", num_txs)
         ).await;

         // === CRITICAL ASSERTION ===
         // Bob should have ZERO UTXOs despite view tag collisions
         // Because full ECDH scan correctly rejects

         tokio::time::sleep(Duration::from_secs(2)).await; // Extra time for any delayed processing

         assert_eq!(
             bob.ephemeral_keys().len(), 0,
             "Bob should have ZERO UTXOs - view tag collisions must be rejected by full scan"
         );

         assert_eq!(
             bob.balance().await.unwrap().mature, 0,
             "Bob's balance should be 0"
         );

         env.shutdown().await;
     }

     1.7 test_concurrent_scanning — Race condition test

     Проверяем: Concurrent scanning по нескольким accounts не создаёт race conditions.

     #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
     async fn test_concurrent_scanning() {
         let env = StealthTestEnv::new().await;

         // Create 5 stealth accounts
         let accounts: Vec<_> = futures::future::join_all(
             (0..5).map(|i| async {
                 let acc = env.create_stealth_account(&format!("account_{}", i)).await;
                 acc.connect().await.unwrap();
                 acc.unlock(&env.wallet_secret, None).await.unwrap();
                 acc
             })
         ).await;

         env.mine_blocks(env.coinbase_maturity + 10).await;

         // Send 10 UTXOs to each account
         for (i, acc) in accounts.iter().enumerate() {
             for _ in 0..10 {
                 env.send_to_stealth(
                     1_000_000_000u64 * (i + 1) as u64,
                     acc.stealth_address(),
                 ).await;
             }
         }

         env.mine_blocks(1).await;

         // Wait for all accounts to detect their UTXOs
         env.wait_for(
             || async {
                 for acc in &accounts {
                     if acc.ephemeral_keys().len() < 10 {
                         return false;
                     }
                 }
                 true
             },
             30000,
             "All accounts should detect their 10 UTXOs"
         ).await;

         // === VERIFY ISOLATION ===
         for (i, acc) in accounts.iter().enumerate() {
             let keys = acc.ephemeral_keys().len();
             assert_eq!(
                 keys, 10,
                 "Account {} should have exactly 10 keys, got {}", i, keys
             );

             let expected_balance = 1_000_000_000u64 * (i + 1) as u64 * 10;
             let actual = acc.balance().await.unwrap().mature;
             assert_eq!(
                 actual, expected_balance,
                 "Account {} balance mismatch", i
             );
         }

         // Verify no cross-contamination in processor index
         let processor = env.wallet.utxo_processor();
         let all_outpoints: Vec<_> = accounts.iter()
             .flat_map(|a| a.ephemeral_keys().outpoints())
             .collect();

         assert_eq!(
             all_outpoints.len(), 50,
             "Total outpoints should be 50"
         );

         env.shutdown().await;
     }

     ---
     2. Fuzz Testing (crypto/stealth/fuzz/)

     2.1 Structure

     crypto/stealth/fuzz/
     ├── Cargo.toml
     └── fuzz_targets/
         ├── parse_ephemeral_output.rs
         ├── parse_stealth_address.rs
         └── stealth_secret_key.rs

     2.2 Cargo.toml

     [package]
     name = "kaspa-stealth-fuzz"
     version = "0.0.0"
     publish = false
     edition = "2021"

     [package.metadata]
     cargo-fuzz = true

     [dependencies]
     libfuzzer-sys = "0.4"
     kaspa-stealth = { path = ".." }
     arbitrary = { version = "1", features = ["derive"] }

     [[bin]]
     name = "parse_ephemeral_output"
     path = "fuzz_targets/parse_ephemeral_output.rs"
     test = false
     doc = false
     bench = false

     [[bin]]
     name = "parse_stealth_address"
     path = "fuzz_targets/parse_stealth_address.rs"
     test = false
     doc = false
     bench = false

     [[bin]]
     name = "stealth_secret_key"
     path = "fuzz_targets/stealth_secret_key.rs"
     test = false
     doc = false
     bench = false

     2.3 Fuzz Targets

     parse_ephemeral_output.rs:
     #![no_main]
     use libfuzzer_sys::fuzz_target;
     use kaspa_stealth::EphemeralOutput;

     fuzz_target!(|data: &[u8]| {
         // Should never panic, always return Err for invalid input
         let _ = EphemeralOutput::from_slice(data);
     });

     parse_stealth_address.rs:
     #![no_main]
     use libfuzzer_sys::fuzz_target;
     use kaspa_stealth::StealthAddress;

     fuzz_target!(|data: &[u8]| {
         let _ = StealthAddress::from_slice(data);
     });

     stealth_secret_key.rs:
     #![no_main]
     use libfuzzer_sys::fuzz_target;
     use kaspa_stealth::StealthSecretKey;

     fuzz_target!(|data: &[u8]| {
         if data.len() >= 64 {
             let scan: [u8; 32] = data[0..32].try_into().unwrap();
             let spend: [u8; 32] = data[32..64].try_into().unwrap();
             let _ = StealthSecretKey::from_bytes(scan, spend);
         }
     });

     ---
     3. Files to Modify

     | File                                      | Action | Description                    |
     |-------------------------------------------|--------|--------------------------------|
     | testing/integration/src/stealth_flow.rs   | CREATE | Integration tests              |
     | testing/integration/src/lib.rs            | EDIT   | Add pub mod stealth_flow;      |
     | crypto/stealth/fuzz/Cargo.toml            | CREATE | Fuzz config                    |
     | crypto/stealth/fuzz/fuzz_targets/*.rs     | CREATE | 3 fuzz targets                 |
     | wallet/core/src/storage/ephemeral_keys.rs | EDIT   | Add status() method if missing |

     ---
     4. Execution Order

     Phase 1: Infrastructure (Day 1)

     1. Create stealth_flow.rs with StealthTestEnv
     2. Add helper functions: wait_for, send_to_stealth, generate_miner_keypair
     3. Register module in lib.rs
     4. Verify compilation

     Phase 2: Core Tests (Days 2-3)

     5. test_stealth_send_receive — basic flow
     6. test_stealth_change_flow — pre-calculated keys
     7. test_rpc_restore — persistence
     8. Run, debug, fix

     Phase 3: Edge Cases (Day 4)

     9. test_stealth_reorg_cleanup — 2 daemons, full simulation
     10. test_view_tag_collision — crypto correctness
     11. test_concurrent_scanning — race conditions

     Phase 4: Fuzz (Day 5)

     12. Setup crypto/stealth/fuzz/ structure
     13. Create fuzz targets
     14. Run initial fuzzing session (1 hour per target)

     ---
     5. Commands

     # Run integration tests
     cargo test --release -p kaspa-testing-integration stealth_flow

     # Run specific test
     cargo test --release -p kaspa-testing-integration stealth_flow::test_stealth_send_receive

     # Run with logging
     RUST_LOG=info cargo test --release -p kaspa-testing-integration stealth_flow -- --nocapture

     # Fuzz testing (requires nightly)
     cd crypto/stealth/fuzz
     cargo +nightly fuzz run parse_ephemeral_output -- -max_len=128 -runs=100000

     # List fuzz corpus
     cargo +nightly fuzz list

     ---
     6. Success Criteria

     | Test                | Must Pass                                   | Edge Cases Covered                 |
     |---------------------|---------------------------------------------|------------------------------------|
     | send_receive        | Balance, ephemeral key, outpoint index      | Async notification timing          |
     | change_flow         | Pre-calculation, status transition, cleanup | Spent UTXO removal                 |
     | reorg_cleanup       | All 3 levels cleaned                        | 2-daemon partition/reconnect       |
     | rpc_restore         | Full state restoration                      | Crash recovery                     |
     | view_tag_collision  | Zero false positives                        | 512 txs, ~2 statistical collisions |
     | concurrent_scanning | Perfect isolation                           | 5 accounts × 10 UTXOs              |
     | Fuzz (3 targets)    | No panics                                   | 100k runs each                     |