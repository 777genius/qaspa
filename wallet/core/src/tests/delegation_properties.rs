use crate::account::delegation::{select_active, verify_against_anchor, DelegationRecordV1, DelegationStatus};
use kaspa_hashes::Hash;
use kaspa_mldsa::MlDsaLevel;
use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
use proptest::prelude::*;

fn make_record(level: MlDsaLevel, anchor: [u8; 32], valid_from: u64, valid_until: Option<u64>, nonce: u64) -> DelegationRecordV1 {
    DelegationRecordV1::new(
        level,
        anchor,
        crate::deterministic::AccountId(Hash::from_u64_word(5)),
        [5u8; 32],
        [6u8; 32],
        valid_from,
        valid_until,
        nonce,
        DelegationStatus::Active,
    )
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 32, .. ProptestConfig::default() })]

    #[test]
    fn prop_forged_signature_is_rejected(level in prop_oneof![Just(MlDsaLevel::Level2), Just(MlDsaLevel::Level3), Just(MlDsaLevel::Level5)],
                                         anchor_bytes in any::<[u8; 32]>(),
                                         sig_bytes in prop::collection::vec(any::<u8>(), 2000..5000)) {
        let master = MlDsaKeypair::random(level).unwrap();
        let anchor = master.anchor();

        let mut record = make_record(level, anchor_bytes, 1, Some(10), 1);
        // force signature length to expected, padding or truncating
        let mut sig = sig_bytes;
        let expected_len = level.signature_len();
        sig.resize(expected_len, 0u8);
        record.signature = sig;

        let res = verify_against_anchor(&anchor, master.public_key().as_bytes(), &record);
        prop_assert!(res.is_ok());
        prop_assert!(!res.unwrap());
    }

    #[test]
    fn prop_delegation_window_semantics(valid_from in 0u64..50_000, span in 0u64..10_000, current in 0u64..60_000) {
        let valid_until = valid_from.saturating_add(span);
        let record = make_record(MlDsaLevel::Level2, [1u8; 32], valid_from, Some(valid_until), 1);

        let within = current >= valid_from && current <= valid_until;
        let window_ok = current >= record.valid_from_daa
            && record.valid_until_daa.map(|u| current <= u).unwrap_or(true);

        prop_assert_eq!(window_ok, within);
    }

    #[test]
    fn prop_expired_records_not_selected(valid_from in 0u64..10_000, span in 1u64..5_000, base_nonce in 1u64..100) {
        let level = MlDsaLevel::Level3;
        let master = MlDsaKeypair::random(level).unwrap();
        let anchor = *master.anchor().as_bytes();
        let valid_until = valid_from.saturating_add(span);

        let mut expired = make_record(level, anchor, valid_from, Some(valid_until), base_nonce);
        expired.status = DelegationStatus::Expired { expired_daa: valid_until };

        let mut active = expired.clone();
        active.status = DelegationStatus::Active;
        active.nonce = base_nonce.saturating_add(1);

        let none_selected = select_active(&[expired.clone()]);
        prop_assert!(none_selected.is_none(), "expired delegation must not be selected");

        let picked = select_active(&[expired, active.clone()]);
        prop_assert_eq!(picked.map(|r| r.nonce), Some(active.nonce), "active delegation wins over expired");
    }
}
