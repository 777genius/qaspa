use faster_hex::hex_decode;
use kaspa_utils::hex::ToHex;
use kaspa_wallet_core::api::message::MasterAnchorInfo;
use kaspa_wallet_core::storage::PrvKeyDataId;

/// Maximum length (in bytes) of the MLDSA anchor commitment.
pub const MASTER_ANCHOR_LEN: usize = 32;
/// Raw byte length of [`PrvKeyDataId`].
pub const PRV_KEY_DATA_ID_LEN: usize = 8;

/// C-friendly representation of [`MasterAnchorInfo`].
///
/// The struct intentionally avoids heap allocations so that consumers written
/// in C, Go or Swift can safely stack-allocate buffers and pass them by pointer.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct KaspaMasterAnchorInfo {
    /// Deterministic identifier of the private key data record.
    pub id: [u8; PRV_KEY_DATA_ID_LEN],
    /// Raw MLDSA anchor commitment (zeroed when [`Self::has_anchor`] is false).
    pub anchor: [u8; MASTER_ANCHOR_LEN],
    /// MLDSA security level (currently level 2) if known, zero otherwise.
    pub level: u8,
    /// Indicates whether the underlying payload is encrypted at rest.
    pub is_encrypted: bool,
    /// Indicates whether [`Self::anchor`] contains a valid value.
    pub has_anchor: bool,
    /// Reserved for future extensions / padding.
    pub reserved: [u8; 5],
}

impl Default for KaspaMasterAnchorInfo {
    fn default() -> Self {
        Self {
            id: [0u8; PRV_KEY_DATA_ID_LEN],
            anchor: [0u8; MASTER_ANCHOR_LEN],
            level: 0,
            is_encrypted: false,
            has_anchor: false,
            reserved: [0u8; 5],
        }
    }
}

impl KaspaMasterAnchorInfo {
    pub fn from_master_info(info: &MasterAnchorInfo) -> Self {
        let mut ffi_info =
            KaspaMasterAnchorInfo { is_encrypted: info.is_encrypted, level: info.level.unwrap_or_default(), ..Default::default() };
        ffi_info.id = decode_id(info.id);
        if let Some(anchor_hex) = info.anchor.as_deref() {
            if anchor_hex.len() == MASTER_ANCHOR_LEN * 2 && hex_decode(anchor_hex.as_bytes(), &mut ffi_info.anchor).is_ok() {
                ffi_info.has_anchor = true;
            }
        }
        ffi_info
    }
}

fn decode_id(id: PrvKeyDataId) -> [u8; PRV_KEY_DATA_ID_LEN] {
    let hex = id.to_hex();
    let mut bytes = [0u8; PRV_KEY_DATA_ID_LEN];
    if hex_decode(hex.as_bytes(), &mut bytes).is_err() {
        return [0u8; PRV_KEY_DATA_ID_LEN];
    }
    bytes
}
