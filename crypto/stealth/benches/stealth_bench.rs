//! Benchmarks for stealth address operations
//!
//! Run with: cargo bench -p kaspa-stealth

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use kaspa_stealth::{check_view_tag, create_stealth_output, derive_spending_key, scan_output, EphemeralOutput, StealthSecretKey};
use rand::rngs::OsRng;

fn bench_key_generation(c: &mut Criterion) {
    c.bench_function("stealth_key_generation", |b| b.iter(|| black_box(StealthSecretKey::generate().unwrap())));
}

fn bench_create_output(c: &mut Criterion) {
    let keys = StealthSecretKey::generate().unwrap();
    let address = keys.to_address();

    c.bench_function("stealth_create_output", |b| b.iter(|| black_box(create_stealth_output(&address, &mut OsRng).unwrap())));
}

fn bench_check_view_tag(c: &mut Criterion) {
    let keys = StealthSecretKey::generate().unwrap();
    let address = keys.to_address();
    let output = create_stealth_output(&address, &mut OsRng).unwrap();

    c.bench_function("stealth_check_view_tag", |b| {
        b.iter(|| black_box(check_view_tag(&output.ephemeral_pubkey, output.view_tag, &keys.scan_secret())))
    });
}

fn bench_scan_output(c: &mut Criterion) {
    let keys = StealthSecretKey::generate().unwrap();
    let address = keys.to_address();
    let output = create_stealth_output(&address, &mut OsRng).unwrap();

    c.bench_function("stealth_scan_output", |b| {
        b.iter(|| black_box(scan_output(&output, &keys.scan_secret(), &address.spend_pubkey).unwrap()))
    });
}

fn bench_derive_spending_key(c: &mut Criterion) {
    let keys = StealthSecretKey::generate().unwrap();
    let address = keys.to_address();
    let output = create_stealth_output(&address, &mut OsRng).unwrap();
    let scan_result = scan_output(&output, &keys.scan_secret(), &address.spend_pubkey).unwrap();

    c.bench_function("stealth_derive_spending_key", |b| {
        b.iter(|| black_box(derive_spending_key(&keys.spend_secret(), &scan_result.blinding_factor).unwrap()))
    });
}

fn bench_serialization(c: &mut Criterion) {
    let keys = StealthSecretKey::generate().unwrap();
    let address = keys.to_address();
    let output = create_stealth_output(&address, &mut OsRng).unwrap();

    c.bench_function("stealth_output_to_bytes", |b| b.iter(|| black_box(output.to_bytes())));

    let bytes = output.to_bytes();
    c.bench_function("stealth_output_from_bytes", |b| b.iter(|| black_box(EphemeralOutput::from_slice(&bytes).unwrap())));
}

fn bench_full_scan_miss(c: &mut Criterion) {
    // Simulates scanning an output that doesn't belong to us
    let scanner_keys = StealthSecretKey::generate().unwrap();
    let other_keys = StealthSecretKey::generate().unwrap();
    let output = create_stealth_output(&other_keys.to_address(), &mut OsRng).unwrap();

    c.bench_function("stealth_scan_miss_view_tag", |b| {
        b.iter(|| black_box(check_view_tag(&output.ephemeral_pubkey, output.view_tag, &scanner_keys.scan_secret())))
    });
}

criterion_group!(
    benches,
    bench_key_generation,
    bench_create_output,
    bench_check_view_tag,
    bench_scan_output,
    bench_derive_spending_key,
    bench_serialization,
    bench_full_scan_miss,
);

criterion_main!(benches);
