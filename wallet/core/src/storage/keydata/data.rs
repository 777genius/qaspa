//!
//! Private key storage and encryption.
//!

use crate::derivation::create_xpub_from_xprv;
use crate::encryption::{Decrypted, decrypt_xchacha20poly1305, encrypt_xchacha20poly1305};
use crate::imports::*;
use kaspa_bip32::{ExtendedPrivateKey, ExtendedPublicKey, Language, Mnemonic};
use kaspa_mldsa::MlDsaLevel;
use kaspa_utils::hex::ToHex;
use kaspa_wallet_keys::keypair_mldsa::MasterAnchor;
use secp256k1::SecretKey;
use xxhash_rust::xxh3::xxh3_64;

#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize, PartialEq, Eq)]
pub enum PrvKeyDataVariantKind {
    Mnemonic,
    Bip39Seed,
    ExtendedPrivateKey,
    SecretKey,
    MlDsaMaster,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
#[serde(tag = "key-variant", content = "key-data")]
pub enum PrvKeyDataVariant {
    // 12 or 24 word bip39 mnemonic
    Mnemonic(String),
    // Bip39 seed (generated from mnemonic)
    Bip39Seed(String),
    // Extended Private Key (XPrv)
    ExtendedPrivateKey(String),
    // secp256k1::SecretKey
    SecretKey(String),
    MlDsaMaster(MlDsaMasterPayload),
}

impl BorshSerialize for PrvKeyDataVariant {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        StorageHeader::new(Self::MAGIC, Self::VERSION).serialize(writer)?;
        let kind = self.kind();
        BorshSerialize::serialize(&kind, writer)?;

        match self {
            PrvKeyDataVariant::Mnemonic(value)
            | PrvKeyDataVariant::Bip39Seed(value)
            | PrvKeyDataVariant::ExtendedPrivateKey(value)
            | PrvKeyDataVariant::SecretKey(value) => {
                BorshSerialize::serialize(value.as_str(), writer)?;
            }
            PrvKeyDataVariant::MlDsaMaster(payload) => {
                BorshSerialize::serialize(payload, writer)?;
            }
        }

        Ok(())
    }
}

impl BorshDeserialize for PrvKeyDataVariant {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> IoResult<Self> {
        let StorageHeader { version: _, .. } =
            StorageHeader::deserialize_reader(reader)?.try_magic(Self::MAGIC)?.try_version(Self::VERSION)?;

        let kind: PrvKeyDataVariantKind = BorshDeserialize::deserialize_reader(reader)?;

        match kind {
            PrvKeyDataVariantKind::Mnemonic => {
                let string: String = BorshDeserialize::deserialize_reader(reader)?;
                Ok(Self::Mnemonic(string))
            }
            PrvKeyDataVariantKind::Bip39Seed => {
                let string: String = BorshDeserialize::deserialize_reader(reader)?;
                Ok(Self::Bip39Seed(string))
            }
            PrvKeyDataVariantKind::ExtendedPrivateKey => {
                let string: String = BorshDeserialize::deserialize_reader(reader)?;
                Ok(Self::ExtendedPrivateKey(string))
            }
            PrvKeyDataVariantKind::SecretKey => {
                let string: String = BorshDeserialize::deserialize_reader(reader)?;
                Ok(Self::SecretKey(string))
            }
            PrvKeyDataVariantKind::MlDsaMaster => {
                let payload: MlDsaMasterPayload = BorshDeserialize::deserialize_reader(reader)?;
                Ok(Self::MlDsaMaster(payload))
            }
        }
    }
}

impl PrvKeyDataVariant {
    const MAGIC: u32 = 0x5652504b;
    const VERSION: u32 = 0;

    pub fn kind(&self) -> PrvKeyDataVariantKind {
        match self {
            PrvKeyDataVariant::Mnemonic(_) => PrvKeyDataVariantKind::Mnemonic,
            PrvKeyDataVariant::Bip39Seed(_) => PrvKeyDataVariantKind::Bip39Seed,
            PrvKeyDataVariant::ExtendedPrivateKey(_) => PrvKeyDataVariantKind::ExtendedPrivateKey,
            PrvKeyDataVariant::SecretKey(_) => PrvKeyDataVariantKind::SecretKey,
            PrvKeyDataVariant::MlDsaMaster(_) => PrvKeyDataVariantKind::MlDsaMaster,
        }
    }

    pub fn from_mnemonic(mnemonic: Mnemonic) -> Self {
        PrvKeyDataVariant::Mnemonic(mnemonic.phrase_string())
    }

