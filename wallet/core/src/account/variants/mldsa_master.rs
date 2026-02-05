use crate::account::{Account, AccountKind, Inner};
use crate::deterministic::{from_mldsa_master, make_account_hashes};
use crate::imports::*;
use crate::serializer::StorageHeader;
use crate::storage::account::{AccountSettings, AccountStorable, AccountStorage};
use crate::storage::{AccountMetadata, PrvKeyDataId, Storable};
use kaspa_addresses::{Address, Version};
use kaspa_mldsa::{MASTER_SIGN_DOMAIN_DELEGATION, MasterSeed, MlDsaLevel, Signature as MlDsaSignature, try_sign as mldsa_try_sign};
use kaspa_utils::hex::ToHex;
use kaspa_wallet_keys::keypair_mldsa::{MasterAnchor, MlDsaKeypair};
use std::borrow::Cow;
use std::io::{Error as IoError, ErrorKind as IoErrorKind, Result as IoResult};

pub fn format_master_anchor_short(anchor: &MasterAnchor) -> String {
    let bytes = anchor.as_bytes();
    bytes[..4].to_vec().to_hex()
}

/// Account kind identifier for MLDSA master accounts.
pub const MLDSA_MASTER_ACCOUNT_KIND: &str = "kaspa-mldsa-master";

/// Stored payload for the MLDSA master account.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MldsaMasterAccountPayloadV1 {
    pub master_id: PrvKeyDataId,
    pub anchor: MasterAnchor,
    pub master_pubkey: Vec<u8>,
    pub level: MlDsaLevel,
    pub created_at_daa: u64,
    pub status: MasterStatus,
    pub delegations: Vec<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MasterStatus {
    Active,
    Rotated { rotated_at_daa: u64, new_anchor: Option<MasterAnchor> },
    Revoked { revoked_at_daa: u64 },
}

impl BorshSerialize for MasterStatus {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        match self {
            MasterStatus::Active => BorshSerialize::serialize(&0u8, writer),
            MasterStatus::Rotated { rotated_at_daa, new_anchor } => {
                BorshSerialize::serialize(&1u8, writer)?;
                BorshSerialize::serialize(rotated_at_daa, writer)?;
                let has_anchor = new_anchor.is_some();
                BorshSerialize::serialize(&has_anchor, writer)?;
                if let Some(anchor) = new_anchor {
                    BorshSerialize::serialize(anchor.as_bytes(), writer)?;
                }
                Ok(())
            }
            MasterStatus::Revoked { revoked_at_daa } => {
                BorshSerialize::serialize(&2u8, writer)?;
                BorshSerialize::serialize(revoked_at_daa, writer)
            }
        }
    }
}

impl BorshDeserialize for MasterStatus {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> IoResult<Self> {
        let tag: u8 = BorshDeserialize::deserialize_reader(reader)?;
        match tag {
            0 => Ok(MasterStatus::Active),
            1 => {
                let rotated_at_daa: u64 = BorshDeserialize::deserialize_reader(reader)?;
                let has_anchor: bool = BorshDeserialize::deserialize_reader(reader)?;
                let new_anchor = if has_anchor {
                    let anchor_bytes: [u8; 32] = BorshDeserialize::deserialize_reader(reader)?;
                    Some(MasterAnchor::new(anchor_bytes))
                } else {
                    None
                };
                Ok(MasterStatus::Rotated { rotated_at_daa, new_anchor })
            }
            2 => {
                let revoked_at_daa: u64 = BorshDeserialize::deserialize_reader(reader)?;
                Ok(MasterStatus::Revoked { revoked_at_daa })
            }
            other => Err(IoError::new(IoErrorKind::InvalidData, format!("invalid MasterStatus tag {other}"))),
        }
    }
}

impl Storable for MldsaMasterAccountPayloadV1 {
    const STORAGE_MAGIC: u32 = 0x4D4C_4D41; // "MLMA"
    const STORAGE_VERSION: u32 = 0;
}

impl AccountStorable for MldsaMasterAccountPayloadV1 {}

impl BorshSerialize for MldsaMasterAccountPayloadV1 {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        StorageHeader::new(Self::STORAGE_MAGIC, Self::STORAGE_VERSION).serialize(writer)?;
        BorshSerialize::serialize(&self.master_id, writer)?;
        BorshSerialize::serialize(&self.anchor.as_bytes(), writer)?;
        BorshSerialize::serialize(&self.master_pubkey, writer)?;
        BorshSerialize::serialize(&(self.level as u8), writer)?;
        BorshSerialize::serialize(&self.created_at_daa, writer)?;
        BorshSerialize::serialize(&self.status, writer)?;
        BorshSerialize::serialize(&self.delegations, writer)?;
        Ok(())
    }
}

