//!
//! Message signing and verification functions.
//!

use blake2b_simd::Params;
use borsh::{BorshDeserialize, BorshSerialize};
use kaspa_consensus_core::network::NetworkId;
use kaspa_hashes::{Hash, PersonalMessageSigningHash};
use secp256k1::{Error as SecpError, XOnlyPublicKey};
use serde::{Deserialize, Serialize};

use crate::account::delegation::{delegation_message_hash, DelegationRecordV1, DelegationStatus};
use crate::deterministic::AccountId;
use crate::error::Error;
use crate::result::Result;

const DOMAIN_MLDSA_DELEGATION_REQUEST_ID: &[u8] = b"mldsa-delegation-request";

pub(crate) mod serde_hex_array_32 {
    use faster_hex::{hex_decode, hex_string};
    use serde::de::{Error as DeError, SeqAccess, Visitor};
    use serde::{Deserializer, Serializer};
    use std::fmt;

    pub fn serialize<S>(value: &[u8; 32], serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&hex_string(value))
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<[u8; 32], D::Error>
    where
        D: Deserializer<'de>,
    {
        struct HexVisitor;
        impl<'de> Visitor<'de> for HexVisitor {
            type Value = [u8; 32];

            fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
                formatter.write_str("a hex string or byte array of length 32")
            }

            fn visit_str<E>(self, v: &str) -> Result<Self::Value, E>
            where
                E: DeError,
            {
                parse_hex(v).map_err(E::custom)
            }

            fn visit_string<E>(self, v: String) -> Result<Self::Value, E>
            where
                E: DeError,
            {
                self.visit_str(&v)
            }

            fn visit_bytes<E>(self, v: &[u8]) -> Result<Self::Value, E>
            where
                E: DeError,
            {
                if v.len() != 32 {
                    return Err(E::invalid_length(v.len(), &"32-byte array"));
                }
                let mut out = [0u8; 32];
                out.copy_from_slice(v);
                Ok(out)
            }

            fn visit_seq<A>(self, mut seq: A) -> Result<Self::Value, A::Error>
            where
                A: SeqAccess<'de>,
            {
                let mut bytes = Vec::with_capacity(32);
                while let Some(val) = seq.next_element::<u8>()? {
                    bytes.push(val);
                }
                if bytes.len() != 32 {
                    return Err(A::Error::invalid_length(bytes.len(), &"32-byte array"));
                }
                let mut out = [0u8; 32];
                out.copy_from_slice(&bytes);
                Ok(out)
            }
        }

        fn parse_hex(value: &str) -> Result<[u8; 32], String> {
            if value.len() != 64 {
                return Err(format!("hex string must be 64 chars (got {})", value.len()));
            }
            let mut bytes = [0u8; 32];
            hex_decode(value.as_bytes(), &mut bytes).map_err(|e| e.to_string())?;
            Ok(bytes)
        }

        deserializer.deserialize_any(HexVisitor)
    }
}

pub(crate) mod serde_base64_bytes {
    use base64::{engine::general_purpose, Engine as _};
    use serde::de::{Error as DeError, SeqAccess, Visitor};
    use serde::{Deserializer, Serializer};
    use std::fmt;

    pub fn serialize<S>(value: &Vec<u8>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&general_purpose::STANDARD.encode(value))
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where
        D: Deserializer<'de>,
    {
        struct Base64Visitor;
        impl<'de> Visitor<'de> for Base64Visitor {
            type Value = Vec<u8>;

            fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
                formatter.write_str("a base64 string or byte array")
            }

            fn visit_str<E>(self, v: &str) -> Result<Self::Value, E>
            where
                E: DeError,
            {
                general_purpose::STANDARD.decode(v).map_err(E::custom)
            }

            fn visit_string<E>(self, v: String) -> Result<Self::Value, E>
            where
                E: DeError,
            {
                self.visit_str(&v)
            }

            fn visit_bytes<E>(self, v: &[u8]) -> Result<Self::Value, E>
            where
                E: DeError,
            {
                Ok(v.to_vec())
            }

            fn visit_seq<A>(self, mut seq: A) -> Result<Self::Value, A::Error>
            where
                A: SeqAccess<'de>,
            {
                let mut bytes = Vec::new();
                while let Some(val) = seq.next_element::<u8>()? {
                    bytes.push(val);
                }
                Ok(bytes)
            }
        }

        deserializer.deserialize_any(Base64Visitor)
    }
}

/// A personal message (text) that can be signed.
#[derive(Clone)]
pub struct PersonalMessage<'a>(pub &'a str);

impl AsRef<[u8]> for PersonalMessage<'_> {
    fn as_ref(&self) -> &[u8] {
        self.0.as_bytes()
    }
}

#[derive(Clone)]
pub struct SignMessageOptions {
    /// The auxiliary randomness exists only to mitigate specific kinds of power analysis
    /// side-channel attacks. Providing it definitely improves security, but omitting it
    /// should not be considered dangerous, as most legacy signature schemes don't provide
    /// mitigations against such attacks. To read more about the relevant discussions that
    /// arose in adding this randomness please see: <https://github.com/sipa/bips/issues/195>
    pub no_aux_rand: bool,
}

