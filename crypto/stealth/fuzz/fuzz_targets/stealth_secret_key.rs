#![no_main]
use libfuzzer_sys::fuzz_target;
use kaspa_stealth::StealthSecretKey;

fuzz_target!(|data: &[u8]| {
    if data.len() >= 64 {
        let scan: [u8; 32] = data[0..32].try_into().unwrap();
        let spend: [u8; 32] = data[32..64].try_into().unwrap();
        let _ = StealthSecretKey::from_bytes(scan, spend);
    }
});
