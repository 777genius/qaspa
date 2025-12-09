#![no_main]
use libfuzzer_sys::fuzz_target;
use kaspa_stealth::StealthAddress;

fuzz_target!(|data: &[u8]| {
    // Should never panic, always return Err for invalid input
    let _ = StealthAddress::from_slice(data);
});
