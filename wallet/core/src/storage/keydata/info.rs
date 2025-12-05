//!
//! Private key data info (reference representation).
//!

use super::{PrvKeyDataVariant, PrvKeyDataVariantKind};
use crate::imports::*;
use faster_hex::hex_decode;
use kaspa_utils::hex::ToHex;
use kaspa_wallet_macros::declare_typescript_wasm_interface as declare;
use serde::de::Error as DeError;
use serde::{Deserializer, Serializer};
use std::fmt::{Display, Formatter};
use std::ops::Deref;

declare! {
    IPrvKeyDataInfo,
    r#"
    /**
     * Private key data information.
     * @category Wallet API
     */
    export interface IPrvKeyDataInfo {
        /** Deterministic wallet id of the private key */
        id: HexString;
        /** Optional name of the private key */
        name?: string;
        /** 
         * Indicates if the key requires additional payment or a recovery secret
         * to perform wallet operations that require access to it.
         * For BIP39 keys this indicates that the key was created with a BIP39 passphrase.
         */
        isEncrypted: boolean;
        /** Variant kind of the private key */
        kind: string;
        /** Optional MLDSA security level */
        level?: number;
        /** Optional MLDSA master anchor (hex) */
        anchor?: HexString;
    }
    "#,
}

#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct PrvKeyDataInfo {
    pub id: PrvKeyDataId,
    pub name: Option<String>,
    #[serde(rename = "isEncrypted")]
    pub is_encrypted: bool,
    pub kind: PrvKeyDataVariantKind,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub level: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none", serialize_with = "serialize_anchor", deserialize_with = "deserialize_anchor")]
    pub anchor: Option<[u8; 32]>,
}

impl From<&PrvKeyData> for PrvKeyDataInfo {
    fn from(data: &PrvKeyData) -> Self {
        let (kind, level, anchor) = if let Ok(payload) = data.payload.decrypt(None) {
            let variant = payload.as_variant();
            let kind = variant.kind();
            let anchor = match variant.deref() {
                PrvKeyDataVariant::MlDsaMaster(master) => (master.level().map(|lvl| lvl as u8), Some(*master.anchor().as_bytes())),
                _ => (None, None),
            };
            (kind, anchor.0, anchor.1)
        } else {
            (PrvKeyDataVariantKind::Mnemonic, None, None)
        };

        Self::new(data.id, data.name.clone(), data.payload.is_encrypted(), kind, level, anchor)
    }
}

impl PrvKeyDataInfo {
    pub fn new(
        id: PrvKeyDataId,
        name: Option<String>,
        is_encrypted: bool,
        kind: PrvKeyDataVariantKind,
        level: Option<u8>,
        anchor: Option<[u8; 32]>,
    ) -> Self {
        Self { id, name, is_encrypted, kind, level, anchor }
    }

    pub fn is_encrypted(&self) -> bool {
        self.is_encrypted
    }

    pub fn name_or_id(&self) -> String {
        if let Some(name) = &self.name {
            name.to_owned()
        } else {
            self.id.to_hex()[0..16].to_string()
        }
    }

    pub fn requires_bip39_passphrase(&self) -> bool {
        self.is_encrypted
    }
}

impl Display for PrvKeyDataInfo {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        if let Some(name) = &self.name {
            write!(f, "{} ({})", name, self.id.to_hex())?;
        } else {
            write!(f, "{}", self.id.to_hex())?;
        }
        Ok(())
    }
}

fn serialize_anchor<S>(value: &Option<[u8; 32]>, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    match value {
        Some(anchor) => serializer.serialize_some(&anchor.to_vec().to_hex()),
        None => serializer.serialize_none(),
    }
}

fn deserialize_anchor<'de, D>(deserializer: D) -> Result<Option<[u8; 32]>, D::Error>
where
    D: Deserializer<'de>,
{
    let opt = <Option<String> as serde::Deserialize<'de>>::deserialize(deserializer)?;
    match opt {
        Some(hex_string) => {
            if hex_string.len() != 64 {
                return Err(D::Error::custom("invalid anchor length"));
            }
            let mut bytes = [0u8; 32];
            hex_decode(hex_string.as_bytes(), &mut bytes).map_err(D::Error::custom)?;
            Ok(Some(bytes))
        }
        None => Ok(None),
    }
}
