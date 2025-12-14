//!
//! Deterministic private key data ids.
//!

use crate::imports::*;
use faster_hex::{hex_decode, hex_string};
use serde::Serializer;

#[derive(Default, Clone, Copy, PartialEq, Eq, Hash, Ord, PartialOrd, BorshSerialize, BorshDeserialize)]
pub struct KeyDataId(pub(crate) [u8; 8]);

impl KeyDataId {
    pub fn new(id: u64) -> Self {
        KeyDataId(id.to_le_bytes())
    }

    pub fn new_from_slice(vec: &[u8]) -> Self {
        Self(<[u8; 8]>::try_from(<&[u8]>::clone(&vec)).expect("Error: invalid slice size for id"))
    }
}

impl ToHex for KeyDataId {
    fn to_hex(&self) -> String {
        self.0.to_vec().to_hex()
    }
}

impl FromHex for KeyDataId {
    type Error = Error;
    fn from_hex(hex_str: &str) -> Result<Self, Self::Error> {
        // KeyDataId is always 8 bytes = 16 hex chars.
        // Do not panic on malformed user input (e.g. from JS/WASM).
        if hex_str.len() != 16 {
            return Err(Error::InvalidKeyDataId(format!("invalid key data id length: expected 16 hex chars, got {}", hex_str.len())));
        }
        let mut data = vec![0u8; hex_str.len() / 2];
        hex_decode(hex_str.as_bytes(), &mut data)?;
        Ok(Self::new_from_slice(&data))
    }
}

impl TryFrom<&JsValue> for KeyDataId {
    type Error = Error;
    fn try_from(value: &JsValue) -> Result<Self> {
        let string = value.as_string().ok_or(Error::InvalidKeyDataId(format!("{value:?}")))?;
        Self::from_hex(&string)
    }
}

impl From<KeyDataId> for JsValue {
    fn from(value: KeyDataId) -> Self {
        JsValue::from(value.to_hex())
    }
}

impl std::fmt::Debug for KeyDataId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "KeyDataId ({})", self.0.as_slice().to_hex())
    }
}

impl std::fmt::Display for KeyDataId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0.as_slice().to_hex())
    }
}

impl Serialize for KeyDataId {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&hex_string(&self.0))
    }
}

impl<'de> Deserialize<'de> for KeyDataId {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = <std::string::String as Deserialize>::deserialize(deserializer)?;
        if s.len() != 16 {
            return Err(serde::de::Error::custom(format!("invalid key data id length: expected 16 hex chars, got {}", s.len())));
        }
        let mut data = vec![0u8; s.len() / 2];
        hex_decode(s.as_bytes(), &mut data).map_err(serde::de::Error::custom)?;
        Ok(Self::new_from_slice(&data))
    }
}

impl Zeroize for KeyDataId {
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}

pub type PrvKeyDataId = KeyDataId;
pub type PrvKeyDataMap = HashMap<PrvKeyDataId, PrvKeyData>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn key_data_id_from_hex_rejects_wrong_length_instead_of_panicking() {
        assert!(KeyDataId::from_hex("").is_err());
        assert!(KeyDataId::from_hex("00").is_err());
        assert!(KeyDataId::from_hex("001122").is_err());
        assert!(KeyDataId::from_hex("001122334455667").is_err()); // odd len
        assert!(KeyDataId::from_hex("001122334455667788").is_err()); // too long
    }
}
