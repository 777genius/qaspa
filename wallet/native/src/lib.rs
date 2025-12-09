//! Native bindings for kaspa-wallet core.
//!
//! This library exposes a small C-friendly surface that allows external
//! runtimes (Flutter, Go, etc.) to consume wallet metadata such as
//! MLDSA master anchor descriptors without depending on the internal
//! Rust representations.

pub mod runtime;
pub mod types;

pub use runtime::*;
pub use types::*;
