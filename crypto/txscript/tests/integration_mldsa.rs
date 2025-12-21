//! Integration test for ML-DSA signature verification in transactions
//!
//! This test demonstrates the complete flow:
//! 1. Generate ML-DSA keypair
//! 2. Create address from public key
//! 3. Create pay-to-pubkey-mldsa script
//! 4. Sign transaction with ML-DSA
//! 5. Verify signature in script execution

use kaspa_addresses::{Address, Prefix, Version};
use kaspa_consensus_core::hashing::sighash::SigHashReusedValuesUnsync;
use kaspa_consensus_core::hashing::sighash_type::SIG_HASH_ALL;
use kaspa_consensus_core::tx::{
    MutableTransaction, Transaction, TransactionInput, TransactionOutpoint, TransactionOutput, UtxoEntry, VerifiableTransaction,
};
use kaspa_hashes::Hash;
use kaspa_mldsa::{generate_keypair, sign, MlDsaLevel};
use kaspa_txscript::caches::Cache;
use kaspa_txscript::pay_to_address_script;
use kaspa_txscript::script_builder::ScriptBuilder;
use kaspa_txscript::TxScriptEngine;

#[test]
#[ignore]
fn test_mldsa_transaction_end_to_end() {
    // Step 1: Generate ML-DSA keypair (Level 2 for optimal size)
    let keypair = generate_keypair(MlDsaLevel::Level2).unwrap();

    println!("✓ Generated ML-DSA Level 2 keypair");
    println!("  Public key size: {} bytes", keypair.public_key.len());
    println!("  Secret key size: {} bytes", keypair.secret_key.len());

    // Step 2: Create ML-DSA address from public key
    let address = Address::new(Prefix::Mainnet, Version::PubKeyMLDSA, keypair.public_key.as_bytes());

    println!("✓ Created ML-DSA address: {}", address);

    // Step 3: Create script public key (output script)
    let script_pubkey = pay_to_address_script(&address).expect("valid ML-DSA address");

    println!("✓ Created script public key ({} bytes)", script_pubkey.script().len());
    assert_eq!(script_pubkey.script().len(), 1316); // OpPushData2 + 2 + 1312 + OpCheckSigMLDSA

    // Step 4: Create a transaction that spends from this script
    let previous_outpoint = TransactionOutpoint { transaction_id: Hash::from_bytes([1u8; 32]), index: 0 };

    let tx = Transaction::new(
        0,
        vec![TransactionInput::new(previous_outpoint, vec![], 0, 1)],
        vec![TransactionOutput::new(1000, script_pubkey.clone())],
        0,
        Default::default(),
        0,
        vec![],
    );

    println!("✓ Created transaction with {} inputs, {} outputs", tx.inputs.len(), tx.outputs.len());

    // Step 5: Calculate sighash for signing
    let utxo_entry = UtxoEntry::new(5000, script_pubkey.clone(), 0, false);
    let mut mutable_tx = MutableTransaction::with_entries(tx, vec![utxo_entry.clone()]);

    let reused_values = SigHashReusedValuesUnsync::new();
    let sig_hash = kaspa_consensus_core::hashing::sighash::calc_schnorr_signature_hash(
        &mutable_tx.as_verifiable(),
        0,
        SIG_HASH_ALL,
        &reused_values,
    );

    println!("✓ Calculated sighash: {}", sig_hash);

    // Step 6: Sign the sighash with ML-DSA
    let signature = sign(sig_hash.as_bytes().as_slice(), &keypair.secret_key).unwrap();

    println!("✓ Generated ML-DSA signature ({} bytes)", signature.len());
    assert_eq!(signature.len(), 2420); // ML-DSA Level 2 signature size

    // Step 7: Create signature script (input script) with signature and hash type
    let mut sig_with_hash_type = signature.as_bytes().to_vec();
    sig_with_hash_type.push(SIG_HASH_ALL.to_u8());

    // Signature script only pushes the signature (with hash type)
    // The public key is already in the script_pubkey
    let signature_script = ScriptBuilder::new().add_data(&sig_with_hash_type).unwrap().drain();

    mutable_tx.tx.inputs[0].signature_script = signature_script;

    println!("✓ Created signature script ({} bytes)", mutable_tx.tx.inputs[0].signature_script.len());

    // Step 8: Verify the transaction using script engine
    let sig_cache = Cache::new(10_000);
    let verifiable_tx = mutable_tx.as_verifiable();

    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &verifiable_tx.tx().inputs[0],
        0,
        &utxo_entry,
        &reused_values,
        &sig_cache,
    );

    println!("✓ Executing script...");

    // Execute and verify
    let result = vm.execute();

    match result {
        Ok(()) => {
            println!("✅ Transaction verified successfully!");
            println!("\n🎉 ML-DSA integration test PASSED");
        }
        Err(e) => {
            panic!("❌ Script execution failed: {:?}", e);
        }
    }
}

