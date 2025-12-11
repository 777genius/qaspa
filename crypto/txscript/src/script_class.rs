use crate::{opcodes, STEALTH_OUTPUT_SIZE, STEALTH_SCRIPT_VERSION};
use borsh::{BorshDeserialize, BorshSerialize};
use kaspa_addresses::Version;
use kaspa_consensus_core::tx::{ScriptPublicKey, ScriptPublicKeyVersion};
use serde::{Deserialize, Serialize};
use std::{
    fmt::{Display, Formatter},
    str::FromStr,
};
use thiserror::Error;

#[derive(Error, PartialEq, Eq, Debug, Clone)]
pub enum Error {
    #[error("Invalid script class {0}")]
    InvalidScriptClass(String),
}

/// Standard classes of script payment in the blockDAG
#[derive(PartialEq, Eq, Hash, Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[borsh(use_discriminant = true)]
#[repr(u8)]
pub enum ScriptClass {
    /// None of the recognized forms
    NonStandard = 0,
    /// Pay to pubkey
    PubKey,
    /// Pay to pubkey ECDSA
    PubKeyECDSA,
    /// Pay to pubkey ML-DSA (post-quantum)
    PubKeyMLDSA,
    /// Pay to script hash
    ScriptHash,
    /// Pay to stealth address (Native SegWit style)
    Stealth,
}

const NON_STANDARD: &str = "nonstandard";
const PUB_KEY: &str = "pubkey";
const PUB_KEY_ECDSA: &str = "pubkeyecdsa";
const PUB_KEY_MLDSA: &str = "pubkeymldsa";
const SCRIPT_HASH: &str = "scripthash";
const STEALTH: &str = "stealth";

impl ScriptClass {
    pub fn from_script(script_public_key: &ScriptPublicKey) -> Self {
        let script = script_public_key.script();
        let version = script_public_key.version();

        match version {
            // Standard script types (version 0)
            0 => {
                if Self::is_pay_to_pubkey(script) {
                    ScriptClass::PubKey
                } else if Self::is_pay_to_pubkey_ecdsa(script) {
                    Self::PubKeyECDSA
                } else if Self::is_pay_to_pubkey_mldsa(script) {
                    Self::PubKeyMLDSA
                } else if Self::is_pay_to_script_hash(script) {
                    Self::ScriptHash
                } else {
                    ScriptClass::NonStandard
                }
            }
            // Stealth address scripts (Native SegWit style)
            STEALTH_SCRIPT_VERSION => {
                if Self::is_pay_to_stealth(script) {
                    ScriptClass::Stealth
                } else {
                    ScriptClass::NonStandard
                }
            }
            // Unknown version
            _ => ScriptClass::NonStandard,
        }
    }

    // Returns true if the script passed is a pay-to-pubkey
    // transaction, false otherwise.
    #[inline(always)]
    pub fn is_pay_to_pubkey(script_public_key: &[u8]) -> bool {
        (script_public_key.len() == 34) && // 2 opcodes number + 32 data
        (script_public_key[0] == opcodes::codes::OpData32) &&
        (script_public_key[33] == opcodes::codes::OpCheckSig)
    }

    // Returns returns true if the script passed is an ECDSA pay-to-pubkey
    /// transaction, false otherwise.
    #[inline(always)]
    pub fn is_pay_to_pubkey_ecdsa(script_public_key: &[u8]) -> bool {
        (script_public_key.len() == 35) && // 2 opcodes number + 33 data
        (script_public_key[0] == opcodes::codes::OpData33) &&
        (script_public_key[34] == opcodes::codes::OpCheckSigECDSA)
    }

    /// Returns true if the script passed is an ML-DSA pay-to-pubkey
    /// transaction, false otherwise.
    #[inline(always)]
    pub fn is_pay_to_pubkey_mldsa(script_public_key: &[u8]) -> bool {
        // OpPushData2 (1) + length bytes (2) + 1312 data + OpCheckSigMLDSA (1) = 1316 bytes
        (script_public_key.len() == 1316) &&
        (script_public_key[0] == opcodes::codes::OpPushData2) &&
        // Check length is 1312 (0x0520 in little-endian)
        (script_public_key[1] == 0x20) &&
        (script_public_key[2] == 0x05) &&
        (script_public_key[1315] == opcodes::codes::OpCheckSigMLDSA)
    }

    /// Returns true if the script is in the standard
    /// pay-to-script-hash (P2SH) format, false otherwise.
    #[inline(always)]
    pub fn is_pay_to_script_hash(script_public_key: &[u8]) -> bool {
        (script_public_key.len() == 35) && // 3 opcodes number + 32 data
        (script_public_key[0] == opcodes::codes::OpBlake2b) &&
        (script_public_key[1] == opcodes::codes::OpData32) &&
        (script_public_key[34] == opcodes::codes::OpEqual)
    }

    /// Returns true if the script is a pay-to-stealth format.
    /// Format: [33 bytes R][1 byte view_tag][32 bytes P_dest] = 66 bytes
    ///
    /// Note: This only checks the length. Full validation of the public keys
    /// is done during script execution in the VM.
    #[inline(always)]
    pub fn is_pay_to_stealth(script: &[u8]) -> bool {
        script.len() == STEALTH_OUTPUT_SIZE
    }