impl BorshDeserialize for MldsaMasterAccountPayloadV1 {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> IoResult<Self> {
        let StorageHeader { version, .. } =
            StorageHeader::deserialize_reader(reader)?.try_magic(Self::STORAGE_MAGIC)?.try_version(Self::STORAGE_VERSION)?;

        let master_id = BorshDeserialize::deserialize_reader(reader)?;
        let anchor_bytes: [u8; 32] = BorshDeserialize::deserialize_reader(reader)?;
        let master_pubkey: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
        let level_raw: u8 = BorshDeserialize::deserialize_reader(reader)?;
        let created_at_daa: u64 = BorshDeserialize::deserialize_reader(reader)?;
        let status: MasterStatus = BorshDeserialize::deserialize_reader(reader)?;
        let delegations: Vec<u64> = BorshDeserialize::deserialize_reader(reader)?;

        if version != 0 {
            return Err(IoError::new(IoErrorKind::InvalidData, format!("unsupported MLDSA master payload version {version}")));
        }

        if master_pubkey.is_empty() {
            return Err(IoError::new(IoErrorKind::InvalidData, "empty master_pubkey"));
        }

        let level = MlDsaLevel::from_u8(level_raw)
            .ok_or(IoError::new(IoErrorKind::InvalidData, format!("invalid MLDSA level {level_raw}")))?;

        if master_pubkey.len() != level.public_key_len() {
            return Err(IoError::new(
                IoErrorKind::InvalidData,
                format!("invalid master_pubkey length: expected {}, got {}", level.public_key_len(), master_pubkey.len()),
            ));
        }

        Ok(Self { master_id, anchor: MasterAnchor::new(anchor_bytes), master_pubkey, level, created_at_daa, status, delegations })
    }
}

pub struct Ctor {}

#[async_trait]
impl crate::factory::Factory for Ctor {
    fn name(&self) -> String {
        "MLDSA Master".to_string()
    }

    fn description(&self) -> String {
        "Post-quantum master account (anchor + metadata)".to_string()
    }

    async fn try_load(
        &self,
        wallet: &Arc<Wallet>,
        storage: &AccountStorage,
        meta: Option<Arc<AccountMetadata>>,
    ) -> Result<Arc<dyn Account>> {
        Ok(Arc::new(MldsaMasterAccount::try_load(wallet, storage, meta).await?))
    }
}

pub struct MldsaMasterAccount {
    inner: Arc<Inner>,
    prv_key_data_id: PrvKeyDataId,
    anchor: MasterAnchor,
    master_pubkey: Vec<u8>,
    level: MlDsaLevel,
    created_at_daa: u64,
    status: MasterStatus,
    delegations: Vec<u64>,
    unlocked_keypair: Arc<AsyncRwLock<Option<MlDsaKeypair>>>,
}

impl MldsaMasterAccount {
    #[allow(clippy::too_many_arguments)]
    pub async fn try_new(
        wallet: &Arc<Wallet>,
        name: Option<String>,
        master_id: PrvKeyDataId,
        anchor: MasterAnchor,
        master_pubkey: Vec<u8>,
        level: MlDsaLevel,
        created_at_daa: u64,
        status: MasterStatus,
        delegations: Vec<u64>,
    ) -> Result<Self> {
        let storable = MldsaMasterAccountPayloadV1 { master_id, anchor, master_pubkey, level, created_at_daa, status, delegations };

        let settings = AccountSettings { name, ..Default::default() };
        let (id, storage_key) = make_account_hashes(from_mldsa_master(&master_id, &anchor));
        let inner = Arc::new(Inner::new(wallet, id, storage_key, settings));

        Ok(Self {
            inner,
            prv_key_data_id: master_id,
            anchor,
            master_pubkey: storable.master_pubkey.clone(),
            level,
            created_at_daa,
            status: storable.status.clone(),
            delegations: storable.delegations.clone(),
            unlocked_keypair: Arc::new(AsyncRwLock::new(None)),
        })
    }