/// Sign a message with the given private key
pub fn sign_message(msg: &PersonalMessage, privkey: &[u8; 32], options: &SignMessageOptions) -> Result<Vec<u8>, SecpError> {
    let hash = calc_personal_message_hash(msg);

    let msg = secp256k1::Message::from_digest_slice(hash.as_bytes().as_slice())?;
    let schnorr_key = secp256k1::Keypair::from_seckey_slice(secp256k1::SECP256K1, privkey)?;

    let sig: [u8; 64] = if options.no_aux_rand {
        *secp256k1::SECP256K1.sign_schnorr_no_aux_rand(&msg, &schnorr_key).as_ref()
    } else {
        *schnorr_key.sign_schnorr(msg).as_ref()
    };

    Ok(sig.to_vec())
}

/// Verifies signed message.
///
/// Produces `Ok(())` if the signature matches the given message and [`secp256k1::Error`]
/// if any of the inputs are incorrect, or the signature is invalid.
///
pub fn verify_message(msg: &PersonalMessage, signature: &Vec<u8>, pubkey: &XOnlyPublicKey) -> Result<(), SecpError> {
    let hash = calc_personal_message_hash(msg);
    let msg = secp256k1::Message::from_digest_slice(hash.as_bytes().as_slice())?;
    let sig = secp256k1::schnorr::Signature::from_slice(signature.as_slice())?;
    sig.verify(&msg, pubkey)
}

fn calc_personal_message_hash(msg: &PersonalMessage) -> Hash {
    let mut hasher = PersonalMessageSigningHash::new();
    hasher.write(msg);
    hasher.finalize()
}

/// Delegation header identical to [`DelegationRecordV1`] but without a signature.
#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct DelegationRecordHeaderV1 {
    pub version: u8,
    pub level: u8,
    #[serde(with = "serde_hex_array_32")]
    pub anchor: [u8; 32],
    pub account_id: AccountId,
    #[serde(with = "serde_hex_array_32")]
    pub spend_pubkey: [u8; 32],
    #[serde(with = "serde_hex_array_32")]
    pub scan_pubkey: [u8; 32],
    pub valid_from_daa: u64,
    pub valid_until_daa: Option<u64>,
    pub nonce: u64,
    pub status: DelegationStatus,
}

impl From<&DelegationRecordV1> for DelegationRecordHeaderV1 {
    fn from(record: &DelegationRecordV1) -> Self {
        Self {
            version: record.version,
            level: record.level,
            anchor: record.anchor,
            account_id: record.account_id,
            spend_pubkey: record.spend_pubkey,
            scan_pubkey: record.scan_pubkey,
            valid_from_daa: record.valid_from_daa,
            valid_until_daa: record.valid_until_daa,
            nonce: record.nonce,
            status: record.status.clone(),
        }
    }
}

impl From<&DelegationRecordHeaderV1> for DelegationRecordV1 {
    fn from(header: &DelegationRecordHeaderV1) -> Self {
        Self {
            version: header.version,
            level: header.level,
            anchor: header.anchor,
            account_id: header.account_id,
            spend_pubkey: header.spend_pubkey,
            scan_pubkey: header.scan_pubkey,
            valid_from_daa: header.valid_from_daa,
            valid_until_daa: header.valid_until_daa,
            nonce: header.nonce,
            status: header.status.clone(),
            signature: Vec::new(),
        }
    }
}

/// Canonical signable body for a delegation request batch.
#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct MasterDelegationRequestBodyV1 {
    pub version: u8,
    #[serde(with = "serde_hex_array_32")]
    pub master_anchor: [u8; 32],
    pub master_level: u8,
    pub network_id: NetworkId,
    pub delegations: Vec<DelegationRecordHeaderV1>,
    pub created_at_unixtime: u64,
    #[serde(with = "serde_hex_array_32")]
    pub request_id: [u8; 32],
}

/// Canonical signable body for a delegation response batch.
#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct MasterDelegationResponseBodyV1 {
    pub version: u8,
    #[serde(with = "serde_hex_array_32")]
    pub master_anchor: [u8; 32],
    pub master_level: u8,
    #[serde(with = "serde_hex_array_32")]
    pub request_id: [u8; 32],
    pub delegations: Vec<DelegationRecordV1>,
}

/// Hash delegation header using the same domain separation as on-chain delegation records.
pub fn hash_delegation_header(header: &DelegationRecordHeaderV1) -> Result<[u8; 32]> {
    delegation_message_hash(&DelegationRecordV1::from(header))
}