    fn as_str(&self) -> &'static str {
        match self {
            ScriptClass::NonStandard => NON_STANDARD,
            ScriptClass::PubKey => PUB_KEY,
            ScriptClass::PubKeyECDSA => PUB_KEY_ECDSA,
            ScriptClass::PubKeyMLDSA => PUB_KEY_MLDSA,
            ScriptClass::ScriptHash => SCRIPT_HASH,
            ScriptClass::Stealth => STEALTH,
        }
    }

    pub fn version(&self) -> ScriptPublicKeyVersion {
        match self {
            ScriptClass::NonStandard => 0,
            ScriptClass::PubKey => 0,
            ScriptClass::PubKeyECDSA => 0,
            ScriptClass::PubKeyMLDSA => 0,
            ScriptClass::ScriptHash => 0,
            ScriptClass::Stealth => STEALTH_SCRIPT_VERSION,
        }
    }
}

impl Display for ScriptClass {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl FromStr for ScriptClass {
    type Err = Error;

    fn from_str(script_class: &str) -> Result<Self, Self::Err> {
        match script_class {
            NON_STANDARD => Ok(ScriptClass::NonStandard),
            PUB_KEY => Ok(ScriptClass::PubKey),
            PUB_KEY_ECDSA => Ok(ScriptClass::PubKeyECDSA),
            PUB_KEY_MLDSA => Ok(ScriptClass::PubKeyMLDSA),
            SCRIPT_HASH => Ok(ScriptClass::ScriptHash),
            STEALTH => Ok(ScriptClass::Stealth),
            _ => Err(Error::InvalidScriptClass(script_class.to_string())),
        }
    }
}

impl TryFrom<&str> for ScriptClass {
    type Error = Error;

    fn try_from(script_class: &str) -> Result<Self, Self::Error> {
        script_class.parse()
    }
}

impl From<Version> for ScriptClass {
    fn from(value: Version) -> Self {
        match value {
            Version::PubKey => ScriptClass::PubKey,
            Version::PubKeyECDSA => ScriptClass::PubKeyECDSA,
            Version::PubKeyMLDSA => ScriptClass::PubKeyMLDSA,
            Version::ScriptHash => ScriptClass::ScriptHash,
            Version::Stealth => ScriptClass::Stealth,
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::MAX_SCRIPT_PUBLIC_KEY_VERSION;
    use kaspa_consensus_core::tx::ScriptVec;

    use super::*;

    #[test]
    fn test_script_class_from_script() {
        struct Test {
            name: &'static str,
            script: Vec<u8>,
            version: ScriptPublicKeyVersion,
            class: ScriptClass,
        }

        // cspell:disable
        let tests = vec![
            Test {
                name: "valid pubkey script",
                script: hex::decode("204a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151ac").unwrap(),
                version: 0,
                class: ScriptClass::PubKey,
            },
            Test {
                name: "valid pubkey ecdsa script",
                script: hex::decode("21fd4a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151ab").unwrap(),
                version: 0,
                class: ScriptClass::PubKeyECDSA,
            },
            Test {
                name: "valid scripthash script",
                script: hex::decode("aa204a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f815187").unwrap(),
                version: 0,
                class: ScriptClass::ScriptHash,
            },
            Test {
                name: "non standard script (unexpected version)",
                script: hex::decode("204a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151ac").unwrap(),
                version: MAX_SCRIPT_PUBLIC_KEY_VERSION + 1,
                class: ScriptClass::NonStandard,
            },
            Test {
                name: "non standard script (unexpected key len)",
                script: hex::decode("1f4a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f81ac").unwrap(),
                version: 0,
                class: ScriptClass::NonStandard,
            },
            Test {
                name: "non standard script (unexpected final check sig op)",
                script: hex::decode("204a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151ad").unwrap(),
                version: 0,
                class: ScriptClass::NonStandard,
            },
            // Stealth script tests
            Test {
                name: "valid stealth script (66 bytes with version 16)",
                // Format: [33B R compressed][1B view_tag][32B P_dest x-only]
                // Using valid compressed pubkey (02 prefix) and x-only pubkey
                script: hex::decode(concat!(
                    "02",                                                               // compressed pubkey prefix
                    "4a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151", // 32 bytes
                    "ab",                                                               // view_tag (1 byte)
                    "4a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151", // P_dest (32 bytes)
                ))
                .unwrap(),
                version: STEALTH_SCRIPT_VERSION,
                class: ScriptClass::Stealth,
            },
            Test {
                name: "non standard stealth script (wrong length)",
                script: hex::decode("4a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151").unwrap(),
                version: STEALTH_SCRIPT_VERSION,
                class: ScriptClass::NonStandard,
            },
            Test {
                name: "non standard stealth script (correct length but wrong version)",
                script: hex::decode(concat!(
                    "02",
                    "4a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151",
                    "ab",
                    "4a23f5eef4b2dead811c7efb4f1afbd8df845e804b6c36a4001fc096e13f8151",
                ))
                .unwrap(),
                version: 0, // wrong version
                class: ScriptClass::NonStandard,
            },
        ];
        // cspell:enable

        for test in tests {
            let script_public_key = ScriptPublicKey::new(test.version, ScriptVec::from_iter(test.script.iter().copied()));
            assert_eq!(test.class, ScriptClass::from_script(&script_public_key), "{} wrong script class", test.name);
        }
    }
}