    pub async fn try_load(wallet: &Arc<Wallet>, storage: &AccountStorage, _meta: Option<Arc<AccountMetadata>>) -> Result<Self> {
        let payload = MldsaMasterAccountPayloadV1::try_from_slice(storage.serialized.as_slice())?;
        let inner = Arc::new(Inner::from_storage(wallet, storage));
        let prv_key_data_id: PrvKeyDataId = storage.prv_key_data_ids.clone().try_into()?;

        Ok(Self {
            inner,
            prv_key_data_id,
            anchor: payload.anchor,
            master_pubkey: payload.master_pubkey,
            level: payload.level,
            created_at_daa: payload.created_at_daa,
            status: payload.status,
            delegations: payload.delegations,
            unlocked_keypair: Arc::new(AsyncRwLock::new(None)),
        })
    }

    pub async fn unlock_with_master_keypair(&self, keypair: MlDsaKeypair) -> Result<()> {
        if keypair.anchor() != self.anchor {
            return Err(Error::Custom("Master anchor mismatch during unlock".to_string()));
        }
        let mut guard = self.unlocked_keypair.write().await;
        *guard = Some(keypair);
        Ok(())
    }

    pub async fn lock(&self) {
        let mut guard = self.unlocked_keypair.write().await;
        *guard = None;
    }

    pub fn anchor(&self) -> &MasterAnchor {
        &self.anchor
    }

    pub fn level(&self) -> MlDsaLevel {
        self.level
    }

    pub async fn unlock_with_master_seed(&self, master_seed: &MasterSeed, level: MlDsaLevel) -> Result<()> {
        if level != self.level {
            return Err(Error::Custom("Requested MLDSA level does not match account level".to_string()));
        }

        let (keypair, derived_anchor) = MlDsaKeypair::from_master_seed(master_seed, level)?;
        if derived_anchor != self.anchor {
            return Err(Error::Custom("Master anchor mismatch during unlock".to_string()));
        }

        self.unlock_with_master_keypair(keypair).await
    }

    pub async fn sign_message(&self, domain: &MasterSignDomain, payload: &[u8]) -> Result<MlDsaSignature> {
        let guard = self.unlocked_keypair.read().await;
        let keypair = guard.as_ref().ok_or(Error::AccountLocked)?;

        let domain_tag = domain.tag();
        let mut message = Vec::with_capacity(domain_tag.len() + self.anchor.as_bytes().len() + payload.len());
        message.extend_from_slice(&domain_tag);
        message.extend_from_slice(self.anchor.as_bytes());
        message.extend_from_slice(payload);

        let signature =
            mldsa_try_sign(&message, &keypair.inner().secret_key).map_err(|e| Error::Custom(format!("MLDSA signing failed: {e}")))?;
        MasterMetrics::global().inc_sign_ops();
        log_trace!("MLDSA master sign: master_anchor={} domain={:?}", format_master_anchor_short(&self.anchor), domain);
        Ok(signature)
    }

    /// Signs a delegation hash exactly as produced by `delegation_message_hash`
    /// (no additional domain/tag/anchor prefix). This is the canonical
    /// signature format for delegation records.
    pub async fn sign_delegation_hash(&self, payload: &[u8]) -> Result<MlDsaSignature> {
        let guard = self.unlocked_keypair.read().await;
        let keypair = guard.as_ref().ok_or(Error::AccountLocked)?;
        let signature =
            mldsa_try_sign(payload, &keypair.inner().secret_key).map_err(|e| Error::Custom(format!("MLDSA signing failed: {e}")))?;
        MasterMetrics::global().inc_sign_ops();
        Ok(signature)
    }
}

#[async_trait]
impl Account for MldsaMasterAccount {
    fn inner(&self) -> &Arc<Inner> {
        &self.inner
    }

    fn account_kind(&self) -> AccountKind {
        MLDSA_MASTER_ACCOUNT_KIND.into()
    }

    fn prv_key_data_id(&self) -> Result<&PrvKeyDataId> {
        Ok(&self.prv_key_data_id)
    }

    fn as_dyn_arc(self: Arc<Self>) -> Arc<dyn Account> {
        self
    }

    fn sig_op_count(&self) -> u8 {
        1
    }

    fn minimum_signatures(&self) -> u16 {
        1
    }

