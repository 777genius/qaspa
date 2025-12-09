use crate::types::{KaspaMasterAnchorInfo, KaspaMasterDelegationSummary};
use kaspa_wallet_core::api::message::{
    MasterAnchorInfo, MasterAnchorListResponse, MasterDelegationApplyRequest, MasterDelegationSignRequest,
};
use kaspa_wallet_core::api::traits::WalletApi;
use kaspa_wallet_core::message::{MasterDelegationRequestBodyV1, MasterDelegationResponseBodyV1};
use kaspa_wallet_core::wallet::Wallet;
use std::mem;
use std::ptr;
use std::slice;
use std::sync::Arc;
use tokio::runtime::Runtime;

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

/// Parse delegation request JSON and fill a lightweight summary (anchor, level, request_id, delegations count).
///
/// # Safety
/// Callers must pass valid non-null pointers for JSON buffer and output summary;
/// buffers must remain valid for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn kaspa_wallet_mldsa_delegation_request_summary(
    json_ptr: *const u8,
    json_len: usize,
    out_summary: *mut KaspaMasterDelegationSummary,
) -> bool {
    if json_ptr.is_null() || out_summary.is_null() || json_len == 0 {
        return false;
    }
    let json = slice::from_raw_parts(json_ptr, json_len);
    match serde_json::from_slice::<MasterDelegationRequestBodyV1>(json) {
        Ok(req) => {
            let summary = KaspaMasterDelegationSummary {
                master_anchor: req.master_anchor,
                master_level: req.master_level,
                request_id: req.request_id,
                delegations: req.delegations.len() as u32,
                ..Default::default()
            };
            ptr::write(out_summary, summary);
            true
        }
        Err(_) => false,
    }
}

/// Sign delegation request JSON using an opened wallet instance (legacy wrapper, no force flag).
///
/// # Safety
/// Pointers must be valid and owned by the caller; wallet_ptr must reference a live `Wallet`.
#[no_mangle]
pub unsafe extern "C" fn kaspa_wallet_mldsa_delegation_sign(
    wallet_ptr: *mut Wallet,
    wallet_secret_ptr: *const u8,
    wallet_secret_len: usize,
    json_ptr: *const u8,
    json_len: usize,
    out_json_ptr: *mut *mut u8,
    out_json_len: *mut usize,
) -> bool {
    kaspa_wallet_mldsa_delegation_sign_ex(
        wallet_ptr,
        wallet_secret_ptr,
        wallet_secret_len,
        json_ptr,
        json_len,
        false,
        out_json_ptr,
        out_json_len,
    )
}

/// Sign delegation request JSON using an opened wallet instance with optional network mismatch override.
///
/// # Safety
/// Pointers must be valid and owned by the caller; wallet_ptr must reference a live `Wallet`.
#[no_mangle]
pub unsafe extern "C" fn kaspa_wallet_mldsa_delegation_sign_ex(
    wallet_ptr: *mut Wallet,
    wallet_secret_ptr: *const u8,
    wallet_secret_len: usize,
    json_ptr: *const u8,
    json_len: usize,
    force_network_mismatch: bool,
    out_json_ptr: *mut *mut u8,
    out_json_len: *mut usize,
) -> bool {
    if wallet_ptr.is_null()
        || wallet_secret_ptr.is_null()
        || json_ptr.is_null()
        || out_json_ptr.is_null()
        || out_json_len.is_null()
        || wallet_secret_len == 0
        || json_len == 0
    {
        return false;
    }

    // Borrow Arc without leaking the original strong ref passed from the caller.
    Arc::increment_strong_count(wallet_ptr as *const Wallet);
    let wallet = Arc::from_raw(wallet_ptr);
    let wallet_secret = slice::from_raw_parts(wallet_secret_ptr, wallet_secret_len).to_vec().into();
    let json = slice::from_raw_parts(json_ptr, json_len);

    let request: MasterDelegationRequestBodyV1 = match serde_json::from_slice(json) {
        Ok(v) => v,
        Err(_) => return false,
    };

    let rt = match Runtime::new() {
        Ok(rt) => rt,
        Err(_) => return false,
    };

    let signed = match rt.block_on(wallet.master_delegation_sign_call(MasterDelegationSignRequest {
        wallet_secret,
        request,
        force_network_mismatch,
    })) {
        Ok(v) => v.response,
        Err(_) => return false,
    };

    let out_json = match serde_json::to_vec(&signed) {
        Ok(v) => v,
        Err(_) => return false,
    };

    let boxed = out_json.into_boxed_slice();
    let len = boxed.len();
    let ptr = Box::into_raw(boxed) as *mut u8;
    *out_json_ptr = ptr;
    *out_json_len = len;
    true
}

