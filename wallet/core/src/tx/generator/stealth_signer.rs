//!
//! Stealth transaction signer.
//!
//! Signs stealth inputs using ephemeral keys retrieved from an EphemeralKeyProvider.
//!

use crate::error::Error;
use crate::result::Result;
use crate::storage::EphemeralKeyData;
use async_trait::async_trait;
use kaspa_consensus_core::hashing::sighash::{calc_schnorr_signature_hash, SigHashReusedValuesUnsync};
use kaspa_consensus_core::hashing::sighash_type::SIG_HASH_ALL;
use kaspa_consensus_core::sign::Signed;
use kaspa_consensus_core::tx::{SignableTransaction, TransactionOutpoint};
use kaspa_txscript::STEALTH_SCRIPT_VERSION;
use secp256k1::{Keypair, Message, SecretKey, SECP256K1};
use std::sync::Arc;

// ============================================================================
// EPHEMERAL KEY PROVIDER TRAIT
// ============================================================================

/// Trait for retrieving ephemeral keys for stealth inputs.
///
/// This abstraction allows StealthSigner to work without direct
/// dependency on StealthAccount.
#[async_trait]
pub trait EphemeralKeyProvider: Send + Sync {
    /// Retrieves the ephemeral key data for a given outpoint.
    async fn get_ephemeral_key(&self, outpoint: &TransactionOutpoint) -> Option<EphemeralKeyData>;

    /// Retrieves the ephemeral key data with optional delegation id metadata.
    /// Default implementation falls back to key-only.
    async fn get_ephemeral_entry(&self, outpoint: &TransactionOutpoint) -> Option<(EphemeralKeyData, Option<u64>)> {
        self.get_ephemeral_key(outpoint).await.map(|k| (k, None))
    }
}

/// Type alias for dynamic ephemeral key provider
pub type DynEphemeralKeyProvider = Arc<dyn EphemeralKeyProvider + 'static>;

// ============================================================================
// STEALTH SIGNER
// ============================================================================

/// Signer for stealth transactions.
///
/// Unlike the standard Signer which derives keys from addresses,
/// StealthSigner retrieves pre-computed spending keys from an
/// EphemeralKeyProvider (typically an EphemeralKeyStore).
pub struct StealthSigner {
    key_provider: DynEphemeralKeyProvider,
    strict_mixed_inputs: bool,
}

impl StealthSigner {
    /// Creates a new StealthSigner with the given key provider.
    pub fn new(key_provider: DynEphemeralKeyProvider) -> Self {
        Self { key_provider, strict_mixed_inputs: true }
    }

    /// Enables or disables strict mode for mixed inputs detection.
    /// When enabled (default), the signer returns an error if stealth and non-stealth inputs are mixed.
    pub fn with_strict_mode(mut self, strict: bool) -> Self {
        self.strict_mixed_inputs = strict;
        self
    }

