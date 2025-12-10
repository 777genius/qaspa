use crate::account::variants::stealth::Payload;
use crate::serializer::StorageHeader;
use crate::storage::storable::Storable;
use borsh::BorshDeserialize;
use borsh::BorshSerialize;
use proptest::prelude::*;

proptest! {
    #![proptest_config(ProptestConfig { cases: 32, .. ProptestConfig::default() })]

    #[test]
    fn prop_stealth_payload_v0_roundtrip(
        account_index in any::<u64>(),
        scan in any::<[u8; 32]>(),
        spend in any::<[u8; 32]>(),
        creation in prop::option::of(any::<u64>()),
    ) {
        // Encode manual v0 payload (no master_anchor / delegation_id)
        let mut bytes = vec![];
        StorageHeader::new(Payload::STORAGE_MAGIC, 0).serialize(&mut bytes).unwrap();
        account_index.serialize(&mut bytes).unwrap();
        scan.to_vec().serialize(&mut bytes).unwrap();
        spend.to_vec().serialize(&mut bytes).unwrap();
        creation.serialize(&mut bytes).unwrap();

        let decoded = Payload::try_from_slice(&bytes).expect("decode v0 payload");

        prop_assert_eq!(decoded.account_index, account_index);
        prop_assert_eq!(decoded.scan_pubkey, scan.to_vec());
        prop_assert_eq!(decoded.spend_pubkey, spend.to_vec());
        prop_assert_eq!(decoded.creation_daa_score, creation);
        prop_assert_eq!(decoded.master_anchor, None);
        prop_assert_eq!(decoded.delegation_id, None);
    }
}
