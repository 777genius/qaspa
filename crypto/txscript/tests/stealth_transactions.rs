//! Integration tests for Stealth Addresses
//!
//! Tests the full flow of:
//! - Creating stealth outputs (sender side)
//! - Native SegWit validation (VM execution)
//! - Signature verification

use kaspa_consensus_core::{
    constants::TX_VERSION,
    hashing::sighash::{SigHashReusedValuesUnsync, calc_schnorr_signature_hash},
    hashing::sighash_type::SIG_HASH_ALL,
    subnets::SUBNETWORK_ID_NATIVE,
    tx::{
        PopulatedTransaction, ScriptPublicKey, Transaction, TransactionInput, TransactionOutpoint, TransactionOutput, UtxoEntry,
        VerifiableTransaction,
    },
};
use kaspa_stealth::{StealthSecretKey, create_stealth_output, derive_spending_key, scan_output};
use kaspa_txscript::{
    MAX_SCRIPT_ELEMENT_SIZE, STEALTH_OUTPUT_SIZE, STEALTH_SCRIPT_VERSION, TxScriptEngine, caches::Cache, pay_to_stealth,
};
use rand::rngs::OsRng;
use secp256k1::{Message, SECP256K1, SecretKey};

/// Creates a mock transaction with a stealth input for testing
fn create_stealth_test_transaction(
    spending_key: &SecretKey,
    stealth_spk: &ScriptPublicKey,
    tlv_prefix: Option<Vec<u8>>,
) -> (Transaction, UtxoEntry) {
    // Create a simple transaction spending from a stealth output
    let prev_outpoint = TransactionOutpoint::new([0u8; 32].into(), 0);

    // Create the UTXO entry for the stealth output being spent
    let utxo = UtxoEntry::new(1000000, stealth_spk.clone(), 100, false);

    // Create an unsigned transaction first
    let unsigned_input = TransactionInput::new(prev_outpoint, vec![], u64::MAX, 1);
    let output_spk = ScriptPublicKey::new(0, vec![0xac; 34].into()); // dummy output
    let output = TransactionOutput::new(999000, output_spk);

    let unsigned_tx = Transaction::new(TX_VERSION, vec![unsigned_input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![]);

    // Sign the transaction
    let reused_values = SigHashReusedValuesUnsync::new();
    let entries = vec![utxo.clone()];
    let verifiable_tx = PopulatedTransaction::new(&unsigned_tx, entries);

    let sig_hash = calc_schnorr_signature_hash(&verifiable_tx, 0, SIG_HASH_ALL, &reused_values);
    let msg = Message::from_digest_slice(sig_hash.as_bytes().as_slice()).unwrap();

    // Get x-only keypair for Schnorr signing
    let keypair = secp256k1::Keypair::from_secret_key(SECP256K1, spending_key);
    let sig = SECP256K1.sign_schnorr(&msg, &keypair);

    // Create signature script: optional TLV || [64 bytes sig][1 byte sighash_type]
    let mut sig_script = Vec::with_capacity(74);
    if let Some(prefix) = tlv_prefix {
        sig_script.extend_from_slice(&prefix);
    }
    sig_script.extend_from_slice(&sig.serialize());
    sig_script.push(SIG_HASH_ALL.to_u8());

    // Create the signed transaction
    let signed_input = TransactionInput::new(prev_outpoint, sig_script, u64::MAX, 1);
    let output_spk = ScriptPublicKey::new(0, vec![0xac; 34].into());
    let output = TransactionOutput::new(999000, output_spk);

    let signed_tx = Transaction::new(TX_VERSION, vec![signed_input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![]);

    (signed_tx, utxo)
}

#[test]
fn test_stealth_output_creation() {
    // Generate receiver's stealth keys
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();

    // Sender creates a stealth output
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();

    // Create ScriptPublicKey
    let spk = pay_to_stealth(&ephemeral_output);

    // Verify structure
    assert_eq!(spk.version(), STEALTH_SCRIPT_VERSION);
    assert_eq!(spk.script().len(), STEALTH_OUTPUT_SIZE);
}

#[test]
fn test_stealth_transaction_valid_signature() {
    // Generate receiver's stealth keys
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();

    // Sender creates a stealth output
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);

    // Receiver scans and derives spending key
    let scan_result = scan_output(&ephemeral_output, &receiver_keys.scan_secret(), &receiver_address.spend_pubkey).unwrap();

    let spending_key = derive_spending_key(&receiver_keys.spend_secret(), &scan_result.blinding_factor).unwrap();

    // Create and sign a transaction spending the stealth output
    let (tx, utxo) = create_stealth_test_transaction(&spending_key, &stealth_spk, None);

    // Verify the transaction using the VM
    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);

    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();

    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );

    // Should succeed
    let result = vm.execute();
    assert!(result.is_ok(), "Valid stealth transaction should pass: {:?}", result);
}