    fn receive_address(&self) -> Result<Address> {
        // `Version::PubKeyMLDSA` in kaspa addresses is currently fixed to ML-DSA Level 2 (1312 bytes).
        // Master accounts may use higher ML-DSA levels for off-chain protocols (delegations), so
        // we must not panic here. Instead, return a clear error when an on-chain address cannot
        // be constructed for the current master level.
        if self.level != MlDsaLevel::Level2 {
            return Err(Error::Custom(format!(
                "MLDSA master receive address is only supported for Level2; current level is {:?}",
                self.level
            )));
        }
        if self.master_pubkey.len() != MlDsaLevel::Level2.public_key_len() {
            return Err(Error::Custom(format!(
                "invalid MLDSA master pubkey length: expected {}, got {}",
                MlDsaLevel::Level2.public_key_len(),
                self.master_pubkey.len()
            )));
        }

        Ok(Address::new(self.inner().wallet.network_id()?.into(), Version::PubKeyMLDSA, &self.master_pubkey))
    }

    fn change_address(&self) -> Result<Address> {
        self.receive_address()
    }

    fn to_storage(&self) -> Result<AccountStorage> {
        let settings = self.context().settings.clone();
        let storable = MldsaMasterAccountPayloadV1 {
            master_id: self.prv_key_data_id,
            anchor: self.anchor,
            master_pubkey: self.master_pubkey.clone(),
            level: self.level,
            created_at_daa: self.created_at_daa,
            status: self.status.clone(),
            delegations: self.delegations.clone(),
        };

        let account_storage = AccountStorage::try_new(
            MLDSA_MASTER_ACCOUNT_KIND.into(),
            self.id(),
            self.storage_key(),
            self.prv_key_data_id.into(),
            settings,
            storable,
        )?;

        Ok(account_storage)
    }

    fn metadata(&self) -> Result<Option<AccountMetadata>> {
        Ok(None)
    }

    fn descriptor(&self) -> Result<crate::account::descriptor::AccountDescriptor> {
        let receive = self.receive_address().ok();
        let descriptor = crate::account::descriptor::AccountDescriptor::new(
            MLDSA_MASTER_ACCOUNT_KIND.into(),
            *self.id(),
            self.name(),
            self.balance(),
            self.prv_key_data_id.into(),
            receive.clone(),
            receive,
            None,
        )
        .with_property(
            crate::account::descriptor::AccountDescriptorProperty::Other("anchor".to_string()),
            self.anchor.to_string().into(),
        )
        .with_property(
            crate::account::descriptor::AccountDescriptorProperty::Other("level".to_string()),
            format!("{:?}", self.level).into(),
        )
        .with_property(
            crate::account::descriptor::AccountDescriptorProperty::Other("status".to_string()),
            serde_json::to_string(&self.status).unwrap_or_default().into(),
        );

        Ok(descriptor)
    }
}

/// Domain separation for master signatures.
#[derive(Debug, Clone)]
pub enum MasterSignDomain {
    AnchorExport,
    Delegation,
    Custom(String),
}

impl MasterSignDomain {
    fn tag(&self) -> Cow<'static, [u8]> {
        match self {
            MasterSignDomain::AnchorExport => Cow::Borrowed(b"mldsa.master.anchor-export"),
            MasterSignDomain::Delegation => Cow::Borrowed(MASTER_SIGN_DOMAIN_DELEGATION),
            MasterSignDomain::Custom(custom) => {
                let mut prefix = b"mldsa.master.custom:".to_vec();
                prefix.extend_from_slice(custom.as_bytes());
                Cow::Owned(prefix)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn payload_rejects_wrong_pubkey_length() {
        let payload = MldsaMasterAccountPayloadV1 {
            master_id: PrvKeyDataId::new(1),
            anchor: MasterAnchor::new([0u8; 32]),
            master_pubkey: vec![0u8; 10],
            level: MlDsaLevel::Level2,
            created_at_daa: 0,
            status: MasterStatus::Active,
            delegations: vec![],
        };

        let encoded = borsh::to_vec(&payload).expect("serialize");
        let err = MldsaMasterAccountPayloadV1::try_from_slice(&encoded).expect_err("must fail on invalid pubkey length");
        assert!(err.to_string().contains("invalid master_pubkey length"));
    }

    #[test]
    fn domain_tags_are_prefixed() {
        assert_eq!(MasterSignDomain::AnchorExport.tag().as_ref(), b"mldsa.master.anchor-export");
        assert_eq!(MasterSignDomain::Delegation.tag().as_ref(), b"mldsa.master.delegation");
        let custom = MasterSignDomain::Custom("abc".to_string()).tag().into_owned();
        assert!(custom.starts_with(b"mldsa.master.custom:"));
        assert!(custom.ends_with(b"abc"));
    }
}