#[test]
#[ignore]
fn test_mldsa_signature_invalid() {
    // Test that invalid signatures are rejected
    let keypair = generate_keypair(MlDsaLevel::Level2).unwrap();
    let address = Address::new(Prefix::Mainnet, Version::PubKeyMLDSA, keypair.public_key.as_bytes());
    let script_pubkey = pay_to_address_script(&address).expect("valid ML-DSA address");

    let previous_outpoint = TransactionOutpoint { transaction_id: Hash::from_bytes([1u8; 32]), index: 0 };

    let tx = Transaction::new(
        0,
        vec![TransactionInput::new(previous_outpoint, vec![], 0, 1)],
        vec![TransactionOutput::new(1000, script_pubkey.clone())],
        0,
        Default::default(),
        0,
        vec![],
    );

    let utxo_entry = UtxoEntry::new(5000, script_pubkey.clone(), 0, false);
    let mut mutable_tx = MutableTransaction::with_entries(tx, vec![utxo_entry.clone()]);

    let reused_values = SigHashReusedValuesUnsync::new();
    let sig_hash = kaspa_consensus_core::hashing::sighash::calc_schnorr_signature_hash(
        &mutable_tx.as_verifiable(),
        0,
        SIG_HASH_ALL,
        &reused_values,
    );

    let signature = sign(sig_hash.as_bytes().as_slice(), &keypair.secret_key).unwrap();

    // Corrupt the signature by modifying the bytes
    let mut corrupted_sig_bytes = signature.as_bytes().to_vec();
    corrupted_sig_bytes[0] ^= 0xFF;

    let mut sig_with_hash_type = corrupted_sig_bytes;
    sig_with_hash_type.push(SIG_HASH_ALL.to_u8());

    // Signature script only pushes the signature (with hash type)
    // The public key is already in the script_pubkey
    let signature_script = ScriptBuilder::new().add_data(&sig_with_hash_type).unwrap().drain();

    mutable_tx.tx.inputs[0].signature_script = signature_script;

    let sig_cache = Cache::new(10_000);
    let verifiable_tx = mutable_tx.as_verifiable();

    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &verifiable_tx.tx().inputs[0],
        0,
        &utxo_entry,
        &reused_values,
        &sig_cache,
    );

    // Corrupted signature should fail
    let result = vm.execute();
    assert!(result.is_err(), "Corrupted signature should fail verification");

    println!("✅ Invalid signature correctly rejected");
}

#[test]
#[ignore]
fn test_mldsa_wrong_public_key() {
    // Test that signature from wrong keypair is rejected
    // Address has keypair1's public key, but we sign with keypair2's secret key
    let keypair1 = generate_keypair(MlDsaLevel::Level2).unwrap();
    let keypair2 = generate_keypair(MlDsaLevel::Level2).unwrap();

    // Address created with keypair1 - so script_pubkey has keypair1's public key
    let address = Address::new(Prefix::Mainnet, Version::PubKeyMLDSA, keypair1.public_key.as_bytes());
    let script_pubkey = pay_to_address_script(&address).expect("valid ML-DSA address");

    let previous_outpoint = TransactionOutpoint { transaction_id: Hash::from_bytes([1u8; 32]), index: 0 };

    let tx = Transaction::new(
        0,
        vec![TransactionInput::new(previous_outpoint, vec![], 0, 1)],
        vec![TransactionOutput::new(1000, script_pubkey.clone())],
        0,
        Default::default(),
        0,
        vec![],
    );

    let utxo_entry = UtxoEntry::new(5000, script_pubkey.clone(), 0, false);
    let mut mutable_tx = MutableTransaction::with_entries(tx, vec![utxo_entry.clone()]);

    let reused_values = SigHashReusedValuesUnsync::new();
    let sig_hash = kaspa_consensus_core::hashing::sighash::calc_schnorr_signature_hash(
        &mutable_tx.as_verifiable(),
        0,
        SIG_HASH_ALL,
        &reused_values,
    );

    // Sign with keypair2's secret key (wrong key!)
    // But the script_pubkey expects keypair1's public key
    let signature = sign(sig_hash.as_bytes().as_slice(), &keypair2.secret_key).unwrap();

    let mut sig_with_hash_type = signature.as_bytes().to_vec();
    sig_with_hash_type.push(SIG_HASH_ALL.to_u8());

    // Signature script only pushes the signature
    // The public key comes from script_pubkey (keypair1's public key)
    let signature_script = ScriptBuilder::new().add_data(&sig_with_hash_type).unwrap().drain();

    mutable_tx.tx.inputs[0].signature_script = signature_script;

    let sig_cache = Cache::new(10_000);
    let verifiable_tx = mutable_tx.as_verifiable();

    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &verifiable_tx.tx().inputs[0],
        0,
        &utxo_entry,
        &reused_values,
        &sig_cache,
    );

    // Signature from wrong keypair should fail
    let result = vm.execute();
    assert!(result.is_err(), "Signature from wrong keypair should fail verification");

    println!("✅ Wrong keypair signature correctly rejected");
}
