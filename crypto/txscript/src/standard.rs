use crate::{
    opcodes::codes::{OpBlake2b, OpCheckSig, OpCheckSigECDSA, OpCheckSigMLDSA, OpData32, OpData33, OpEqual, OpPushData2},
    script_builder::{ScriptBuilder, ScriptBuilderResult},
    script_class::ScriptClass,
    STEALTH_OUTPUT_SIZE, STEALTH_SCRIPT_VERSION,
};
use blake2b_simd::Params;
use kaspa_addresses::{Address, Prefix, Version};
use kaspa_consensus_core::tx::{ScriptPublicKey, ScriptVec};
use kaspa_stealth::EphemeralOutput;
use kaspa_txscript_errors::TxScriptError;
use smallvec::SmallVec;
use std::iter::once;

mod multisig;

pub use multisig::{multisig_redeem_script, multisig_redeem_script_ecdsa, Error as MultisigCreateError};

/// Creates a new script to pay a transaction output to a 32-byte pubkey.
fn pay_to_pub_key(address_payload: &[u8]) -> Result<ScriptVec, TxScriptError> {
    // TODO: use ScriptBuilder when add_op and add_data fns or equivalents are available
    if address_payload.len() != 32 {
        return Err(TxScriptError::InvalidPublicKeyLen(address_payload.len()));
    }
    Ok(SmallVec::from_iter(once(OpData32).chain(address_payload.iter().copied()).chain(once(OpCheckSig))))
}

/// Creates a new script to pay a transaction output to a 33-byte ECDSA pubkey.
fn pay_to_pub_key_ecdsa(address_payload: &[u8]) -> Result<ScriptVec, TxScriptError> {
    // TODO: use ScriptBuilder when add_op and add_data fns or equivalents are available
    if address_payload.len() != 33 {
        return Err(TxScriptError::InvalidPublicKeyLen(address_payload.len()));
    }
    Ok(SmallVec::from_iter(once(OpData33).chain(address_payload.iter().copied()).chain(once(OpCheckSigECDSA))))
}

/// Creates a new script to pay a transaction output to a 1312-byte ML-DSA pubkey.
fn pay_to_pub_key_mldsa(address_payload: &[u8]) -> Result<ScriptVec, TxScriptError> {
    // TODO: use ScriptBuilder when add_op and add_data fns or equivalents are available
    if address_payload.len() != 1312 {
        return Err(TxScriptError::InvalidPublicKeyLen(address_payload.len()));
    }
    // OpPushData2 + length (1312 = 0x0520 in little-endian) + data + OpCheckSigMLDSA
    Ok(SmallVec::from_iter(
        once(OpPushData2)
            .chain(once(0x20)) // Low byte of 1312
            .chain(once(0x05)) // High byte of 1312
            .chain(address_payload.iter().copied())
            .chain(once(OpCheckSigMLDSA)),
    ))
}

/// Creates a new script to pay a transaction output to a script hash.
/// It is expected that the input is a valid hash.
fn pay_to_script_hash(script_hash: &[u8]) -> Result<ScriptVec, TxScriptError> {
    // TODO: use ScriptBuilder when add_op and add_data fns or equivalents are available
    if script_hash.len() != 32 {
        return Err(TxScriptError::InvalidPublicKeyLen(script_hash.len()));
    }
    Ok(SmallVec::from_iter([OpBlake2b, OpData32].iter().copied().chain(script_hash.iter().copied()).chain(once(OpEqual))))
}

/// Creates a new script to pay a transaction output to a stealth address.
/// Format: [33 bytes R (ephemeral pubkey)][1 byte view_tag][32 bytes P_dest (x-only)]
///
/// This is a Native SegWit style script - no opcodes, direct Schnorr verification.
fn pay_to_stealth_output(output: &EphemeralOutput) -> ScriptVec {
    SmallVec::from_slice(&output.to_bytes())
}