    /// Signs all stealth inputs in the transaction.
    ///
    /// Non-stealth inputs are skipped and should be signed by the standard signer.
    /// Returns `Signed::Fully` if all inputs were signed, `Signed::Partially` otherwise.
    pub async fn sign(&self, mut tx: SignableTransaction, include_delegation_id: bool) -> Result<Signed> {
        let mut additional_signatures_required = false;
        let reused_values = SigHashReusedValuesUnsync::new();
        let num_inputs = tx.tx.inputs.len();
        let mut has_stealth_inputs = false;
        let mut has_non_stealth_inputs = false;

        for idx in 0..num_inputs {
            let utxo_entry = tx.entries[idx].as_ref().ok_or(Error::MissingUtxoEntry(idx))?;

            let script_version = utxo_entry.script_public_key.version();

            if script_version != STEALTH_SCRIPT_VERSION {
                has_non_stealth_inputs = true;
                // Not a stealth input - skip (will be signed by standard signer)
                if tx.tx.inputs[idx].signature_script.is_empty() {
                    additional_signatures_required = true;
                }
                continue;
            }

            has_stealth_inputs = true;

            // Get outpoint for this input
            let outpoint = tx.tx.inputs[idx].previous_outpoint;

            // Retrieve spending key from ephemeral store (with delegation metadata if available)
            let fallback = self.key_provider.get_ephemeral_key(&outpoint).await.map(|k| (k, None));
            let (key_data, delegation_id) =
                self.key_provider.get_ephemeral_entry(&outpoint).await.or(fallback).ok_or(Error::EphemeralKeyNotFound(outpoint))?;

            // Get spending secret bytes
            let spending_secret_bytes =
                key_data.spending_secret_bytes().ok_or_else(|| Error::Custom("Invalid spending secret length".into()))?;

            // Reconstruct secret key
            let spending_secret =
                SecretKey::from_slice(&spending_secret_bytes).map_err(|e| Error::Custom(format!("Invalid secret key: {}", e)))?;
            let keypair = Keypair::from_secret_key(SECP256K1, &spending_secret);

            // Calculate sighash
            let sighash = calc_schnorr_signature_hash(&tx.as_verifiable(), idx, SIG_HASH_ALL, &reused_values);

            // Sign
            let message = Message::from_digest_slice(sighash.as_bytes().as_slice())
                .map_err(|e| Error::Custom(format!("Invalid message: {}", e)))?;
            let signature = SECP256K1.sign_schnorr(&message, &keypair);

            // Format signature script: optional TLV + [64 bytes sig][1 byte sighash_type]
            // Note: NO OP_DATA_65 prefix for Native SegWit style (stealth)
            let mut sig_script = Vec::with_capacity(74);
            if include_delegation_id {
                if let Some(id) = delegation_id {
                    sig_script.push(0xA1);
                    sig_script.extend_from_slice(&id.to_le_bytes());
                }
            }
            sig_script.extend_from_slice(&signature.serialize());
            sig_script.push(SIG_HASH_ALL.to_u8());

            tx.tx.inputs[idx].signature_script = sig_script;
        }

        if self.strict_mixed_inputs && has_stealth_inputs && has_non_stealth_inputs {
            return Err(Error::MixedStealthAndLegacyInputsNotAllowed);
        }

        if additional_signatures_required {
            Ok(Signed::Partially(tx))
        } else {
            Ok(Signed::Fully(tx))
        }
    }
}

