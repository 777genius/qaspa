//! Generate a stealth address for testing
use kaspa_addresses::{Address, Prefix, Version};
use kaspa_stealth::StealthSecretKey;

fn main() {
    let sk = StealthSecretKey::generate().expect("Failed to generate keys");
    let addr = sk.to_address();
    let bytes = addr.to_bytes();
    let address = Address::new(Prefix::StealthTestnet, Version::Stealth, &bytes);

    println!("# Stealth Address for miner payout (devnet/testnet)");
    println!("export MINER_PAYOUT_ADDRESS='{}'", address);
    println!();
    println!("# Secret keys (keep safe!)");
    let mut scan_hex = [0u8; 64];
    let mut spend_hex = [0u8; 64];
    faster_hex::hex_encode(sk.scan_secret_bytes(), &mut scan_hex).unwrap();
    faster_hex::hex_encode(sk.spend_secret_bytes(), &mut spend_hex).unwrap();
    println!("# SCAN_SECRET={}", std::str::from_utf8(&scan_hex).unwrap());
    println!("# SPEND_SECRET={}", std::str::from_utf8(&spend_hex).unwrap());
}