/// Creates a new script to pay a transaction output to the specified address.
///
/// Note: For stealth addresses (Version::Stealth), use `pay_to_stealth` instead,
/// as stealth outputs require the ephemeral key data, not just the address payload.
pub fn pay_to_address_script(address: &Address) -> Result<ScriptPublicKey, TxScriptError> {
    let script = match address.version {
        Version::PubKey => pay_to_pub_key(address.payload.as_slice())?,
        Version::PubKeyECDSA => pay_to_pub_key_ecdsa(address.payload.as_slice())?,
        Version::PubKeyMLDSA => pay_to_pub_key_mldsa(address.payload.as_slice())?,
        Version::ScriptHash => pay_to_script_hash(address.payload.as_slice())?,
        Version::Stealth => return Err(TxScriptError::PubKeyFormat),
    };
    Ok(ScriptPublicKey::new(ScriptClass::from(address.version).version(), script))
}

/// Creates a ScriptPublicKey for a stealth output.
///
/// This creates the Native SegWit style script used for stealth transactions.
/// The script contains the ephemeral public key R, view tag, and destination pubkey P_dest.
///
/// # Arguments
///
/// * `output` - The ephemeral output data from `kaspa_stealth::create_stealth_output`
///
/// # Returns
///
/// A ScriptPublicKey with version STEALTH_SCRIPT_VERSION (16) containing the stealth output data.
pub fn pay_to_stealth(output: &EphemeralOutput) -> ScriptPublicKey {
    ScriptPublicKey::new(STEALTH_SCRIPT_VERSION, pay_to_stealth_output(output))
}

/// Extracts the EphemeralOutput from a stealth ScriptPublicKey.
///
/// # Arguments
///
/// * `spk` - A ScriptPublicKey that should be a stealth output
///
/// # Returns
///
/// The EphemeralOutput containing R, view_tag, and P_dest, or an error if invalid.
pub fn extract_stealth_output(spk: &ScriptPublicKey) -> Result<EphemeralOutput, TxScriptError> {
    if spk.version() != STEALTH_SCRIPT_VERSION {
        return Err(TxScriptError::PubKeyFormat);
    }
    if spk.script().len() != STEALTH_OUTPUT_SIZE {
        return Err(TxScriptError::PubKeyFormat);
    }
    EphemeralOutput::from_slice(spk.script()).map_err(|_| TxScriptError::PubKeyFormat)
}

/// Takes a script and returns an equivalent pay-to-script-hash script
pub fn pay_to_script_hash_script(redeem_script: &[u8]) -> ScriptPublicKey {
    let redeem_script_hash = Params::new().hash_length(32).to_state().update(redeem_script).finalize();
    // `redeem_script_hash` is always 32 bytes
    let script = SmallVec::from_iter(
        [OpBlake2b, OpData32].iter().copied().chain(redeem_script_hash.as_bytes().iter().copied()).chain(once(OpEqual)),
    );
    ScriptPublicKey::new(ScriptClass::ScriptHash.version(), script)
}

/// Generates a signature script that fits a pay-to-script-hash script
pub fn pay_to_script_hash_signature_script(redeem_script: Vec<u8>, signature: Vec<u8>) -> ScriptBuilderResult<Vec<u8>> {
    let redeem_script_as_data = ScriptBuilder::new().add_data(&redeem_script)?.drain();
    Ok(Vec::from_iter(signature.iter().copied().chain(redeem_script_as_data.iter().copied())))
}

