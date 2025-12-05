use crate::types::KaspaMasterAnchorInfo;
use kaspa_wallet_core::api::message::{MasterAnchorInfo, MasterAnchorListResponse};
use kaspa_wallet_core::wallet::Wallet;
use std::ptr;
use std::slice;

/// Convert `MasterAnchorInfo` values returned by wallet-core into their
/// C-compatible counterparts.
pub fn map_master_anchor_infos(infos: &[MasterAnchorInfo]) -> Vec<KaspaMasterAnchorInfo> {
    infos.iter().map(KaspaMasterAnchorInfo::from_master_info).collect()
}

/// Fetch MLDSA master anchors directly from an opened wallet instance.
pub async fn collect_master_anchor_infos(wallet: &Wallet) -> kaspa_wallet_core::result::Result<Vec<KaspaMasterAnchorInfo>> {
    let anchors = wallet.master_anchor_infos().await?;
    Ok(map_master_anchor_infos(&anchors))
}

/// Parse a JSON-encoded [`MasterAnchorListResponse`] and write the resulting
/// anchor descriptors into the caller-provided buffer.
///
/// # Safety
/// - `json_ptr` must point to valid UTF-8 encoded bytes of length `json_len`.
/// - `out_ptr` must be valid for writes of `out_len * size_of::<KaspaMasterAnchorInfo>()` bytes.
/// - `written` must be a valid pointer to `usize`.
///
/// The function writes the total number of decoded anchors into `written`.
/// If the caller-provided buffer is too small, the slice is truncated but the
/// returned `written` count still reflects the total number of anchors so the
/// caller can reallocate and retry.
#[no_mangle]
pub unsafe extern "C" fn kaspa_wallet_master_anchor_list(
    json_ptr: *const u8,
    json_len: usize,
    out_ptr: *mut KaspaMasterAnchorInfo,
    out_len: usize,
    written: *mut usize,
) -> bool {
    if json_ptr.is_null() || json_len == 0 || written.is_null() {
        return false;
    }

    if out_len > 0 && out_ptr.is_null() {
        return false;
    }

    let json = unsafe { slice::from_raw_parts(json_ptr, json_len) };
    let decoded: MasterAnchorListResponse = match serde_json::from_slice(json) {
        Ok(value) => value,
        Err(_) => return false,
    };

    let ffi_infos: Vec<KaspaMasterAnchorInfo> = decoded.anchors.iter().map(KaspaMasterAnchorInfo::from_master_info).collect();
    unsafe {
        *written = ffi_infos.len();
    }

    if out_len == 0 {
        return true;
    }

    let copy_len = out_len.min(ffi_infos.len());
    if copy_len == 0 {
        return true;
    }

    unsafe {
        ptr::copy_nonoverlapping(ffi_infos.as_ptr(), out_ptr, copy_len);
    }

    true
}
