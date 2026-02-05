use super::StorageGuard;
use crate::encryption::EncryptionKind;
use crate::storage::Encryptable;
use crate::storage::keydata::data::{MlDsaMasterPayload, PrvKeyDataPayload, PrvKeyDataVariant};
use crate::storage::keydata::{PrvKeyData, PrvKeyDataId};
use borsh::BorshDeserialize;
use kaspa_mldsa::MlDsaLevel;
use kaspa_wallet_keys::keypair_mldsa::MasterAnchor;
use kaspa_wallet_keys::secret::Secret;
use zeroize::Zeroize;

#[test]
fn mldsa_master_payload_borsh_roundtrip() {
    let payload = MlDsaMasterPayload::new(MlDsaLevel::Level2, MasterAnchor::new([1u8; 32]), vec![9u8; 16]);
    let guard = StorageGuard::new(&payload);
    let decoded = guard.validate().expect("borsh roundtrip");
    assert_eq!(decoded.level(), Some(MlDsaLevel::Level2));
    assert_eq!(decoded.anchor().as_bytes(), &[1u8; 32]);
    assert_eq!(decoded.seed_cipher(), &[9u8; 16]);
}

#[test]
fn prv_key_data_variant_roundtrip_and_id() {
    let payload = MlDsaMasterPayload::new(MlDsaLevel::Level3, MasterAnchor::new([2u8; 32]), vec![7u8; 8]);
    let variant = PrvKeyDataVariant::MlDsaMaster(payload.clone());

    let encoded = borsh::to_vec(&variant).expect("encode");
    let decoded = PrvKeyDataVariant::try_from_slice(&encoded).expect("decode");
    assert!(matches!(decoded, PrvKeyDataVariant::MlDsaMaster(_)));

    let id = variant.id();
    assert_ne!(id, PrvKeyDataId::new(0));

    // Zeroize should clear sensitive buffers
    let mut payload_copy = payload.clone();
    payload_copy.zeroize();
    assert!(payload_copy.seed_cipher().is_empty());
}

#[test]
fn reencrypt_seed_changes_ciphertext_and_decrypts() {
    let wallet_secret_old = Secret::new(b"old-secret-123".to_vec());
    let wallet_secret_new = Secret::new(b"new-secret-456".to_vec());

    let seed_plain = vec![42u8; 48];
    let seed_cipher = crate::encryption::encrypt_xchacha20poly1305(&seed_plain, &wallet_secret_old).expect("cipher");
    let payload = MlDsaMasterPayload::new(MlDsaLevel::Level5, MasterAnchor::new([3u8; 32]), seed_cipher);
    let variant = PrvKeyDataVariant::MlDsaMaster(payload);
    let prv_payload = PrvKeyDataPayload::try_new_with_mldsa_master(match &variant {
        PrvKeyDataVariant::MlDsaMaster(p) => p.clone(),
        _ => unreachable!(),
    })
    .expect("payload");
    let id = prv_payload.id();

    let mut prv = PrvKeyData { id, name: None, payload: Encryptable::Plain(prv_payload) };

    // initial encrypt
    prv.encrypt(&wallet_secret_old, EncryptionKind::XChaCha20Poly1305).expect("encrypt");

    let before_bytes = match &prv.payload {
        Encryptable::XChaCha20Poly1305(c) => borsh::to_vec(c).expect("serialize encrypted before"),
        _ => panic!("expected encrypted"),
    };

    // reencrypt with new secret
    prv.reencrypt_mldsa_master_seed(&wallet_secret_old, &wallet_secret_new).expect("reencrypt");

    let after_bytes = match &prv.payload {
        Encryptable::XChaCha20Poly1305(c) => borsh::to_vec(c).expect("serialize encrypted after"),
        _ => panic!("expected encrypted"),
    };
    assert_ne!(before_bytes, after_bytes, "ciphertext must change after reencrypt");

    // decrypt with new secret succeeds
    let payload_after = prv.as_mldsa_master(Some(&wallet_secret_new)).expect("decrypt after").expect("payload");
    assert_eq!(payload_after.level(), Some(MlDsaLevel::Level5));
    assert_eq!(payload_after.anchor().as_bytes(), &[3u8; 32]);
}

#[test]
fn ml_dsa_master_zeroize_clears_sensitive_material() {
    let mut payload = MlDsaMasterPayload::new(MlDsaLevel::Level2, MasterAnchor::new([4u8; 32]), vec![1u8; 4]);
    payload.zeroize();
    assert_eq!(payload.anchor().as_bytes(), &[0u8; 32]);
    assert!(payload.seed_cipher().is_empty());
}
