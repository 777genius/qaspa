#![no_main]

use borsh::BorshDeserialize;
use kaspa_mldsa::MlDsaLevel;
use kaspa_wallet_core::account::delegation::{verify_against_anchor, DelegationRecordV1};
use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
use libfuzzer_sys::fuzz_target;

const MAX_SIGNATURE_LEN: usize = 6_000;

fn try_verify(mut record: DelegationRecordV1) {
    let Some(level) = MlDsaLevel::from_u8(record.level) else { return };

    if record.signature.len() > MAX_SIGNATURE_LEN {
        record.signature.truncate(MAX_SIGNATURE_LEN);
    }

    let master = MlDsaKeypair::random(level);
    let anchor = master.anchor();

    // ensure window fields stay consistent
    let _window_is_consistent = record.valid_until_daa.map(|u| record.valid_from_daa <= u).unwrap_or(true);

    let _ = verify_against_anchor(&anchor, master.public_key().as_bytes(), &record);
}

fuzz_target!(|data: &[u8]| {
    // Borsh decode path
    if let Ok(record) = DelegationRecordV1::try_from_slice(data) {
        try_verify(record);
    }

    // JSON decode path (best-effort)
    if let Ok(as_str) = std::str::from_utf8(data) {
        if let Ok(record) = serde_json::from_str::<DelegationRecordV1>(as_str) {
            try_verify(record);
        }
    }
});