/// Returns the address encoded in a script public key.
///
/// Notes:
///  - This function only works for 'standard' transaction script types.
///    Any data such as public keys which are invalid will return the
///    `TxScriptError::PubKeyFormat` error.
///
///  - In case a ScriptClass is needed by the caller, call `ScriptClass::from(address.version)`
///    or use `address.version` directly instead, where address is the successfully
///    returned address.
pub fn extract_script_pub_key_address(script_public_key: &ScriptPublicKey, prefix: Prefix) -> Result<Address, TxScriptError> {
    let class = ScriptClass::from_script(script_public_key);
    if script_public_key.version() > class.version() {
        return Err(TxScriptError::PubKeyFormat);
    }
    let script = script_public_key.script();
    match class {
        ScriptClass::NonStandard => Err(TxScriptError::PubKeyFormat),
        ScriptClass::PubKey => Ok(Address::new(prefix, Version::PubKey, &script[1..33])),
        ScriptClass::PubKeyECDSA => Ok(Address::new(prefix, Version::PubKeyECDSA, &script[1..34])),
        ScriptClass::PubKeyMLDSA => Ok(Address::new(prefix, Version::PubKeyMLDSA, &script[3..1315])), // Skip OpPushData2 + 2 length bytes
        ScriptClass::ScriptHash => Ok(Address::new(prefix, Version::ScriptHash, &script[2..34])),
        ScriptClass::Stealth => {
            // Stealth ScriptPublicKeys don't directly map to an address - they contain
            // ephemeral data (R, view_tag, P_dest) specific to a single output.
            // Use extract_stealth_output() to get the ephemeral data instead.
            Err(TxScriptError::PubKeyFormat)
        }
    }
}

pub mod test_helpers {
    use super::*;
    use crate::{opcodes::codes::OpTrue, MAX_TX_IN_SEQUENCE_NUM};
    use kaspa_consensus_core::{
        constants::TX_VERSION,
        subnets::SUBNETWORK_ID_NATIVE,
        tx::{Transaction, TransactionInput, TransactionOutpoint, TransactionOutput},
    };

    /// Returns a P2SH script paying to an anyone-can-spend address,
    /// The second return value is a redeemScript to be used with txscript.pay_to_script_hash_signature_script
    pub fn op_true_script() -> (ScriptPublicKey, Vec<u8>) {
        let redeem_script = vec![OpTrue];
        let script_public_key = pay_to_script_hash_script(&redeem_script);
        (script_public_key, redeem_script)
    }

    /// Creates a transaction that spends the first output of provided transaction.
    /// Assumes that the output being spent has opTrueScript as its scriptPublicKey.
    /// Creates the value of the spent output minus provided `fee` (in sompi).
    pub fn create_transaction(tx_to_spend: &Transaction, fee: u64) -> Transaction {
        let (script_public_key, redeem_script) = op_true_script();
        let signature_script = pay_to_script_hash_signature_script(redeem_script, vec![]).expect("the script is canonical");
        let previous_outpoint = TransactionOutpoint::new(tx_to_spend.id(), 0);
        let input = TransactionInput::new(previous_outpoint, signature_script, MAX_TX_IN_SEQUENCE_NUM, 1);
        let output = TransactionOutput::new(tx_to_spend.outputs[0].value - fee, script_public_key);
        Transaction::new(TX_VERSION, vec![input], vec![output], 0, SUBNETWORK_ID_NATIVE, 0, vec![])
    }