    pub fn from_secret_key(secret_key: SecretKey) -> Self {
        PrvKeyDataVariant::SecretKey(secret_key.secret_bytes().to_vec().to_hex())
    }

    pub fn from_mldsa_master(payload: MlDsaMasterPayload) -> Self {
        PrvKeyDataVariant::MlDsaMaster(payload)
    }

    pub fn get_string(&self) -> Zeroizing<String> {
        match self {
            PrvKeyDataVariant::Mnemonic(s) => Zeroizing::new(s.clone()),
            PrvKeyDataVariant::Bip39Seed(s) => Zeroizing::new(s.clone()),
            PrvKeyDataVariant::ExtendedPrivateKey(s) => Zeroizing::new(s.clone()),
            PrvKeyDataVariant::SecretKey(s) => Zeroizing::new(s.clone()),
            PrvKeyDataVariant::MlDsaMaster(payload) => Zeroizing::new(payload.key_id()),
        }
    }

    pub fn id(&self) -> PrvKeyDataId {
        let s = PrvKeyDataVariant::get_string(self); //self.get_string();
        PrvKeyDataId::new(xxh3_64(s.as_bytes()))
    }
}

impl Zeroize for PrvKeyDataVariant {
    fn zeroize(&mut self) {
        match self {
            PrvKeyDataVariant::Mnemonic(s) => s.zeroize(),
            PrvKeyDataVariant::Bip39Seed(s) => s.zeroize(),
            PrvKeyDataVariant::ExtendedPrivateKey(s) => s.zeroize(),
            PrvKeyDataVariant::SecretKey(s) => s.zeroize(),
            PrvKeyDataVariant::MlDsaMaster(payload) => payload.zeroize(),
        }
    }
}
impl Drop for PrvKeyDataVariant {
    fn drop(&mut self) {
        self.zeroize()
    }
}

impl ZeroizeOnDrop for PrvKeyDataVariant {}

#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct MlDsaMasterPayload {
    level: u8,
    anchor: [u8; 32],
    seed_cipher: Vec<u8>,
}

impl MlDsaMasterPayload {
    pub fn new(level: MlDsaLevel, anchor: MasterAnchor, seed_cipher: Vec<u8>) -> Self {
        Self { level: level as u8, anchor: *anchor.as_bytes(), seed_cipher }
    }

    pub fn level(&self) -> Option<MlDsaLevel> {
        MlDsaLevel::from_u8(self.level)
    }

    pub fn anchor(&self) -> MasterAnchor {
        MasterAnchor::new(self.anchor)
    }

    pub fn seed_cipher(&self) -> &[u8] {
        &self.seed_cipher
    }

    fn key_id(&self) -> String {
        format!("mldsa:{:02x}:{}", self.level, self.anchor.to_vec().to_hex())
    }

    pub fn decrypt_seed(&self, wallet_secret: &Secret) -> Result<Zeroizing<Vec<u8>>> {
        let decrypted = decrypt_xchacha20poly1305(self.seed_cipher(), wallet_secret)?;
        Ok(Zeroizing::new(decrypted.as_ref().to_vec()))
    }

    pub fn reencrypt_seed(&mut self, old_secret: &Secret, new_secret: &Secret) -> Result<()> {
        let decrypted = decrypt_xchacha20poly1305(self.seed_cipher(), old_secret)?;
        let new_cipher = encrypt_xchacha20poly1305(decrypted.as_ref(), new_secret)?;
        self.seed_cipher = new_cipher;
        Ok(())
    }
}

impl Zeroize for MlDsaMasterPayload {
    fn zeroize(&mut self) {
        self.anchor.zeroize();
        self.seed_cipher.zeroize();
    }
}

impl Drop for MlDsaMasterPayload {
    fn drop(&mut self) {
        self.zeroize()
    }
}

impl ZeroizeOnDrop for MlDsaMasterPayload {}

#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrvKeyDataPayload {
    prv_key_variant: PrvKeyDataVariant,
}

impl PrvKeyDataPayload {
    pub fn try_new_with_mnemonic(mnemonic: Mnemonic) -> Result<Self> {
        Ok(Self { prv_key_variant: PrvKeyDataVariant::from_mnemonic(mnemonic) })
    }

    pub fn try_new_with_secret_key(secret_key: SecretKey) -> Result<Self> {
        Ok(Self { prv_key_variant: PrvKeyDataVariant::from_secret_key(secret_key) })
    }

    pub fn try_new_with_mldsa_master(payload: MlDsaMasterPayload) -> Result<Self> {
        Ok(Self { prv_key_variant: PrvKeyDataVariant::from_mldsa_master(payload) })
    }

