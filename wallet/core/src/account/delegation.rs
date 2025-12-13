use crate::deterministic::AccountId;
use crate::error::Error;
use crate::result::Result;
use blake2b_simd::Params;
use borsh::{BorshDeserialize, BorshSerialize};
use kaspa_mldsa::{sign, verify, MlDsaLevel, PublicKey as MlDsaPublicKey};
use kaspa_wallet_keys::keypair_mldsa::{MasterAnchor, MlDsaKeypair};
use serde::{Deserialize, Serialize};

pub const DOMAIN_MLDSA_DELEGATION: &[u8] = b"kaspa.mldsa.delegation.v1";
pub const DOMAIN_MLDSA_DELEGATION_REVOKE: &[u8] = b"kaspa.mldsa.delegation.revoke.v1";

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[repr(transparent)]
pub struct DelegationId(pub u64);

impl From<u64> for DelegationId {
    fn from(value: u64) -> Self {
        Self(value)
    }
}

impl From<DelegationId> for u64 {
    fn from(value: DelegationId) -> Self {
        value.0
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub enum DelegationStatus {
    #[default]
    Active,
    Revoked {
        revoked_daa: u64,
    },
    Expired {
        expired_daa: u64,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DelegationRecordV1 {
    pub version: u8,
    pub level: u8,
    #[serde(with = "crate::message::serde_hex_array_32")]
    pub anchor: [u8; 32],
    pub account_id: AccountId,
    #[serde(with = "crate::message::serde_hex_array_32")]
    pub spend_pubkey: [u8; 32],
    #[serde(with = "crate::message::serde_hex_array_32")]
    pub scan_pubkey: [u8; 32],
    pub valid_from_daa: u64,
    pub valid_until_daa: Option<u64>,
    pub nonce: u64,
    pub status: DelegationStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub warned_at_daa: Option<u64>,
    #[serde(with = "crate::message::serde_base64_bytes")]
    pub signature: Vec<u8>,
}

impl DelegationRecordV1 {
    pub fn new(
        level: MlDsaLevel,
        anchor: [u8; 32],
        account_id: AccountId,
        spend_pubkey: [u8; 32],
        scan_pubkey: [u8; 32],
        valid_from_daa: u64,
        valid_until_daa: Option<u64>,
        nonce: u64,
        status: DelegationStatus,
    ) -> Self {
        Self {
            version: 2,
            level: level as u8,
            anchor,
            account_id,
            spend_pubkey,
            scan_pubkey,
            valid_from_daa,
            valid_until_daa,
            nonce,
            status,
            warned_at_daa: None,
            signature: Vec::new(),
        }
    }

    pub fn signature_len(&self) -> Option<usize> {
        MlDsaLevel::from_u8(self.level).map(|lvl| lvl.signature_len())
    }

    pub fn warned_recently(&self, current_daa: u64, warn_window_daa: u64) -> bool {
        match self.warned_at_daa {
            None => false,
            Some(prev) => current_daa.saturating_sub(prev) < warn_window_daa,
        }
    }

    pub fn set_warned_at(&mut self, current_daa: u64) {
        self.warned_at_daa = Some(current_daa);
    }
}

impl BorshSerialize for DelegationRecordV1 {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        BorshSerialize::serialize(&self.version, writer)?;
        BorshSerialize::serialize(&self.level, writer)?;
        BorshSerialize::serialize(&self.anchor, writer)?;
        BorshSerialize::serialize(&self.account_id, writer)?;
        BorshSerialize::serialize(&self.spend_pubkey, writer)?;
        BorshSerialize::serialize(&self.scan_pubkey, writer)?;
        BorshSerialize::serialize(&self.valid_from_daa, writer)?;
        BorshSerialize::serialize(&self.valid_until_daa, writer)?;
        BorshSerialize::serialize(&self.nonce, writer)?;
        BorshSerialize::serialize(&self.status, writer)?;
        if self.version >= 2 {
            BorshSerialize::serialize(&self.warned_at_daa, writer)?;
        }
        BorshSerialize::serialize(&self.signature, writer)?;
        Ok(())
    }
}

impl BorshDeserialize for DelegationRecordV1 {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let version: u8 = BorshDeserialize::deserialize_reader(reader)?;
        let level: u8 = BorshDeserialize::deserialize_reader(reader)?;
        let anchor: [u8; 32] = BorshDeserialize::deserialize_reader(reader)?;
        let account_id: AccountId = BorshDeserialize::deserialize_reader(reader)?;
        let spend_pubkey: [u8; 32] = BorshDeserialize::deserialize_reader(reader)?;
        let scan_pubkey: [u8; 32] = BorshDeserialize::deserialize_reader(reader)?;
        let valid_from_daa: u64 = BorshDeserialize::deserialize_reader(reader)?;
        let valid_until_daa: Option<u64> = BorshDeserialize::deserialize_reader(reader)?;
        let nonce: u64 = BorshDeserialize::deserialize_reader(reader)?;
        let status: DelegationStatus = BorshDeserialize::deserialize_reader(reader)?;
        let warned_at_daa = if version >= 2 { BorshDeserialize::deserialize_reader(reader)? } else { None };
        let signature: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;

        Ok(Self {
            version,
            level,
            anchor,
            account_id,
            spend_pubkey,
            scan_pubkey,
            valid_from_daa,
            valid_until_daa,
            nonce,
            status,
            warned_at_daa,
            signature,
        })
    }
}

pub fn delegation_message_hash(record: &DelegationRecordV1) -> Result<[u8; 32]> {
    let mut clone = record.clone();
    clone.signature.clear();
    // `warned_at_daa` — локальная мета-информация (троттлинг уведомлений) и не должна
    // влиять на подпись/валидацию делегации. Хэш всегда считается так, как будто
    // `warned_at_daa` отсутствует.
    clone.warned_at_daa = None;
    let serialized = borsh::to_vec(&clone).map_err(|e| Error::Custom(format!("delegation borsh encode: {e}")))?;

    let mut hasher = Params::new().hash_length(32).key(DOMAIN_MLDSA_DELEGATION).to_state();
    hasher.update(&serialized);
    let mut out = [0u8; 32];
    out.copy_from_slice(hasher.finalize().as_bytes());
    Ok(out)
}

pub fn sign_with_master(master_key: &MlDsaKeypair, record: &mut DelegationRecordV1) -> Result<()> {
    let hash = delegation_message_hash(record)?;
    let sig = sign(hash.as_slice(), master_key.secret_key());

    let expected_len = record.signature_len().ok_or_else(|| Error::Custom("invalid delegation level".to_string()))?;

    if sig.as_bytes().len() != expected_len {
        return Err(Error::Custom(format!("invalid delegation signature length {}", sig.as_bytes().len())));
    }

    record.signature = sig.as_bytes().to_vec();
    Ok(())
}

pub fn verify_against_anchor(anchor: &MasterAnchor, master_pubkey: &[u8], record: &DelegationRecordV1) -> Result<bool> {
    if record.anchor != *anchor.as_bytes() {
        return Ok(false);
    }

    let level = MlDsaLevel::from_u8(record.level).ok_or_else(|| Error::Custom(format!("unsupported MLDSA level {}", record.level)))?;

    let pubkey = MlDsaPublicKey::from_bytes(master_pubkey, level).map_err(|e| Error::Custom(format!("invalid master pubkey: {e}")))?;

    let sig_len = level.signature_len();
    if record.signature.len() != sig_len {
        return Ok(false);
    }

    let sig = kaspa_mldsa::Signature::from_bytes(&record.signature, level)
        .map_err(|e| Error::Custom(format!("invalid delegation signature: {e}")))?;

    // Основной путь: хэш по текущей версии записи, но с `warned_at_daa = None`.
    let hash = delegation_message_hash(record)?;
    if verify(hash.as_slice(), &sig, &pubkey) {
        return Ok(true);
    }

    // Совместимость: если в сторах оказалась запись, у которой `version` была повышена
    // локально (например, чтобы попытаться сохранить `warned_at_daa`), подпись могла
    // быть рассчитана на прежней версии. Пробуем повторно с version=1.
    if record.version != 1 {
        let mut legacy = record.clone();
        legacy.version = 1;
        legacy.warned_at_daa = None;
        legacy.signature.clear();
        let serialized = borsh::to_vec(&legacy).map_err(|e| Error::Custom(format!("delegation borsh encode: {e}")))?;
        let mut hasher = Params::new().hash_length(32).key(DOMAIN_MLDSA_DELEGATION).to_state();
        hasher.update(&serialized);
        let mut out = [0u8; 32];
        out.copy_from_slice(hasher.finalize().as_bytes());
        return Ok(verify(out.as_slice(), &sig, &pubkey));
    }

    Ok(false)
}

pub fn select_active(records: &[DelegationRecordV1]) -> Option<DelegationRecordV1> {
    records
        .iter()
        .filter(|r| matches!(r.status, DelegationStatus::Active))
        .max_by_key(|r| (r.nonce, r.valid_from_daa, r.valid_until_daa.unwrap_or(u64::MAX)))
        .cloned()
}

#[cfg(test)]
mod tests {
    use super::*;
    use kaspa_hashes::Hash;
    use kaspa_mldsa::MlDsaLevel;
    use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
    use serde_json::{from_str, to_string};

    fn sample_account_id() -> AccountId {
        AccountId(Hash::from_u64_word(42))
    }

    fn base_record() -> DelegationRecordV1 {
        DelegationRecordV1::new(
            MlDsaLevel::Level2,
            [1u8; 32],
            sample_account_id(),
            [2u8; 32],
            [3u8; 32],
            100,
            Some(200),
            1,
            DelegationStatus::Active,
        )
    }

    #[test]
    fn borsh_roundtrip_preserves_record() {
        let mut record = base_record();
        record.signature = vec![9u8; 4];

        let bytes = borsh::to_vec(&record).expect("encode");
        let decoded = DelegationRecordV1::try_from_slice(&bytes).expect("decode");
        assert_eq!(decoded, record);
    }

    #[test]
    fn serde_roundtrip_preserves_record() {
        let record = base_record();
        let json = to_string(&record).expect("serde serialize");
        let decoded: DelegationRecordV1 = from_str(&json).expect("serde deserialize");
        assert_eq!(decoded, record);
    }

    #[test]
    fn hash_ignores_signature_but_changes_with_fields() {
        let record = base_record();
        let mut with_signature = record.clone();
        with_signature.signature = vec![1u8; 16];

        let hash_without_sig = delegation_message_hash(&record).expect("hash");
        let hash_with_sig = delegation_message_hash(&with_signature).expect("hash");
        assert_eq!(hash_without_sig, hash_with_sig, "signature must be ignored");

        let mut warned = record.clone();
        warned.version = warned.version.max(2);
        warned.warned_at_daa = Some(12345);
        assert_eq!(hash_without_sig, delegation_message_hash(&warned).expect("hash"), "warned_at_daa must not affect hash");

        let mut different_anchor = record.clone();
        different_anchor.anchor = [9u8; 32];
        assert_ne!(hash_without_sig, delegation_message_hash(&different_anchor).expect("hash"), "anchor must change hash");

        let mut different_nonce = record.clone();
        different_nonce.nonce += 1;
        assert_ne!(hash_without_sig, delegation_message_hash(&different_nonce).expect("hash"), "nonce must change hash");
    }

    #[test]
    fn select_active_prefers_highest_nonce_and_skips_inactive() {
        let mut a = base_record();
        a.nonce = 1;

        let mut b = base_record();
        b.nonce = 2;

        let mut c = base_record();
        c.nonce = 3;
        c.status = DelegationStatus::Revoked { revoked_daa: 150 };

        let selected = select_active(&[a.clone(), b.clone(), c.clone()]).expect("active record");
        assert_eq!(selected.nonce, b.nonce);
        assert_eq!(selected.status, DelegationStatus::Active);
    }

    #[test]
    fn sign_and_verify_roundtrip() {
        let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);
        let anchor = keypair.anchor();

        let mut record = DelegationRecordV1::new(
            MlDsaLevel::Level2,
            *anchor.as_bytes(),
            sample_account_id(),
            [5u8; 32],
            [6u8; 32],
            10,
            None,
            7,
            DelegationStatus::Active,
        );

        sign_with_master(&keypair, &mut record).expect("sign");
        assert_eq!(record.signature.len(), keypair.signature_size());

        let verified = verify_against_anchor(&anchor, keypair.public_key().as_bytes(), &record).expect("verify");
        assert!(verified);
    }

    #[test]
    fn verify_fails_for_anchor_mismatch_or_corrupted_signature() {
        let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);
        let anchor = keypair.anchor();

        let mut record = DelegationRecordV1::new(
            MlDsaLevel::Level2,
            *anchor.as_bytes(),
            sample_account_id(),
            [5u8; 32],
            [6u8; 32],
            10,
            None,
            7,
            DelegationStatus::Active,
        );
        sign_with_master(&keypair, &mut record).expect("sign");

        let mut wrong_anchor_record = record.clone();
        wrong_anchor_record.anchor = [0u8; 32];
        let anchor_mismatch = verify_against_anchor(&anchor, keypair.public_key().as_bytes(), &wrong_anchor_record).expect("verify");
        assert!(!anchor_mismatch);

        let mut corrupted = record.clone();
        corrupted.signature[0] ^= 0xFF;
        let corrupted_sig = verify_against_anchor(&anchor, keypair.public_key().as_bytes(), &corrupted).expect("verify");
        assert!(!corrupted_sig);
    }
}