// ============================================================================
// TESTS
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use kaspa_addresses::Version;
    use kaspa_consensus_core::constants::MAX_TX_IN_SEQUENCE_NUM;
    use kaspa_consensus_core::subnets::SUBNETWORK_ID_NATIVE;
    use kaspa_consensus_core::tx::{ScriptPublicKey, Transaction, TransactionInput, TransactionOutput, UtxoEntry};
    use kaspa_hashes::Hash;
    use kaspa_stealth::{create_stealth_output_with_blinding, derive_spending_key, StealthSecretKey};
    use kaspa_txscript::pay_to_stealth;
    use secp256k1::rand::rngs::OsRng;

    struct MockKeyProvider {
        keys: std::collections::HashMap<TransactionOutpoint, (EphemeralKeyData, Option<u64>)>,
    }

    impl MockKeyProvider {
        fn new() -> Self {
            Self { keys: std::collections::HashMap::new() }
        }

        fn add_key_with_delegation(&mut self, outpoint: TransactionOutpoint, data: EphemeralKeyData, delegation_id: Option<u64>) {
            self.keys.insert(outpoint, (data, delegation_id));
        }
    }

    #[async_trait]
    impl EphemeralKeyProvider for MockKeyProvider {
        async fn get_ephemeral_key(&self, outpoint: &TransactionOutpoint) -> Option<EphemeralKeyData> {
            self.keys.get(outpoint).map(|(data, _)| data.clone())
        }

        async fn get_ephemeral_entry(&self, outpoint: &TransactionOutpoint) -> Option<(EphemeralKeyData, Option<u64>)> {
            self.keys.get(outpoint).cloned()
        }
    }

    fn build_stealth_signer_with_tx(delegation_id: Option<u64>) -> (StealthSigner, SignableTransaction) {
        let receiver_keys = StealthSecretKey::generate().unwrap();
        let receiver_address = receiver_keys.to_address();
        let spend_secret = receiver_keys.spend_secret();

        let (ephemeral_output, blinding_factor) = create_stealth_output_with_blinding(&receiver_address, &mut OsRng).unwrap();
        let spending_secret = derive_spending_key(&spend_secret, &blinding_factor).unwrap();

        let mut provider = MockKeyProvider::new();
        let tx_id = Hash::from_bytes([1u8; 32]);
        let outpoint = TransactionOutpoint::new(tx_id, 0);

        let key_data = EphemeralKeyData::new_xonly(
            spending_secret.secret_bytes(),
            blinding_factor.to_be_bytes(),
            ephemeral_output.destination_pubkey.serialize(),
        );
        provider.add_key_with_delegation(outpoint, key_data, delegation_id);

        let script_pubkey = pay_to_stealth(&ephemeral_output);
        let input = TransactionInput::new(outpoint, vec![], 0, 0);
        let output = TransactionOutput::new(1000, ScriptPublicKey::new(0, vec![].into()));
        let tx = Transaction::new(0, vec![input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![]);
        let utxo_entry = UtxoEntry::new(1000, script_pubkey, 100, false);
        let signable = SignableTransaction::with_entries(tx, vec![utxo_entry]);

        (StealthSigner::new(Arc::new(provider)), signable)
    }

    #[tokio::test]
    async fn test_stealth_signer_basic() {
        let (signer, signable) = build_stealth_signer_with_tx(Some(1));
        let signed = signer.sign(signable, true).await.unwrap();

        // Verify signature was added (Fully signed)
        match signed {
            Signed::Fully(tx) => {
                assert!(!tx.tx.inputs[0].signature_script.is_empty());
                assert_eq!(tx.tx.inputs[0].signature_script.len(), 74);
            }
            Signed::Partially(_) => panic!("Expected fully signed transaction"),
        }
    }

    #[tokio::test]
    async fn test_signature_script_includes_tlv_when_flag_enabled() {
        let delegation_id = 0x00A5_A5EE_u64;
        let (signer, signable) = build_stealth_signer_with_tx(Some(delegation_id));
        let signed = signer.sign(signable, true).await.unwrap();

        let tx = match signed {
            Signed::Fully(tx) => tx,
            Signed::Partially(_) => panic!("expected fully signed transaction"),
        };
        let script = &tx.tx.inputs[0].signature_script;
        assert_eq!(script.len(), 74);
        assert_eq!(script[0], 0xA1);
        let mut id_bytes = [0u8; 8];
        id_bytes.copy_from_slice(&script[1..9]);
        assert_eq!(u64::from_le_bytes(id_bytes), delegation_id);
    }

    #[tokio::test]
    async fn test_signature_script_omits_tlv_when_disabled_or_missing_metadata() {
        // Delegation metadata present but flag disabled -> legacy format
        let (signer_with_metadata, signable_with_metadata) = build_stealth_signer_with_tx(Some(42));
        let tx = match signer_with_metadata.sign(signable_with_metadata, false).await.unwrap() {
            Signed::Fully(tx) => tx,
            Signed::Partially(_) => panic!("expected fully signed transaction"),
        };
        assert_eq!(tx.tx.inputs[0].signature_script.len(), 65);

        // Delegation metadata absent even though flag enabled -> legacy format
        let (signer_without_metadata, signable_without_metadata) = build_stealth_signer_with_tx(None);
        let tx = match signer_without_metadata.sign(signable_without_metadata, true).await.unwrap() {
            Signed::Fully(tx) => tx,
            Signed::Partially(_) => panic!("expected fully signed transaction"),
        };
        assert_eq!(tx.tx.inputs[0].signature_script.len(), 65);
    }

    #[tokio::test]
    async fn test_stealth_signer_missing_key() {
        let provider = MockKeyProvider::new();
        let signer = StealthSigner::new(Arc::new(provider));

        // Create a stealth input without providing the key
        let tx_id = Hash::from_bytes([2u8; 32]);
        let outpoint = TransactionOutpoint::new(tx_id, 0);
        let input = TransactionInput::new(outpoint, vec![], 0, 0);

        // Create a stealth ScriptPublicKey (66 bytes, version 16)
        let script_pubkey = ScriptPublicKey::new(STEALTH_SCRIPT_VERSION, vec![0u8; 66].into());
        let output = TransactionOutput::new(1000, ScriptPublicKey::new(0, vec![].into()));
        let tx = Transaction::new(0, vec![input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![]);

        let utxo_entry = UtxoEntry::new(1000, script_pubkey, 100, false);
        let signable = SignableTransaction::with_entries(tx, vec![utxo_entry]);

        // Should fail because key is missing
        let result = signer.sign(signable, true).await;
        assert!(result.is_err());
        match result {
            Err(Error::EphemeralKeyNotFound(_)) => {}
            Err(e) => panic!("Unexpected error: {:?}", e),
            Ok(_) => panic!("Expected error"),
        }
    }

    #[tokio::test]
    async fn test_stealth_signer_skips_non_stealth() {
        let provider = MockKeyProvider::new();
        let signer = StealthSigner::new(Arc::new(provider));

        // Create a regular P2PK input (version 0)
        let tx_id = Hash::from_bytes([3u8; 32]);
        let outpoint = TransactionOutpoint::new(tx_id, 0);
        let input = TransactionInput::new(outpoint, vec![], 0, 0);

        let script_pubkey = ScriptPublicKey::new(0, vec![0u8; 34].into());
        let output = TransactionOutput::new(1000, ScriptPublicKey::new(0, vec![].into()));
        let tx = Transaction::new(0, vec![input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![]);

        let utxo_entry = UtxoEntry::new(1000, script_pubkey, 100, false);
        let signable = SignableTransaction::with_entries(tx, vec![utxo_entry]);

        // Should succeed but indicate additional signatures required (Partially signed)
        let signed = signer.sign(signable, false).await.unwrap();
        match signed {
            Signed::Partially(tx) => {
                assert!(tx.tx.inputs[0].signature_script.is_empty());
            }
            Signed::Fully(_) => panic!("Expected partially signed transaction"),
        }
    }

    #[tokio::test]
    async fn test_stealth_signer_rejects_mixed_inputs_in_strict_mode() {
        let mut provider = MockKeyProvider::new();

        // Stealth outpoint + key
        let stealth_outpoint = TransactionOutpoint::new(Hash::from_u64_word(10), 0);
        let stealth_spk = ScriptPublicKey::new(STEALTH_SCRIPT_VERSION, vec![0u8; 66].into());
        let key_data = EphemeralKeyData::new([1u8; 32], [2u8; 32], [3u8; 33]);
        provider.add_key_with_delegation(stealth_outpoint, key_data, Some(1));

        // Legacy outpoint
        let legacy_outpoint = TransactionOutpoint::new(Hash::from_u64_word(11), 0);
        let legacy_spk = ScriptPublicKey::new(Version::PubKey as u16, vec![0u8; 35].into());

        // Build transaction with stealth + legacy inputs
        let tx = Transaction::new(
            0,
            vec![
                TransactionInput::new(stealth_outpoint, vec![], MAX_TX_IN_SEQUENCE_NUM, 0),
                TransactionInput::new(legacy_outpoint, vec![], MAX_TX_IN_SEQUENCE_NUM, 0),
            ],
            vec![],
            0,
            SUBNETWORK_ID_NATIVE,
            0,
            vec![],
        );

        let stealth_utxo = UtxoEntry::new(1000, stealth_spk, 0, false);
        let legacy_utxo = UtxoEntry::new(1000, legacy_spk, 0, false);
        let signable = SignableTransaction::with_entries(tx, vec![stealth_utxo, legacy_utxo]);

        let signer = StealthSigner::new(Arc::new(provider));

        let res = signer.sign(signable, false).await;
        assert!(matches!(res, Err(Error::MixedStealthAndLegacyInputsNotAllowed)));
    }
}