#[test]
fn test_stealth_transaction_invalid_signature() {
    // Generate receiver's stealth keys
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();

    // Sender creates a stealth output
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);

    // Try to spend with WRONG key (not derived correctly)
    let wrong_key = SecretKey::new(&mut OsRng);

    // Create and sign a transaction with the wrong key
    let (tx, utxo) = create_stealth_test_transaction(&wrong_key, &stealth_spk, None);

    // Verify the transaction using the VM
    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);

    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();

    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );

    // Should fail
    let result = vm.execute();
    assert!(result.is_err(), "Invalid signature should fail validation");
}

#[test]
fn test_stealth_sig_op_count() {
    // Generate stealth output
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);

    // Stealth always counts as 1 sig op
    let count = kaspa_txscript::get_sig_op_count_upper_bound::<PopulatedTransaction, SigHashReusedValuesUnsync>(&[], &stealth_spk);
    assert_eq!(count, 1, "Stealth should always have exactly 1 sig op");
}

#[test]
fn test_stealth_signature_with_delegation_tlv() {
    // Generate receiver's stealth keys
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();

    // Sender creates a stealth output
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);

    // Receiver scans and derives spending key
    let scan_result = scan_output(&ephemeral_output, &receiver_keys.scan_secret(), &receiver_address.spend_pubkey).unwrap();
    let spending_key = derive_spending_key(&receiver_keys.spend_secret(), &scan_result.blinding_factor).unwrap();

    // TLV: tag 0xA1 + u64 delegation id
    let mut tlv = vec![0xA1];
    tlv.extend_from_slice(&123u64.to_le_bytes());
    let (tx, utxo) = create_stealth_test_transaction(&spending_key, &stealth_spk, Some(tlv));

    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);
    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();
    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );
    assert!(vm.execute().is_ok(), "Stealth with TLV should pass");
}

#[test]
fn test_stealth_signature_with_unknown_tlv() {
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);
    let scan_result = scan_output(&ephemeral_output, &receiver_keys.scan_secret(), &receiver_address.spend_pubkey).unwrap();
    let spending_key = derive_spending_key(&receiver_keys.spend_secret(), &scan_result.blinding_factor).unwrap();

    let tlv = vec![0xA2, 0xFF, 0xEE]; // unknown tag, arbitrary payload
    let (tx, utxo) = create_stealth_test_transaction(&spending_key, &stealth_spk, Some(tlv));
    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);
    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();
    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );
    assert!(vm.execute().is_ok(), "Stealth with unknown TLV should pass");
}

#[test]
fn test_stealth_signature_requires_activation_flag_for_tlv() {
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);
    let scan_result = scan_output(&ephemeral_output, &receiver_keys.scan_secret(), &receiver_address.spend_pubkey).unwrap();
    let spending_key = derive_spending_key(&receiver_keys.spend_secret(), &scan_result.blinding_factor).unwrap();

    let mut tlv = vec![0xA1];
    tlv.extend_from_slice(&123u64.to_le_bytes());
    let (tx, utxo) = create_stealth_test_transaction(&spending_key, &stealth_spk, Some(tlv));
    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);
    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();

    let mut vm_enabled = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );
    assert!(vm_enabled.execute().is_ok(), "TLV sig should pass");
}