    pub fn get_xprv(&self, payment_secret: Option<&Secret>) -> Result<ExtendedPrivateKey<SecretKey>> {
        let payment_secret = payment_secret.map(|s| std::str::from_utf8(s.as_ref())).transpose()?;

        match &self.prv_key_variant {
            PrvKeyDataVariant::Mnemonic(mnemonic) => {
                let mnemonic = Mnemonic::new(mnemonic, Language::English)?;
                let xkey = ExtendedPrivateKey::<SecretKey>::new(mnemonic.to_seed(payment_secret.unwrap_or_default()))?;
                Ok(xkey)
            }
            PrvKeyDataVariant::Bip39Seed(seed) => {
                let seed = Zeroizing::new(Vec::from_hex(seed.as_ref())?);
                let xkey = ExtendedPrivateKey::<SecretKey>::new(seed)?;
                Ok(xkey)
            }
            PrvKeyDataVariant::ExtendedPrivateKey(extended_private_key) => {
                let xkey: ExtendedPrivateKey<SecretKey> = extended_private_key.parse()?;
                Ok(xkey)
            }
            PrvKeyDataVariant::SecretKey(_) | PrvKeyDataVariant::MlDsaMaster(_) => Err(Error::XPrvSupport),
        }
    }

    pub fn as_mnemonic(&self) -> Result<Option<Mnemonic>> {
        match &self.prv_key_variant {
            PrvKeyDataVariant::Mnemonic(mnemonic) => Ok(Some(Mnemonic::new(mnemonic.clone(), Language::English)?)),
            _ => Ok(None),
        }
    }

    pub fn as_variant(&self) -> Zeroizing<PrvKeyDataVariant> {
        Zeroizing::new(self.prv_key_variant.clone())
    }

    pub fn as_secret_key(&self) -> Result<Option<SecretKey>> {
        match &self.prv_key_variant {
            PrvKeyDataVariant::SecretKey(private_key) => Ok(Some(SecretKey::from_str(private_key)?)),
            _ => Ok(None),
        }
    }

    pub fn as_mldsa_master(&self) -> Result<Option<MlDsaMasterPayload>> {
        match &self.prv_key_variant {
            PrvKeyDataVariant::MlDsaMaster(payload) => Ok(Some(payload.clone())),
            _ => Ok(None),
        }
    }

    pub fn as_mldsa_master_mut(&mut self) -> Option<&mut MlDsaMasterPayload> {
        match &mut self.prv_key_variant {
            PrvKeyDataVariant::MlDsaMaster(payload) => Some(payload),
            _ => None,
        }
    }

    pub fn reencrypt_mldsa_master_seed(&mut self, old_secret: &Secret, new_secret: &Secret) -> Result<bool> {
        if let Some(payload) = self.as_mldsa_master_mut() {
            payload.reencrypt_seed(old_secret, new_secret)?;
            return Ok(true);
        }
        Ok(false)
    }

    pub fn id(&self) -> PrvKeyDataId {
        self.prv_key_variant.id()
    }
}

impl Zeroize for PrvKeyDataPayload {
    fn zeroize(&mut self) {
        self.prv_key_variant.zeroize();
    }
}

impl Drop for PrvKeyDataPayload {
    fn drop(&mut self) {
        self.zeroize()
    }
}

impl ZeroizeOnDrop for PrvKeyDataPayload {}

#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrvKeyData {
    pub id: PrvKeyDataId,
    pub name: Option<String>,
    pub payload: Encryptable<PrvKeyDataPayload>,
}

impl PrvKeyData {
    pub async fn create_xpub(
        &self,
        payment_secret: Option<&Secret>,
        account_kind: AccountKind,
        account_index: u64,
    ) -> Result<ExtendedPublicKey<secp256k1::PublicKey>> {
        let payload = self.payload.decrypt(payment_secret)?;
        let xprv = payload.get_xprv(payment_secret)?;
        create_xpub_from_xprv(xprv, account_kind, account_index).await
    }

    pub fn get_xprv(&self, payment_secret: Option<&Secret>) -> Result<ExtendedPrivateKey<secp256k1::SecretKey>> {
        let payload = self.payload.decrypt(payment_secret)?;
        payload.get_xprv(payment_secret)
    }

    pub fn as_mnemonic(&self, payment_secret: Option<&Secret>) -> Result<Option<Mnemonic>> {
        let payload = self.payload.decrypt(payment_secret)?;
        payload.as_mnemonic()
    }

    pub fn as_variant(&self, payment_secret: Option<&Secret>) -> Result<Zeroizing<PrvKeyDataVariant>> {
        let payload = self.payload.decrypt(payment_secret)?;
        Ok(payload.as_variant())
    }