/// Free buffers allocated by FFI helpers (e.g. `kaspa_wallet_mldsa_delegation_sign`).
///
/// # Safety
/// The pointer/length pair must come from a Kaspa wallet FFI function that
/// allocated the buffer. Passing arbitrary pointers leads to undefined behavior.
#[no_mangle]
pub unsafe extern "C" fn kaspa_wallet_mldsa_buffer_free(ptr: *mut u8, len: usize) {
    if ptr.is_null() || len == 0 {
        return;
    }
    let _ = Vec::from_raw_parts(ptr, len, len);
}

/// Apply delegation response JSON to the provided wallet instance (legacy wrapper, no force flag).
///
/// # Safety
/// Pointers must be valid; wallet_ptr must reference a live `Wallet` instance; JSON buffers must contain valid UTF-8.
#[no_mangle]
pub unsafe extern "C" fn kaspa_wallet_mldsa_delegation_apply(
    wallet_ptr: *mut Wallet,
    wallet_secret_ptr: *const u8,
    wallet_secret_len: usize,
    request_json_ptr: *const u8,
    request_json_len: usize,
    response_json_ptr: *const u8,
    response_json_len: usize,
    out_applied: *mut u64,
    out_skipped: *mut u64,
) -> bool {
    kaspa_wallet_mldsa_delegation_apply_ex(
        wallet_ptr,
        wallet_secret_ptr,
        wallet_secret_len,
        request_json_ptr,
        request_json_len,
        response_json_ptr,
        response_json_len,
        false,
        out_applied,
        out_skipped,
    )
}

/// Apply delegation response JSON to the provided wallet instance with optional network mismatch override.
///
/// # Safety
/// Pointers must be valid; wallet_ptr must reference a live `Wallet` instance; JSON buffers must contain valid UTF-8.
#[no_mangle]
pub unsafe extern "C" fn kaspa_wallet_mldsa_delegation_apply_ex(
    wallet_ptr: *mut Wallet,
    wallet_secret_ptr: *const u8,
    wallet_secret_len: usize,
    request_json_ptr: *const u8,
    request_json_len: usize,
    response_json_ptr: *const u8,
    response_json_len: usize,
    force_network_mismatch: bool,
    out_applied: *mut u64,
    out_skipped: *mut u64,
) -> bool {
    if wallet_ptr.is_null()
        || wallet_secret_ptr.is_null()
        || request_json_ptr.is_null()
        || response_json_ptr.is_null()
        || out_applied.is_null()
        || out_skipped.is_null()
        || wallet_secret_len == 0
        || request_json_len == 0
        || response_json_len == 0
    {
        return false;
    }

    // Borrow Arc without leaking the original strong ref passed from the caller.
    Arc::increment_strong_count(wallet_ptr as *const Wallet);
    let wallet = Arc::from_raw(wallet_ptr);
    let wallet_secret = slice::from_raw_parts(wallet_secret_ptr, wallet_secret_len).to_vec().into();

    let request: MasterDelegationRequestBodyV1 =
        match serde_json::from_slice(slice::from_raw_parts(request_json_ptr, request_json_len)) {
            Ok(v) => v,
            Err(_) => return false,
        };
    let response: MasterDelegationResponseBodyV1 =
        match serde_json::from_slice(slice::from_raw_parts(response_json_ptr, response_json_len)) {
            Ok(v) => v,
            Err(_) => return false,
        };

    let rt = match Runtime::new() {
        Ok(rt) => rt,
        Err(_) => return false,
    };

    let result = match rt.block_on(wallet.master_delegation_apply_call(MasterDelegationApplyRequest {
        wallet_secret,
        request,
        response,
        force_network_mismatch,
    })) {
        Ok(v) => v,
        Err(_) => return false,
    };

    *out_applied = result.applied as u64;
    *out_skipped = result.skipped as u64;
    true
}