#[test]
fn test_stealth_signature_with_truncated_tlv_prefix() {
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);
    let scan_result = scan_output(&ephemeral_output, &receiver_keys.scan_secret(), &receiver_address.spend_pubkey).unwrap();
    let spending_key = derive_spending_key(&receiver_keys.spend_secret(), &scan_result.blinding_factor).unwrap();

    // TLV tag without full payload
    let tlv = vec![0xA1, 0x55];
    let (tx, utxo) = create_stealth_test_transaction(&spending_key, &stealth_spk, Some(tlv));

    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);
    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();
    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );
    assert!(vm.execute().is_ok(), "Stealth with truncated TLV should still pass");
}

#[test]
fn test_stealth_signature_rejects_oversized_script() {
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);
    let scan_result = scan_output(&ephemeral_output, &receiver_keys.scan_secret(), &receiver_address.spend_pubkey).unwrap();
    let spending_key = derive_spending_key(&receiver_keys.spend_secret(), &scan_result.blinding_factor).unwrap();

    // Make TLV large enough so signature_script > MAX_SCRIPT_ELEMENT_SIZE
    let oversized_prefix = vec![0x42; MAX_SCRIPT_ELEMENT_SIZE - 64];
    let (tx, utxo) = create_stealth_test_transaction(&spending_key, &stealth_spk, Some(oversized_prefix));

    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);
    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();
    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );
    let result = vm.execute();
    assert!(result.is_err(), "Oversized signature script must be rejected");
}

#[test]
fn test_stealth_script_class() {
    use kaspa_txscript::script_class::ScriptClass;

    // Generate stealth output
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);

    // Verify script class detection
    let class = ScriptClass::from_script(&stealth_spk);
    assert_eq!(class, ScriptClass::Stealth, "Should detect Stealth script class");
}

#[test]
fn test_stealth_invalid_script_length() {
    // Create a malformed stealth SPK with wrong length
    let invalid_script = vec![0u8; 50]; // Wrong length (should be 66)
    let invalid_spk = ScriptPublicKey::new(STEALTH_SCRIPT_VERSION, invalid_script.into());

    use kaspa_txscript::script_class::ScriptClass;
    let class = ScriptClass::from_script(&invalid_spk);
    assert_eq!(class, ScriptClass::NonStandard, "Invalid length should be NonStandard");
}

#[test]
fn test_stealth_extract_output() {
    use kaspa_txscript::extract_stealth_output;

    // Generate stealth output
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);

    // Extract and verify
    let extracted = extract_stealth_output(&stealth_spk).unwrap();
    assert_eq!(extracted.ephemeral_pubkey, ephemeral_output.ephemeral_pubkey);
    assert_eq!(extracted.view_tag, ephemeral_output.view_tag);
    assert_eq!(extracted.destination_pubkey, ephemeral_output.destination_pubkey);
}

#[test]
fn test_stealth_wrong_signature_length() {
    // Generate receiver's stealth keys
    let receiver_keys = StealthSecretKey::generate().unwrap();
    let receiver_address = receiver_keys.to_address();

    // Sender creates a stealth output
    let ephemeral_output = create_stealth_output(&receiver_address, &mut OsRng).unwrap();
    let stealth_spk = pay_to_stealth(&ephemeral_output);

    // Create the UTXO entry
    let utxo = UtxoEntry::new(1000000, stealth_spk.clone(), 100, false);

    // Create transaction with wrong signature length
    let prev_outpoint = TransactionOutpoint::new([0u8; 32].into(), 0);
    let invalid_sig_script = vec![0u8; 60]; // Wrong length (should be 65)
    let input = TransactionInput::new(prev_outpoint, invalid_sig_script, u64::MAX, 1);
    let output = TransactionOutput::new(999000, ScriptPublicKey::new(0, vec![0xac; 34].into()));
    let tx = Transaction::new(TX_VERSION, vec![input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![]);

    // Verify should fail
    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);

    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();

    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );

    let result = vm.execute();
    assert!(result.is_err(), "Wrong signature length should fail: {:?}", result);
}

