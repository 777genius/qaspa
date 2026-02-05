use crate::account::delegation::{DelegationRecordV1, DelegationStatus, select_active, sign_with_master, verify_against_anchor};
use kaspa_mldsa::MlDsaLevel;
use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;

fn sample_record(anchor: [u8; 32], nonce: u64) -> DelegationRecordV1 {
    DelegationRecordV1::new(
        MlDsaLevel::Level2,
        anchor,
        crate::deterministic::AccountId(kaspa_hashes::Hash::from_u64_word(11)),
        [2u8; 32],
        [3u8; 32],
        10,
        Some(20),
        nonce,
        DelegationStatus::Active,
    )
}

#[test]
fn delegation_sign_verify_roundtrip() {
    let master = MlDsaKeypair::random(MlDsaLevel::Level2).unwrap();
    let anchor = master.anchor();
    let mut record = sample_record(*anchor.as_bytes(), 1);

    sign_with_master(&master, &mut record).expect("sign");
    let ok = verify_against_anchor(&anchor, master.public_key().as_bytes(), &record).expect("verify");
    assert!(ok, "signed delegation must verify");
    assert_eq!(record.signature.len(), master.signature_size());
}

#[test]
fn delegation_nonce_monotonic_selects_latest_active() {
    let master = MlDsaKeypair::random(MlDsaLevel::Level2).unwrap();
    let anchor = master.anchor();

    let mut r1 = sample_record(*anchor.as_bytes(), 1);
    let mut r2 = sample_record(*anchor.as_bytes(), 2);
    let mut r3 = sample_record(*anchor.as_bytes(), 3);
    r3.status = DelegationStatus::Revoked { revoked_daa: 15 };

    sign_with_master(&master, &mut r1).expect("sign");
    sign_with_master(&master, &mut r2).expect("sign");
    sign_with_master(&master, &mut r3).expect("sign");

    let selected = select_active(&[r1.clone(), r2.clone(), r3.clone()]).expect("active record");
    assert_eq!(selected.nonce, r2.nonce, "must pick highest active nonce");
}

#[test]
fn delegation_rejects_wrong_anchor() {
    let master = MlDsaKeypair::random(MlDsaLevel::Level2).unwrap();
    let anchor = master.anchor();
    let mut record = sample_record(*anchor.as_bytes(), 7);
    sign_with_master(&master, &mut record).expect("sign");

    let mut bad = record.clone();
    bad.anchor = [9u8; 32];
    let verified = verify_against_anchor(&anchor, master.public_key().as_bytes(), &bad).expect("verify");
    assert!(!verified, "anchor mismatch must fail verification");
}

#[test]
fn delegation_signature_survives_warned_at_and_version_bump() {
    let master = MlDsaKeypair::random(MlDsaLevel::Level2).unwrap();
    let anchor = master.anchor();
    let mut record = sample_record(*anchor.as_bytes(), 1);
    record.version = 1; // имитируем старую запись/протокол
    sign_with_master(&master, &mut record).expect("sign");

    // Локальные мета-поля не должны ломать верификацию подписи.
    let mut mutated = record.clone();
    mutated.version = 2; // например, повышено при сохранении мета-данных
    mutated.warned_at_daa = Some(123_456);

    let ok = verify_against_anchor(&anchor, master.public_key().as_bytes(), &mutated).expect("verify");
    assert!(ok, "warning metadata must not invalidate signature");
}