/// Calculate deterministic request id for offline delegation session.
pub fn calc_request_id(body: &MasterDelegationRequestBodyV1) -> Result<[u8; 32]> {
    let mut clone = body.clone();
    clone.request_id = [0u8; 32];
    let serialized = borsh::to_vec(&clone).map_err(|e| Error::Custom(format!("delegation request borsh encode: {e}")))?;
    let mut hasher = Params::new().hash_length(32).key(DOMAIN_MLDSA_DELEGATION_REQUEST_ID).to_state();
    hasher.update(&serialized);
    let mut out = [0u8; 32];
    out.copy_from_slice(hasher.finalize().as_bytes());
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::account::delegation::{sign_with_master, DelegationStatus};
    use kaspa_consensus_core::network::NetworkType;
    use kaspa_hashes::Hash;
    use kaspa_mldsa::MlDsaLevel;
    use kaspa_utils::hex::ToHex;
    use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;

    /// Sign message equivalent that's only used for tests
    /// Necessary only because of KIP test vectors
    fn sign_message_with_aux_rand(msg: &PersonalMessage, privkey: &[u8; 32], aux_rand: &[u8; 32]) -> Result<Vec<u8>, SecpError> {
        let hash = calc_personal_message_hash(msg);

        let msg = secp256k1::Message::from_digest_slice(hash.as_bytes().as_slice())?;
        let schnorr_key = secp256k1::Keypair::from_seckey_slice(secp256k1::SECP256K1, privkey)?;
        let curve = secp256k1::Secp256k1::new();
        let sig: [u8; 64] = *curve.sign_schnorr_with_aux_rand(&msg, &schnorr_key, aux_rand).as_ref();

        Ok(sig.to_vec())
    }

    #[test]
    fn test_basic_sign_and_verify_sign() {
        let pm = PersonalMessage("Hello Kaspa!");
        let privkey: [u8; 32] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        ];
        let pubkey = XOnlyPublicKey::from_slice(&[
            0xF9, 0x30, 0x8A, 0x01, 0x92, 0x58, 0xC3, 0x10, 0x49, 0x34, 0x4F, 0x85, 0xF8, 0x9D, 0x52, 0x29, 0xB5, 0x31, 0xC8, 0x45,
            0x83, 0x6F, 0x99, 0xB0, 0x86, 0x01, 0xF1, 0x13, 0xBC, 0xE0, 0x36, 0xF9,
        ])
        .unwrap();

        let sign_with_aux_rand = SignMessageOptions { no_aux_rand: false };
        let sign_with_no_aux_rand = SignMessageOptions { no_aux_rand: true };
        verify_message(&pm, &sign_message(&pm, &privkey, &sign_with_aux_rand).expect("sign_message failed"), &pubkey)
            .expect("verify_message failed");
        verify_message(&pm, &sign_message(&pm, &privkey, &sign_with_no_aux_rand).expect("sign_message failed"), &pubkey)
            .expect("verify_message failed");
    }

    #[test]
    fn test_basic_sign_without_rand_twice_should_get_same_signature() {
        let pm = PersonalMessage("Hello Kaspa!");
        let privkey: [u8; 32] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        ];

        let sign_with_no_aux_rand = SignMessageOptions { no_aux_rand: true };
        let signature = sign_message(&pm, &privkey, &sign_with_no_aux_rand).expect("sign_message failed");
        let signature_twice = sign_message(&pm, &privkey, &sign_with_no_aux_rand).expect("sign_message failed");
        assert_eq!(signature, signature_twice);
    }

    #[test]
    fn test_kanji_sign_and_verify_sign() {
        let pm = PersonalMessage("こんにちは世界");
        let privkey: [u8; 32] = [
            0xB7, 0xE1, 0x51, 0x62, 0x8A, 0xED, 0x2A, 0x6A, 0xBF, 0x71, 0x58, 0x80, 0x9C, 0xF4, 0xF3, 0xC7, 0x62, 0xE7, 0x16, 0x0F,
            0x38, 0xB4, 0xDA, 0x56, 0xA7, 0x84, 0xD9, 0x04, 0x51, 0x90, 0xCF, 0xEF,
        ];
        let pubkey = XOnlyPublicKey::from_slice(&[
            0xDF, 0xF1, 0xD7, 0x7F, 0x2A, 0x67, 0x1C, 0x5F, 0x36, 0x18, 0x37, 0x26, 0xDB, 0x23, 0x41, 0xBE, 0x58, 0xFE, 0xAE, 0x1D,
            0xA2, 0xDE, 0xCE, 0xD8, 0x43, 0x24, 0x0F, 0x7B, 0x50, 0x2B, 0xA6, 0x59,
        ])
        .unwrap();

        let sign_with_aux_rand = SignMessageOptions { no_aux_rand: false };
        let sign_with_no_aux_rand = SignMessageOptions { no_aux_rand: true };
        verify_message(&pm, &sign_message(&pm, &privkey, &sign_with_aux_rand).expect("sign_message failed"), &pubkey)
            .expect("verify_message failed");
        verify_message(&pm, &sign_message(&pm, &privkey, &sign_with_no_aux_rand).expect("sign_message failed"), &pubkey)
            .expect("verify_message failed");
    }

    #[test]
    fn test_long_text_sign_and_verify_sign() {
        let pm = PersonalMessage("Lorem ipsum dolor sit amet. Aut omnis amet id voluptatem eligendi sit accusantium dolorem 33 corrupti necessitatibus hic consequatur quod et maiores alias non molestias suscipit? Est voluptatem magni qui odit eius est eveniet cupiditate id eius quae aut molestiae nihil eum excepturi voluptatem qui nisi architecto?

Et aliquid ipsa ut quas enim et dolorem deleniti ut eius dicta non praesentium neque est velit numquam. Ut consectetur amet ut error veniam et officia laudantium ea velit nesciunt est explicabo laudantium sit totam aperiam.

Ut omnis magnam et accusamus earum rem impedit provident eum commodi repellat qui dolores quis et voluptate labore et adipisci deleniti. Est nostrum explicabo aut quibusdam labore et molestiae voluptate. Qui omnis nostrum At libero deleniti et quod quia.");
        let privkey: [u8; 32] = [
            0xB7, 0xE1, 0x51, 0x62, 0x8A, 0xED, 0x2A, 0x6A, 0xBF, 0x71, 0x58, 0x80, 0x9C, 0xF4, 0xF3, 0xC7, 0x62, 0xE7, 0x16, 0x0F,
            0x38, 0xB4, 0xDA, 0x56, 0xA7, 0x84, 0xD9, 0x04, 0x51, 0x90, 0xCF, 0xEF,
        ];
        let pubkey = XOnlyPublicKey::from_slice(&[
            0xDF, 0xF1, 0xD7, 0x7F, 0x2A, 0x67, 0x1C, 0x5F, 0x36, 0x18, 0x37, 0x26, 0xDB, 0x23, 0x41, 0xBE, 0x58, 0xFE, 0xAE, 0x1D,
            0xA2, 0xDE, 0xCE, 0xD8, 0x43, 0x24, 0x0F, 0x7B, 0x50, 0x2B, 0xA6, 0x59,
        ])
        .unwrap();

        let sign_with_aux_rand = SignMessageOptions { no_aux_rand: false };
        let sign_with_no_aux_rand = SignMessageOptions { no_aux_rand: true };
        verify_message(&pm, &sign_message(&pm, &privkey, &sign_with_aux_rand).expect("sign_message failed"), &pubkey)
            .expect("verify_message failed");
        verify_message(&pm, &sign_message(&pm, &privkey, &sign_with_no_aux_rand).expect("sign_message failed"), &pubkey)
            .expect("verify_message failed");
    }

    #[test]
    fn test_fail_verify() {
        let pm = PersonalMessage("Not Hello Kaspa!");
        let pubkey = XOnlyPublicKey::from_slice(&[
            0xF9, 0x30, 0x8A, 0x01, 0x92, 0x58, 0xC3, 0x10, 0x49, 0x34, 0x4F, 0x85, 0xF8, 0x9D, 0x52, 0x29, 0xB5, 0x31, 0xC8, 0x45,
            0x83, 0x6F, 0x99, 0xB0, 0x86, 0x01, 0xF1, 0x13, 0xBC, 0xE0, 0x36, 0xF9,
        ])
        .unwrap();
        let fake_sig: Vec<u8> = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        ]
        .to_vec();

        let verify_result = verify_message(&pm, &fake_sig, &pubkey);
        assert!(verify_result.is_err());
    }

    #[test]
    fn test_sign_and_verify_test_case_0() {
        let pm = PersonalMessage("Hello Kaspa!");
        let privkey: [u8; 32] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        ];
        let aux_rand: [u8; 32] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        let pubkey = XOnlyPublicKey::from_slice(&[
            0xF9, 0x30, 0x8A, 0x01, 0x92, 0x58, 0xC3, 0x10, 0x49, 0x34, 0x4F, 0x85, 0xF8, 0x9D, 0x52, 0x29, 0xB5, 0x31, 0xC8, 0x45,
            0x83, 0x6F, 0x99, 0xB0, 0x86, 0x01, 0xF1, 0x13, 0xBC, 0xE0, 0x36, 0xF9,
        ])
        .unwrap();
        let expected_sig: Vec<u8> = [
            0x40, 0xB9, 0xBB, 0x2B, 0xE0, 0xAE, 0x02, 0x60, 0x72, 0x79, 0xED, 0xA6, 0x40, 0x15, 0xA8, 0xD8, 0x6E, 0x37, 0x63, 0x27,
            0x91, 0x70, 0x34, 0x0B, 0x82, 0x43, 0xF7, 0xCE, 0x53, 0x44, 0xD7, 0x7A, 0xFF, 0x11, 0x91, 0x59, 0x8B, 0xAF, 0x2F, 0xD2,
            0x61, 0x49, 0xCA, 0xC3, 0xB4, 0xB1, 0x2C, 0x2C, 0x43, 0x32, 0x61, 0xC0, 0x08, 0x34, 0xDB, 0x60, 0x98, 0xCB, 0x17, 0x2A,
            0xA4, 0x8E, 0xF5, 0x22,
        ]
        .to_vec();

        let sig_result = sign_message_with_aux_rand(&pm, &privkey, &aux_rand).expect("sign_message failed");
        assert_eq!(expected_sig, sig_result);

        verify_message(&pm, &sig_result, &pubkey).expect("verify_message failed");
    }

    #[test]
    fn test_sign_and_verify_test_case_1() {
        let pm = PersonalMessage("Hello Kaspa!");
        let privkey: [u8; 32] = [
            0xB7, 0xE1, 0x51, 0x62, 0x8A, 0xED, 0x2A, 0x6A, 0xBF, 0x71, 0x58, 0x80, 0x9C, 0xF4, 0xF3, 0xC7, 0x62, 0xE7, 0x16, 0x0F,
            0x38, 0xB4, 0xDA, 0x56, 0xA7, 0x84, 0xD9, 0x04, 0x51, 0x90, 0xCF, 0xEF,
        ];
        let aux_rand: [u8; 32] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        ];
        let pubkey = XOnlyPublicKey::from_slice(&[
            0xDF, 0xF1, 0xD7, 0x7F, 0x2A, 0x67, 0x1C, 0x5F, 0x36, 0x18, 0x37, 0x26, 0xDB, 0x23, 0x41, 0xBE, 0x58, 0xFE, 0xAE, 0x1D,
            0xA2, 0xDE, 0xCE, 0xD8, 0x43, 0x24, 0x0F, 0x7B, 0x50, 0x2B, 0xA6, 0x59,
        ])
        .unwrap();
        let expected_sig: Vec<u8> = [
            0xEB, 0x9E, 0x8A, 0x3C, 0x54, 0x7E, 0xB9, 0x1B, 0x6A, 0x75, 0x92, 0x64, 0x4F, 0x32, 0x8F, 0x06, 0x48, 0xBD, 0xD2, 0x1A,
            0xBA, 0x3C, 0xD4, 0x47, 0x87, 0xD4, 0x29, 0xD4, 0xD7, 0x90, 0xAA, 0x8B, 0x96, 0x27, 0x45, 0x69, 0x1F, 0x3B, 0x47, 0x2E,
            0xD8, 0xD6, 0x5F, 0x3B, 0x77, 0x0E, 0xCB, 0x4F, 0x77, 0x7B, 0xD1, 0x7B, 0x1D, 0x30, 0x91, 0x00, 0x91, 0x9B, 0x53, 0xE0,
            0xE2, 0x06, 0xB4, 0xC6,
        ]
        .to_vec();

        let sig_result = sign_message_with_aux_rand(&pm, &privkey, &aux_rand).expect("sign_message failed");
        assert_eq!(expected_sig, sig_result);

        verify_message(&pm, &sig_result, &pubkey).expect("verify_message failed");
    }

    #[test]
    fn test_sign_and_verify_test_case_2() {
        let pm = PersonalMessage("こんにちは世界");
        let privkey: [u8; 32] = [
            0xB7, 0xE1, 0x51, 0x62, 0x8A, 0xED, 0x2A, 0x6A, 0xBF, 0x71, 0x58, 0x80, 0x9C, 0xF4, 0xF3, 0xC7, 0x62, 0xE7, 0x16, 0x0F,
            0x38, 0xB4, 0xDA, 0x56, 0xA7, 0x84, 0xD9, 0x04, 0x51, 0x90, 0xCF, 0xEF,
        ];
        let aux_rand: [u8; 32] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        ];
        let pubkey = XOnlyPublicKey::from_slice(&[
            0xDF, 0xF1, 0xD7, 0x7F, 0x2A, 0x67, 0x1C, 0x5F, 0x36, 0x18, 0x37, 0x26, 0xDB, 0x23, 0x41, 0xBE, 0x58, 0xFE, 0xAE, 0x1D,
            0xA2, 0xDE, 0xCE, 0xD8, 0x43, 0x24, 0x0F, 0x7B, 0x50, 0x2B, 0xA6, 0x59,
        ])
        .unwrap();
        let expected_sig: Vec<u8> = [
            0x81, 0x06, 0x53, 0xD5, 0xF8, 0x02, 0x06, 0xDB, 0x51, 0x96, 0x72, 0x36, 0x2A, 0xDD, 0x6C, 0x98, 0xDA, 0xD3, 0x78, 0x84,
            0x4E, 0x5B, 0xA4, 0xD8, 0x9A, 0x22, 0xC9, 0xF0, 0xC7, 0x09, 0x2E, 0x8C, 0xEC, 0xBA, 0x73, 0x4F, 0xFF, 0x79, 0x22, 0xB6,
            0x56, 0xB4, 0xBE, 0x3F, 0x4B, 0x1F, 0x09, 0x88, 0x99, 0xC9, 0x5C, 0xB5, 0xC1, 0x02, 0x3D, 0xCE, 0x35, 0x19, 0x20, 0x8A,
            0xFA, 0xFB, 0x59, 0xBC,
        ]
        .to_vec();

        let sig_result = sign_message_with_aux_rand(&pm, &privkey, &aux_rand).expect("sign_message failed");
        assert_eq!(expected_sig, sig_result);

        verify_message(&pm, &sig_result, &pubkey).expect("verify_message failed");
    }

    #[test]
    fn test_sign_and_verify_test_case_3() {
        let pm = PersonalMessage("Lorem ipsum dolor sit amet. Aut omnis amet id voluptatem eligendi sit accusantium dolorem 33 corrupti necessitatibus hic consequatur quod et maiores alias non molestias suscipit? Est voluptatem magni qui odit eius est eveniet cupiditate id eius quae aut molestiae nihil eum excepturi voluptatem qui nisi architecto?

Et aliquid ipsa ut quas enim et dolorem deleniti ut eius dicta non praesentium neque est velit numquam. Ut consectetur amet ut error veniam et officia laudantium ea velit nesciunt est explicabo laudantium sit totam aperiam.

Ut omnis magnam et accusamus earum rem impedit provident eum commodi repellat qui dolores quis et voluptate labore et adipisci deleniti. Est nostrum explicabo aut quibusdam labore et molestiae voluptate. Qui omnis nostrum At libero deleniti et quod quia.");
        let privkey: [u8; 32] = [
            0xB7, 0xE1, 0x51, 0x62, 0x8A, 0xED, 0x2A, 0x6A, 0xBF, 0x71, 0x58, 0x80, 0x9C, 0xF4, 0xF3, 0xC7, 0x62, 0xE7, 0x16, 0x0F,
            0x38, 0xB4, 0xDA, 0x56, 0xA7, 0x84, 0xD9, 0x04, 0x51, 0x90, 0xCF, 0xEF,
        ];
        let aux_rand: [u8; 32] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        ];
        let pubkey = XOnlyPublicKey::from_slice(&[
            0xDF, 0xF1, 0xD7, 0x7F, 0x2A, 0x67, 0x1C, 0x5F, 0x36, 0x18, 0x37, 0x26, 0xDB, 0x23, 0x41, 0xBE, 0x58, 0xFE, 0xAE, 0x1D,
            0xA2, 0xDE, 0xCE, 0xD8, 0x43, 0x24, 0x0F, 0x7B, 0x50, 0x2B, 0xA6, 0x59,
        ])
        .unwrap();
        let expected_sig: Vec<u8> = [
            0x40, 0xCB, 0xBD, 0x39, 0x38, 0x86, 0x7B, 0x10, 0x07, 0x6B, 0xB1, 0x48, 0x35, 0x55, 0x7C, 0x06, 0x2F, 0x5B, 0xF6, 0xA4,
            0x68, 0x29, 0x95, 0xFC, 0x8B, 0x0A, 0x1C, 0xD2, 0xED, 0x98, 0x6E, 0xED, 0xAA, 0xA0, 0x0C, 0xFE, 0x04, 0xF6, 0xC9, 0xE5,
            0xA9, 0x54, 0x6B, 0x86, 0x07, 0x32, 0xE5, 0xB9, 0x03, 0xCC, 0x82, 0x78, 0x02, 0x28, 0x64, 0x7D, 0x53, 0x75, 0xBE, 0xC3,
            0xD2, 0xA4, 0x98, 0x3A,
        ]
        .to_vec();

        let sig_result = sign_message_with_aux_rand(&pm, &privkey, &aux_rand).expect("sign_message failed");
        assert_eq!(expected_sig, sig_result);

        verify_message(&pm, &sig_result, &pubkey).expect("verify_message failed");
    }

    fn sample_header() -> DelegationRecordHeaderV1 {
        let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);
        DelegationRecordHeaderV1 {
            version: 1,
            level: MlDsaLevel::Level2 as u8,
            anchor: *keypair.anchor().as_bytes(),
            account_id: AccountId(Hash::from_u64_word(7)),
            spend_pubkey: [2u8; 32],
            scan_pubkey: [3u8; 32],
            valid_from_daa: 10,
            valid_until_daa: Some(20),
            nonce: 1,
            status: DelegationStatus::Active,
        }
    }

    #[test]
    fn delegation_header_roundtrip() {
        let header = sample_header();
        let bytes = borsh::to_vec(&header).expect("encode");
        let decoded = DelegationRecordHeaderV1::try_from_slice(&bytes).expect("decode");
        assert_eq!(decoded, header);

        let json = serde_json::to_string(&header).expect("serde encode");
        let decoded_json: DelegationRecordHeaderV1 = serde_json::from_str(&json).expect("serde decode");
        assert_eq!(decoded_json, header);
    }

    #[test]
    fn delegation_header_hash_matches_record_hash() {
        let header = sample_header();
        let record = DelegationRecordV1::from(&header);

        let header_hash = hash_delegation_header(&header).expect("hash header");
        let record_hash = delegation_message_hash(&record).expect("hash record");

        assert_eq!(header_hash, record_hash);
    }

    #[test]
    fn request_id_changes_with_payload() {
        let header = sample_header();
        let mut request = MasterDelegationRequestBodyV1 {
            version: 1,
            master_anchor: header.anchor,
            master_level: MlDsaLevel::Level2 as u8,
            network_id: NetworkId::new(kaspa_consensus_core::network::NetworkType::Devnet),
            delegations: vec![header.clone()],
            created_at_unixtime: 1_730_000_000,
            request_id: [0u8; 32],
        };

        let request_id = calc_request_id(&request).expect("calc id");
        request.request_id = request_id;

        let mut changed = request.clone();
        changed.delegations[0].nonce += 1;
        let changed_id = calc_request_id(&changed).expect("calc id changed");

        assert_eq!(request_id.len(), 32);
        assert_ne!(request_id, changed_id);

        assert_eq!(request_id, calc_request_id(&request).expect("calc id same"));
    }

    #[test]
    fn master_delegation_test_vectors() {
        const ROOT_SEED: [u8; 64] = [0x11; 64];

        let (master_key, anchor, _) = MlDsaKeypair::from_bip39_root_seed(&ROOT_SEED, 0, MlDsaLevel::Level2).expect("derive master");
        let anchor_bytes = *anchor.as_bytes();

        let header = DelegationRecordHeaderV1 {
            version: 1,
            level: MlDsaLevel::Level2 as u8,
            anchor: anchor_bytes,
            account_id: AccountId(Hash::from_u64_word(42)),
            spend_pubkey: [0x22; 32],
            scan_pubkey: [0x33; 32],
            valid_from_daa: 123_456,
            valid_until_daa: Some(125_000),
            nonce: 7,
            status: DelegationStatus::Active,
        };

        let mut request = MasterDelegationRequestBodyV1 {
            version: 1,
            master_anchor: anchor_bytes,
            master_level: MlDsaLevel::Level2 as u8,
            network_id: NetworkId::new(NetworkType::Devnet),
            delegations: vec![header.clone()],
            created_at_unixtime: 1_730_000_123,
            request_id: [0u8; 32],
        };

        let request_id = calc_request_id(&request).expect("calc request id");
        request.request_id = request_id;

        let request_borsh = borsh::to_vec(&request).expect("borsh request");
        let request_json = serde_json::to_string_pretty(&request).expect("json request");

        let expected_request_id_hex = "ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300";
        let expected_request_borsh_hex = "01cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab020200010000000102cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab0000000000000000000000000000000000000000000000002a000000000000002222222222222222222222222222222222222222222222222222222222222222333333333333333333333333333333333333333333333333333333333333333340e20100000000000148e8010000000000070000000000000000fbb41d6700000000ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300";
        let expected_request_json = r#"{
  "version": 1,
  "masterAnchor": "cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab",
  "masterLevel": 2,
  "networkId": "devnet",
  "delegations": [
    {
      "version": 1,
      "level": 2,
      "anchor": "cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab",
      "accountId": "0000000000000000000000000000000000000000000000002a00000000000000",
      "spendPubkey": "2222222222222222222222222222222222222222222222222222222222222222",
      "scanPubkey": "3333333333333333333333333333333333333333333333333333333333333333",
      "validFromDaa": 123456,
      "validUntilDaa": 125000,
      "nonce": 7,
      "status": "Active"
    }
  ],
  "createdAtUnixtime": 1730000123,
  "requestId": "ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300"
}"#;

        assert_eq!(request_id.to_vec().to_hex(), expected_request_id_hex);
        assert_eq!(request_borsh.to_hex(), expected_request_borsh_hex);
        assert_eq!(request_json, expected_request_json);

        let mut record = DelegationRecordV1::from(&header);
        sign_with_master(&master_key, &mut record).expect("sign record");

        let response = MasterDelegationResponseBodyV1 {
            version: 1,
            master_anchor: anchor_bytes,
            master_level: MlDsaLevel::Level2 as u8,
            request_id,
            delegations: vec![record],
        };

        let response_borsh = borsh::to_vec(&response).expect("borsh response");
        let response_json = serde_json::to_string_pretty(&response).expect("json response");

        let expected_response_borsh_hex = "01cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab02ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300010000000102cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab0000000000000000000000000000000000000000000000002a000000000000002222222222222222222222222222222222222222222222222222222222222222333333333333333333333333333333333333333333333333333333333333333340e20100000000000148e801000000000007000000000000000074090000379f50f583e4621d121565404ec423059ce1ab401d2a567608bfb5d5c82b338a404d9c460332d786b6b5af9f3f97287e72659c1806083024d34f397a14d0f78acbddff4348ab7a996a14dab0e9e826becec95516af209072d4973032e3cfc7fd791f5322695a52c674138429f78c22a07de7e200ad7a4bbc692577525f60c2be382cc317f75f60b2d219758daf94055671ec4353ff08ee7eaf42beb243d59d0907059b405773d49c0f5981ee32aed7617d866d27c7f2ef9069f481be1faa476e255e4dc3072655ad84171ed0fe4caf8bf37f7a93fa4f21ca36ebc3cf5beebdc4dc5aadc302adcf926a1027853b7d3d3c24c28ab750b3bb2631d66883528fcac56b23246f4350a8f22dc60e57b6e550a3fcba74f6df266498ea635f2b7fe3d13f4ab9b4710c3695ea06719201e33c2fc0b9a23aee287cb8d2250d9c7462252b6ad7fcbd05f93c4aaa34285d7e40eb17ff69fd2950db0f887f1e14edb7a95ddf6307e5b9baa8810fa17943ee7a4559cbd87b1f77ec78876f12f08091126de7c7c43f0447ef3391feef679e6fe89da9d1857dd88e109868c05a1567be260a37cdd277c27a8fa2f72d1260860233d5e507fbc84d88bf900fd9077bcb5f796c923ac2374d35486cbd72e4063bee4340101c6251a74b16b03077f6765f462c0236b6a142dc03f49e69e6e41f8f8161ea5d2fa6b7524f11b7be14208edccdb42d3684e4bf8e72fec6dc8865b3c3329b3ea5f4e659535675378bbc4f66c8e0f346c0cc71e75995923cc880855338af2af9856685c777d4be8973574bf2f9b75eb991f563bdd2910be9b8c2d42b665a4ef585a9cc00fc457454515d859f4e01ccce41b0ebedbe6f038ba2a6621b0a932c3b1ee2ff8a8b39f5b8267eb006646e9785af0a1557ffe419725b42020aca59ae09204dcc246fba0d70754a96eaf3e76d79598c5b91ccce1abd597cc6b2a7370236ee96f891865579292e01bd099b8a9a7fc3aa3b05d63aebb29879409cae07e37cb0ba4af0385c32362c0b2e43cabac6b69055193859af573c614c232adcb96d013861bfc2c5369290f672bcd0ed8ca9d2a9c05f1f5be7b1228e730fe3a5e8caddf105083189d033037d4c4911bb8812f1831b5ab2594c449135b98ac9fdcfa16dde57172fad7454ea3becc60f5e20efa6c27e9f353be76ddc7d6a88ebc36228e2bf464cc38f31f35322c6be0f8cc03ec9f6a269fbb640bc282220ab0d0176b4a2945a5fbf88c98d2640e8b92f163bb26a2e94ff8e44a8f188c68def02d11591db60e9c14acbba46db3be18367309f19786de6eb7e1f3730d89d40c06759a574b0804e9aedfffd9e64143189e9a81bd906379ff5c3034a3e30bf74b1147b99371be754e015a6120fe280403267f50b004e57e05ca498ec82eaa4d6860f4ac004c1abcad336e1912c5743e3a73aa62cea3093cfad5adf4da8e6b7689fad3f8ce42055da0316786d64ae6304ed9d1dc6421d744b667723e02258389fe4a467a8a199c6f03e3753a0b9f0559ee8ba55928b5cc9288235eb72a25f871e10655e8a3ba37278858ba4c51fce0ab50aa08b62d86d4944f009a40bb8dd1ffcb20fea3295839d8c11987ab99271371e9db0dd5db93aeb5e1358381530030a9ccc98518388d066c3c28997fd902f1aa8ae17bd625d78a31d026e4c41a36acb68c8b5264b629c77bbdb1d674adf5f0cdd7260febe8654de04f32de27a52f2c95083f7966221652cafbf0d73addb03b163cf4b7418971fa5b56f7fad690e0f2c3f0f34a8b9e2d3b8acf6212e74d9bab4ce7bece2d4e28d0a475bf2527673fcb5f02ff4db4ad2e8567cb743441f2f4b43996e2847d5f382aa59d505a57691d72637c4caf2aca16a23fbd57d17ef2b0bad0a3df3d62a1013d6fc7ed6150920a040e06517cf84279cec0046985208c68059e61ca3284e8c809331b457fa1e1fe70ef65b2eee50b13dddd802a343868426086ab3f923b9001a2e5f076c7f92f2aaa109380f5fd44c975374292ff2139baae6f3c2619089f7fae9bbd9e89b5c1f078da55cd95262447519156d9e493d231b2e373249968c1af15cfca38caeaed07c78f3d96a8bd800aedf42aa85ed1d9c7c9b0cee9f5c9c2b311e4d294276475eeed8e1a75bf6e5079a997728036714217c67b1d67bcf79157e139f271334bb5fdf435728b181e3276a7a9c4b9349811d5f3990918b7d368583a66660d277eaae37189228c2f10b39acb6c50f0b9eb925972c7a47b6010e06e0bfcaffe6c35187b21125f464cabe0927201e02f7e9e49fe313651abc9687357530f99a3148e19e405aefcd347d6fd506609122893628b964190f33e12b265f4d0c70ed0755bc9de95e02f314ea21c541c4c5678220ac45d62ca3df6817ecbe087e9f0d4abd5e8a826bb2f5c695f1c83fbb36463155b99257e96bf28c2e8ce2b6f6758ed0fafe91d434e9bc9f4e4e39e7e4f4e63613dd0f6d81ba1c794b18ab8d42cd66c3cbad866d09902c37dddb597b93d6d6ae9ef98fa969a9b148e704db1d3575ca10a339e771051f70ba5629fd47ccd580a0d830808bc218449d32b54cd8fec9f1bfd77bd41a8bd2f422ec15de5a86f586238409de5b152eee2ac7ca317c4230d287d174ab8dbc13f485f8883199e6a854973b36906950d15aa5be0cc15ba5fb70d6a3469dede55eb857115edc170e410c63e75defb54efd6c62403b7b5ba7fe95ae9cf84c6ce16bd3ac4a76f04d8b695b2965bfad62f063a3dda3f6bc37827103492aa32a02d8957ae76ad2212c03a962cfebc1ce740cac079eb119e637af66ea7be6539b58565946271423864178f3dceebee81f089d02a2a162da7f9dc7c1cae72040dacff217fe4c5e96285ea90a37aaac9e942c183b721ae3ee70fb49d8e73d167bf4f61db78cdba87ffcc5c36d5d480ae8d02c4d289ede6a493e7f9839293d66d386ebaea79e265c9339d895a6915c3e661dcd08ecddd76ebda8201059b44524e1a952e18c676080be3dba54a65f2090692cc5efff45b504fcee54afa69f8b38d51a8cf04350145521e49e77c49772ae05b5653bcb617e775efd06ed7882a85fb1d26fcb0e61b36e65886b85c8e9845a7621bbc136abb3c8067365de463e6b05bc4eda74903f8ba4fd1f45c93519892ffa84201c64cef5fa73c17b956f71205fcb35ff71fffd30d1cf0c96611894eea8d289d0acc66f42200b51c60f5b6b96250a9484643cc152399c41a7b978f5f8e997da5582d4e328115e50c7bcec53f51db289139f180a9ad882b2ff2de9c539d87a005d9a68c2582062c9d1eae7a906101518373947637c8ab8bdc1ced6dcdfe0eb303350576e6f717f8ad3e020454d555b647f8e94a3aeb3b6dbdcfa37404c4e597682838b8c9698999fbac9e1ef00000000000000000000000000000000131e2e40";
        let expected_response_json = r#"{
  "version": 1,
  "masterAnchor": "cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab",
  "masterLevel": 2,
  "requestId": "ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300",
  "delegations": [
    {
      "version": 1,
      "level": 2,
      "anchor": "cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab",
      "accountId": "0000000000000000000000000000000000000000000000002a00000000000000",
      "spendPubkey": "2222222222222222222222222222222222222222222222222222222222222222",
      "scanPubkey": "3333333333333333333333333333333333333333333333333333333333333333",
      "validFromDaa": 123456,
      "validUntilDaa": 125000,
      "nonce": 7,
      "status": "Active",
      "signature": "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"
    }
  ]
}"#;

        assert_eq!(response_borsh.to_hex(), expected_response_borsh_hex);
        assert_eq!(response_json, expected_response_json);
    }
}