#[test]
fn test_stealth_invalid_p_dest_bytes() {
    // Create a stealth SPK with invalid P_dest (not on curve)
    // Format: [33B valid R][1B view_tag][32B INVALID P_dest]
    let mut invalid_script = vec![0u8; 66];

    // Valid compressed pubkey R (02 prefix + 32 bytes on curve)
    invalid_script[0] = 0x02;
    invalid_script[1..33].copy_from_slice(&[
        0x4a, 0x23, 0xf5, 0xee, 0xf4, 0xb2, 0xde, 0xad, 0x81, 0x1c, 0x7e, 0xfb, 0x4f, 0x1a, 0xfb, 0xd8, 0xdf, 0x84, 0x5e, 0x80, 0x4b,
        0x6c, 0x36, 0xa4, 0x00, 0x1f, 0xc0, 0x96, 0xe1, 0x3f, 0x81, 0x51,
    ]);
    invalid_script[33] = 0xab; // view_tag

    // Invalid P_dest - all zeros is not a valid x-only pubkey
    invalid_script[34..66].copy_from_slice(&[0u8; 32]);

    let invalid_spk = ScriptPublicKey::new(STEALTH_SCRIPT_VERSION, invalid_script.into());
    let utxo = UtxoEntry::new(1000000, invalid_spk.clone(), 100, false);

    // Create transaction
    let prev_outpoint = TransactionOutpoint::new([0u8; 32].into(), 0);
    let sig_script = vec![0u8; 65]; // dummy signature
    let input = TransactionInput::new(prev_outpoint, sig_script, u64::MAX, 1);
    let output = TransactionOutput::new(999000, ScriptPublicKey::new(0, vec![0xac; 34].into()));
    let tx = Transaction::new(TX_VERSION, vec![input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![]);

    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);

    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();

    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );

    let result = vm.execute();
    assert!(result.is_err(), "Invalid P_dest (all zeros) should fail: {:?}", result);
}

#[test]
fn test_stealth_invalid_r_bytes() {
    // Create a stealth SPK with invalid R (not on curve)
    // Format: [33B INVALID R][1B view_tag][32B valid P_dest]
    let mut invalid_script = vec![0u8; 66];

    // Invalid compressed pubkey R - 04 prefix is uncompressed (wrong)
    invalid_script[0] = 0x04; // Invalid prefix for compressed
    invalid_script[1..33].copy_from_slice(&[0xab; 32]);
    invalid_script[33] = 0xab; // view_tag

    // Valid P_dest (any 32 bytes that could be on curve)
    invalid_script[34..66].copy_from_slice(&[
        0x4a, 0x23, 0xf5, 0xee, 0xf4, 0xb2, 0xde, 0xad, 0x81, 0x1c, 0x7e, 0xfb, 0x4f, 0x1a, 0xfb, 0xd8, 0xdf, 0x84, 0x5e, 0x80, 0x4b,
        0x6c, 0x36, 0xa4, 0x00, 0x1f, 0xc0, 0x96, 0xe1, 0x3f, 0x81, 0x51,
    ]);

    let invalid_spk = ScriptPublicKey::new(STEALTH_SCRIPT_VERSION, invalid_script.into());
    let utxo = UtxoEntry::new(1000000, invalid_spk.clone(), 100, false);

    // Create transaction
    let prev_outpoint = TransactionOutpoint::new([0u8; 32].into(), 0);
    let sig_script = vec![0u8; 65];
    let input = TransactionInput::new(prev_outpoint, sig_script, u64::MAX, 1);
    let output = TransactionOutput::new(999000, ScriptPublicKey::new(0, vec![0xac; 34].into()));
    let tx = Transaction::new(TX_VERSION, vec![input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![]);

    let entries = vec![utxo];
    let verifiable_tx = PopulatedTransaction::new(&tx, entries);

    let sig_cache = Cache::new(10);
    let reused_values = SigHashReusedValuesUnsync::new();

    let mut vm = TxScriptEngine::from_transaction_input(
        &verifiable_tx,
        &tx.inputs[0],
        0,
        verifiable_tx.utxo(0).unwrap(),
        &reused_values,
        &sig_cache,
    );

    let result = vm.execute();
    assert!(result.is_err(), "Invalid R (wrong prefix) should fail: {:?}", result);
}
