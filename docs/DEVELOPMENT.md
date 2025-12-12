# Development Guide

This guide covers the setup and best practices for contributing to the project.

## Initial Setup

After cloning the repository, configure git hooks to ensure code quality:

```bash
git config core.hooksPath githooks
```

This enables automatic code formatting with `cargo fmt` on every commit.

## Pre-commit Hooks

The pre-commit hook automatically:
- Runs `cargo fmt --all` to format Rust code
- Stages formatted files to include them in your commit

This prevents CI failures due to formatting issues.

## Code Style

### Rust

- Follow standard Rust formatting (`rustfmt`)
- Run `cargo clippy` before submitting PRs
- Ensure all tests pass with `cargo test`

### TypeScript (WASM SDK)

TypeScript configurations are located in:
- `wasm/build/docs/tsconfig.json` - for documentation generation
- `wasm/examples/nodejs/typescript/tsconfig.json` - for Node.js examples

## Building

### Native Build

```bash
cargo build --release
```

### WASM SDK Build

```bash
cd wasm
./build-release
```

## Testing

### Run All Tests

```bash
cargo test --workspace
```

### Run Specific Package Tests

```bash
cargo test -p <package-name>
```

## CI/CD Checks

Before pushing, ensure your code passes these checks locally:

```bash
# Format check
cargo fmt --all -- --check

# Linting
cargo clippy --workspace --tests --benches -- -D warnings

# Tests
cargo test --workspace
```

## Troubleshooting

### Pre-commit hook not working

Verify the hook path is configured:

```bash
git config --get core.hooksPath
```

Should output: `githooks`

### Formatting differences in CI

If CI fails with formatting errors but your local code is formatted:

1. Ensure you have the latest `rustfmt`:
   ```bash
   rustup update
   ```

2. Re-run formatting:
   ```bash
   cargo fmt --all
   ```

3. Check for unstaged changes:
   ```bash
   git diff
   ```