    pub fn try_from_mnemonic(
        mnemonic: Mnemonic,
        payment_secret: Option<&Secret>,
        encryption_kind: EncryptionKind,
        name: Option<String>,
    ) -> Result<Self> {
        let key_data_payload = PrvKeyDataPayload::try_new_with_mnemonic(mnemonic)?;
        let key_data_payload_id = key_data_payload.id();
        let key_data_payload = Encryptable::Plain(key_data_payload);

        let mut prv_key_data = PrvKeyData::new(key_data_payload_id, name, key_data_payload);
        if let Some(payment_secret) = payment_secret {
            prv_key_data.encrypt(payment_secret, encryption_kind)?;
        }

        Ok(prv_key_data)
    }

    pub fn as_secret_key(&self, payment_secret: Option<&Secret>) -> Result<Option<SecretKey>> {
        let payload = self.payload.decrypt(payment_secret)?;
        payload.as_secret_key()
    }

    pub fn try_from_secret_key(
        secret_key: SecretKey,
        payment_secret: Option<&Secret>,
        encryption_kind: EncryptionKind,
        name: Option<String>,
    ) -> Result<Self> {
        let key_data_payload = PrvKeyDataPayload::try_new_with_secret_key(secret_key)?;
        let key_data_payload_id = key_data_payload.id();
        let key_data_payload = Encryptable::Plain(key_data_payload);

        let mut prv_key_data = PrvKeyData::new(key_data_payload_id, name, key_data_payload);
        if let Some(payment_secret) = payment_secret {
            prv_key_data.encrypt(payment_secret, encryption_kind)?;
        }

        Ok(prv_key_data)
    }

    pub fn try_new_mldsa_master(payload: MlDsaMasterPayload) -> Result<Self> {
        let payload = PrvKeyDataPayload::try_new_with_mldsa_master(payload)?;
        let id = payload.id();
        Ok(Self { id, payload: Encryptable::Plain(payload), name: None })
    }

    pub fn as_mldsa_master(&self, payment_secret: Option<&Secret>) -> Result<Option<MlDsaMasterPayload>> {
        let payload = self.payload.decrypt(payment_secret)?;
        payload.as_mldsa_master()
    }

    pub fn reencrypt_mldsa_master_seed(&mut self, old_secret: &Secret, new_secret: &Secret) -> Result<bool> {
        match &mut self.payload {
            Encryptable::Plain(payload) => payload.reencrypt_mldsa_master_seed(old_secret, new_secret),
            Encryptable::XChaCha20Poly1305(cipher) => {
                let decrypted_payload = cipher.decrypt::<PrvKeyDataPayload>(old_secret)?.unwrap();
                let mut payload = decrypted_payload;
                let updated = payload.reencrypt_mldsa_master_seed(old_secret, new_secret)?;
                if updated {
                    let reencrypted = Decrypted::new(payload).encrypt(new_secret, cipher.kind())?;
                    cipher.replace(reencrypted);
                }
                Ok(updated)
            }
        }
    }
}

impl AsRef<PrvKeyData> for PrvKeyData {
    fn as_ref(&self) -> &PrvKeyData {
        self
    }
}

impl Zeroize for PrvKeyData {
    fn zeroize(&mut self) {
        self.id.zeroize();
        self.name.zeroize();
        self.payload.zeroize();
    }
}

impl Drop for PrvKeyData {
    fn drop(&mut self) {
        self.zeroize();
    }
}

impl PrvKeyData {
    pub fn new(id: PrvKeyDataId, name: Option<String>, payload: Encryptable<PrvKeyDataPayload>) -> Self {
        Self { id, payload, name }
    }

    pub fn is_payload_encrypted(&self) -> bool {
        self.payload.is_encrypted()
    }

    pub fn try_new_from_mnemonic(
        mnemonic: Mnemonic,
        payment_secret: Option<&Secret>,
        encryption_kind: EncryptionKind,
    ) -> Result<Self> {
        let payload = PrvKeyDataPayload::try_new_with_mnemonic(mnemonic)?;
        let mut prv_key_data = Self { id: payload.id(), payload: Encryptable::Plain(payload), name: None };
        if let Some(payment_secret) = payment_secret {
            prv_key_data.encrypt(payment_secret, encryption_kind)?;
        }

        Ok(prv_key_data)
    }

