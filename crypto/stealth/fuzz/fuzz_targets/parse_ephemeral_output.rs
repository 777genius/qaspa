#![no_main]
use libfuzzer_sys::fuzz_target;
use kaspa_stealth::EphemeralOutput;

fuzz_target!(|data: &[u8]| {
    // Should never panic, always return Err for invalid input
    let _ = EphemeralOutput::from_slice(data);
});