    /// Creates a transaction that spends the outputs of specified indexes (if they exist) of every provided transaction and returns an optional change.
    /// Assumes that the outputs being spent have opTrueScript as their scriptPublicKey.
    ///
    /// If some change is provided, creates two outputs, first one with the value of the spent outputs minus `change`
    /// and `fee` (in sompi) and second one of `change` amount.
    ///
    /// If no change is provided, creates only one output with the value of the spent outputs minus and `fee` (in sompi)
    pub fn create_transaction_with_change<'a>(
        txs_to_spend: impl Iterator<Item = &'a Transaction>,
        output_indexes: Vec<usize>,
        change: Option<u64>,
        fee: u64,
    ) -> Transaction {
        let (script_public_key, redeem_script) = op_true_script();
        let signature_script = pay_to_script_hash_signature_script(redeem_script, vec![]).expect("the script is canonical");
        let mut inputs_value: u64 = 0;
        let mut inputs = vec![];
        for tx_to_spend in txs_to_spend {
            for i in output_indexes.iter().copied() {
                if i < tx_to_spend.outputs.len() {
                    let previous_outpoint = TransactionOutpoint::new(tx_to_spend.id(), i as u32);
                    inputs.push(TransactionInput::new(previous_outpoint, signature_script.clone(), MAX_TX_IN_SEQUENCE_NUM, 1));
                    inputs_value += tx_to_spend.outputs[i].value;
                }
            }
        }
        let outputs = match change {
            Some(change) => vec![
                TransactionOutput::new(inputs_value - fee - change, script_public_key.clone()),
                TransactionOutput::new(change, script_public_key),
            ],
            None => vec![TransactionOutput::new(inputs_value - fee, script_public_key.clone())],
        };
        Transaction::new(TX_VERSION, inputs, outputs, 0, SUBNETWORK_ID_NATIVE, 0, vec![])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_address_and_encode_script() {
        struct Test {
            name: &'static str,
            script_pub_key: ScriptPublicKey,
            prefix: Prefix,
            expected_address: Result<Address, TxScriptError>,
        }

        // cspell:disable
        let tests = vec![
            Test {
                name: "Mainnet PubKey script and address",
                script_pub_key: ScriptPublicKey::new(
                    ScriptClass::PubKey.version(),
                    ScriptVec::from_slice(
                        &hex::decode("207bc04196f1125e4f2676cd09ed14afb77223b1f62177da5488346323eaa91a69ac").unwrap(),
                    ),
                ),
                prefix: Prefix::Mainnet,
                expected_address: Ok("kaspa:qpauqsvk7yf9unexwmxsnmg547mhyga37csh0kj53q6xxgl24ydxjsgzthw5j".try_into().unwrap()),
            },
            Test {
                name: "Testnet PubKeyECDSA script and address",
                script_pub_key: ScriptPublicKey::new(
                    ScriptClass::PubKeyECDSA.version(),
                    ScriptVec::from_slice(
                        &hex::decode("21ba01fc5f4e9d9879599c69a3dafdb835a7255e5f2e934e9322ecd3af190ab0f60eab").unwrap(),
                    ),
                ),
                prefix: Prefix::Testnet,
                expected_address: Ok("kaspatest:qxaqrlzlf6wes72en3568khahq66wf27tuhfxn5nytkd8tcep2c0vrse6gdmpks".try_into().unwrap()),
            },
            Test {
                name: "Testnet non standard script",
                script_pub_key: ScriptPublicKey::new(
                    ScriptClass::PubKey.version(),
                    ScriptVec::from_slice(
                        &hex::decode("2001fc5f4e9d9879599c69a3dafdb835a7255e5f2e934e9322ecd3af190ab0f60eab").unwrap(),
                    ),
                ),
                prefix: Prefix::Testnet,
                expected_address: Err(TxScriptError::PubKeyFormat),
            },
            Test {
                name: "Mainnet script with unknown version",
                script_pub_key: ScriptPublicKey::new(
                    ScriptClass::PubKey.version() + 1,
                    ScriptVec::from_slice(
                        &hex::decode("207bc04196f1125e4f2676cd09ed14afb77223b1f62177da5488346323eaa91a69ac").unwrap(),
                    ),
                ),
                prefix: Prefix::Mainnet,
                expected_address: Err(TxScriptError::PubKeyFormat),
            },
        ];
        // cspell:enable

        for test in tests {
            let extracted = extract_script_pub_key_address(&test.script_pub_key, test.prefix);
            assert_eq!(extracted, test.expected_address, "extract address test failed for '{}'", test.name);
            if let Ok(ref address) = extracted {
                let encoded = pay_to_address_script(address).unwrap();
                assert_eq!(encoded, test.script_pub_key, "encode public key script test failed for '{}'", test.name);
            }
        }
    }

    #[test]
    fn pay_to_address_script_rejects_stealth_addresses() {
        let stealth = Address::new(Prefix::StealthTestnet, Version::Stealth, &[7u8; 64]);
        assert_eq!(pay_to_address_script(&stealth), Err(TxScriptError::PubKeyFormat));
    }

    #[test]
    fn pay_to_address_script_rejects_invalid_payload_len_instead_of_panicking() {
        let invalid = Address {
            prefix: Prefix::Mainnet,
            version: Version::PubKey,
            payload: kaspa_addresses::PayloadVec::from_slice(&[1u8; 31]),
        };
        assert_eq!(pay_to_address_script(&invalid), Err(TxScriptError::InvalidPublicKeyLen(31)));
    }
}