/// Parse delegation response JSON and fill a lightweight summary (anchor, level, request_id, delegations count).
///
/// # Safety
/// Callers must pass valid non-null pointers for JSON buffer and output summary; buffers must stay valid during the call.
#[no_mangle]
pub unsafe extern "C" fn kaspa_wallet_mldsa_delegation_response_summary(
    json_ptr: *const u8,
    json_len: usize,
    out_summary: *mut KaspaMasterDelegationSummary,
) -> bool {
    if json_ptr.is_null() || out_summary.is_null() || json_len == 0 {
        return false;
    }
    let json = slice::from_raw_parts(json_ptr, json_len);
    match serde_json::from_slice::<MasterDelegationResponseBodyV1>(json) {
        Ok(resp) => {
            let summary = KaspaMasterDelegationSummary {
                master_anchor: resp.master_anchor,
                master_level: resp.master_level,
                request_id: resp.request_id,
                delegations: resp.delegations.len() as u32,
                ..Default::default()
            };
            ptr::write(out_summary, summary);
            true
        }
        Err(_) => false,
    }
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

#[cfg(test)]
mod tests {
    use super::*;
    use kaspa_consensus_core::network::{NetworkId, NetworkType};
    use kaspa_utils::hex::FromHex;
    use kaspa_wallet_core::account::delegation::{DelegationRecordV1, DelegationStatus};
    use kaspa_wallet_core::deterministic::AccountId;
    use kaspa_wallet_core::message::DelegationRecordHeaderV1;
    use std::ptr;

    #[test]
    fn sign_ex_rejects_invalid_args() {
        let ok = unsafe {
            kaspa_wallet_mldsa_delegation_sign_ex(
                ptr::null_mut(),
                ptr::null(),
                0,
                ptr::null(),
                0,
                false,
                ptr::null_mut(),
                ptr::null_mut(),
            )
        };
        assert!(!ok, "sign_ex must reject null/empty inputs");
    }

    #[test]
    fn apply_ex_rejects_invalid_args() {
        let ok = unsafe {
            kaspa_wallet_mldsa_delegation_apply_ex(
                ptr::null_mut(),
                ptr::null(),
                0,
                ptr::null(),
                0,
                ptr::null(),
                0,
                false,
                ptr::null_mut(),
                ptr::null_mut(),
            )
        };
        assert!(!ok, "apply_ex must reject null/empty inputs");
    }

    #[test]
    fn request_summary_parses_json() {
        let header = DelegationRecordHeaderV1 {
            version: 1,
            level: 2,
            anchor: [1u8; 32],
            account_id: AccountId::from_hex("0000000000000000000000000000000000000000000000000000000000000007").expect("account id"),
            spend_pubkey: [2u8; 32],
            scan_pubkey: [3u8; 32],
            valid_from_daa: 10,
            valid_until_daa: Some(20),
            nonce: 1,
            status: DelegationStatus::Active,
        };
        let req = MasterDelegationRequestBodyV1 {
            version: 1,
            master_anchor: [1u8; 32],
            master_level: 2,
            network_id: NetworkId::new(NetworkType::Devnet),
            delegations: vec![header],
            created_at_unixtime: 1_730_000_000,
            request_id: [0xAA; 32],
        };
        let json = serde_json::to_vec(&req).expect("json");
        let mut summary = KaspaMasterDelegationSummary::default();
        let ok = unsafe { kaspa_wallet_mldsa_delegation_request_summary(json.as_ptr(), json.len(), &mut summary as *mut _) };
        assert!(ok, "summary should parse valid request");
        assert_eq!(summary.master_anchor, req.master_anchor);
        assert_eq!(summary.request_id, req.request_id);
        assert_eq!(summary.master_level, req.master_level);
        assert_eq!(summary.delegations, req.delegations.len() as u32);
    }

    #[test]
    fn response_summary_parses_json() {
        let header = DelegationRecordHeaderV1 {
            version: 1,
            level: 2,
            anchor: [2u8; 32],
            account_id: AccountId::from_hex("0000000000000000000000000000000000000000000000000000000000000008").expect("account id"),
            spend_pubkey: [4u8; 32],
            scan_pubkey: [5u8; 32],
            valid_from_daa: 15,
            valid_until_daa: None,
            nonce: 2,
            status: DelegationStatus::Active,
        };
        let mut rec = DelegationRecordV1::from(&header);
        rec.signature = vec![0x11; 64];
        let resp = MasterDelegationResponseBodyV1 {
            version: 1,
            master_anchor: [2u8; 32],
            master_level: 2,
            request_id: [0xBB; 32],
            delegations: vec![rec],
        };
        let json = serde_json::to_vec(&resp).expect("json");
        let mut summary = KaspaMasterDelegationSummary::default();
        let ok = unsafe { kaspa_wallet_mldsa_delegation_response_summary(json.as_ptr(), json.len(), &mut summary as *mut _) };
        assert!(ok, "summary should parse valid response");
        assert_eq!(summary.master_anchor, resp.master_anchor);
        assert_eq!(summary.request_id, resp.request_id);
        assert_eq!(summary.master_level, resp.master_level);
        assert_eq!(summary.delegations, resp.delegations.len() as u32);
    }
}
