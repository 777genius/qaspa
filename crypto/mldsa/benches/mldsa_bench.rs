//! Benchmarks for ML-DSA operations

use criterion::{BenchmarkId, Criterion, black_box, criterion_group, criterion_main};
use kaspa_mldsa::{MlDsaLevel, generate_keypair, sign, verify};

fn bench_keygen(c: &mut Criterion) {
    let mut group = c.benchmark_group("keygen");

    for level in [MlDsaLevel::Level2, MlDsaLevel::Level3, MlDsaLevel::Level5] {
        group.bench_with_input(BenchmarkId::from_parameter(level), &level, |b, &level| {
            b.iter(|| black_box(generate_keypair(level).unwrap()));
        });
    }

    group.finish();
}

fn bench_sign(c: &mut Criterion) {
    let mut group = c.benchmark_group("sign");

    let message = b"benchmark message of reasonable length for testing";

    for level in [MlDsaLevel::Level2, MlDsaLevel::Level3, MlDsaLevel::Level5] {
        let keypair = generate_keypair(level).unwrap();

        group.bench_with_input(BenchmarkId::from_parameter(level), &level, |b, _level| {
            b.iter(|| black_box(sign(black_box(message), black_box(&keypair.secret_key)).unwrap()));
        });
    }

    group.finish();
}

fn bench_verify(c: &mut Criterion) {
    let mut group = c.benchmark_group("verify");

    let message = b"benchmark message of reasonable length for testing";

    for level in [MlDsaLevel::Level2, MlDsaLevel::Level3, MlDsaLevel::Level5] {
        let keypair = generate_keypair(level).unwrap();
        let signature = sign(message, &keypair.secret_key).unwrap();

        group.bench_with_input(BenchmarkId::from_parameter(level), &level, |b, _level| {
            b.iter(|| black_box(verify(black_box(message), black_box(&signature), black_box(&keypair.public_key))));
        });
    }

    group.finish();
}

criterion_group!(benches, bench_keygen, bench_sign, bench_verify);
criterion_main!(benches);