    pub fn try_new_from_secret_key(
        secret_key: SecretKey,
        payment_secret: Option<&Secret>,
        encryption_kind: EncryptionKind,
    ) -> Result<Self> {
        let payload = PrvKeyDataPayload::try_new_with_secret_key(secret_key)?;
        let mut prv_key_data = Self { id: payload.id(), payload: Encryptable::Plain(payload), name: None };
        if let Some(payment_secret) = payment_secret {
            prv_key_data.encrypt(payment_secret, encryption_kind)?;
        }

        Ok(prv_key_data)
    }

    pub fn encrypt(&mut self, secret: &Secret, encryption_kind: EncryptionKind) -> Result<()> {
        self.payload = self.payload.into_encrypted(secret, encryption_kind)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::encryption::{EncryptionKind, encrypt_xchacha20poly1305};
    use crate::tests::*;
    use kaspa_mldsa::MlDsaLevel;

    fn sample_seed() -> Vec<u8> {
        vec![0x55; 48]
    }

    fn sample_payload(secret: &Secret) -> Result<MlDsaMasterPayload> {
        let cipher = encrypt_xchacha20poly1305(&sample_seed(), secret)?;
        Ok(MlDsaMasterPayload::new(MlDsaLevel::Level2, MasterAnchor::new([0x11; 32]), cipher))
    }

    #[test]
    fn test_storage_prv_key_data() -> Result<()> {
        let storable_in = PrvKeyDataVariant::Bip39Seed("lorem ipsum".to_string());
        let guard = StorageGuard::new(&storable_in);
        let storable_out = guard.validate()?;

        match &storable_out {
            PrvKeyDataVariant::Bip39Seed(s) => assert_eq!(s, "lorem ipsum"),
            _ => unreachable!("invalid prv key variant storage data"),
        }

        Ok(())
    }

    #[test]
    fn test_storage_prv_key_data_mldsa_master() -> Result<()> {
        let payload = MlDsaMasterPayload::new(MlDsaLevel::Level2, MasterAnchor::new([1u8; 32]), vec![1, 2, 3]);
        let storable_in = PrvKeyDataVariant::from_mldsa_master(payload.clone());
        let guard = StorageGuard::new(&storable_in);
        let storable_out = guard.validate()?;

        match storable_out {
            PrvKeyDataVariant::MlDsaMaster(ref restored) => {
                assert_eq!(restored.level(), Some(MlDsaLevel::Level2));
                assert_eq!(restored.anchor().as_bytes(), payload.anchor().as_bytes());
            }
            _ => unreachable!("invalid prv key variant storage data"),
        }

        Ok(())
    }

    #[test]
    fn test_mldsa_master_payload_encrypt_decrypt() -> Result<()> {
        let wallet_secret = Secret::from("unit-test-master");
        let payload = sample_payload(&wallet_secret)?;
        let decrypted = payload.decrypt_seed(&wallet_secret)?;
        let decrypted_bytes: &Vec<u8> = decrypted.as_ref();
        assert_eq!(decrypted_bytes.as_slice(), sample_seed().as_slice());
        Ok(())
    }

    #[test]
    fn test_mldsa_master_payload_borsh_roundtrip() -> Result<()> {
        let wallet_secret = Secret::from("unit-test-master");
        let payload = sample_payload(&wallet_secret)?;
        let guard = StorageGuard::new(&payload);
        let restored: MlDsaMasterPayload = guard.validate()?;
        assert_eq!(restored.anchor(), payload.anchor());
        assert_eq!(restored.level(), payload.level());
        Ok(())
    }

    #[test]
    fn test_mldsa_master_payload_reencrypt_seed() -> Result<()> {
        let old_secret = Secret::from("old-secret");
        let new_secret = Secret::from("new-secret");
        let mut payload = sample_payload(&old_secret)?;
        payload.reencrypt_seed(&old_secret, &new_secret)?;
        payload.decrypt_seed(&new_secret)?;
        assert!(payload.decrypt_seed(&old_secret).is_err());
        Ok(())
    }

    #[test]
    fn test_reencrypt_mldsa_master_seed_encrypted_payload() -> Result<()> {
        let old_secret = Secret::from("old-secret");
        let new_secret = Secret::from("new-secret");
        let payload = sample_payload(&old_secret)?;
        let mut prv = PrvKeyData::try_new_mldsa_master(payload)?;
        prv.encrypt(&old_secret, EncryptionKind::XChaCha20Poly1305)?;

        let updated = prv.reencrypt_mldsa_master_seed(&old_secret, &new_secret)?;
        assert!(updated);

        let decrypted_payload = prv.payload.decrypt(Some(&new_secret))?;
        let master = decrypted_payload.as_mldsa_master()?.expect("master payload");
        master.decrypt_seed(&new_secret)?;
        assert!(master.decrypt_seed(&old_secret).is_err());

        Ok(())
    }
}
