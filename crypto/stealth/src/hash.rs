//! Domain-separated hash functions for stealth addresses
//!
//! Each cryptographic operation uses a distinct hash domain to prevent
//! cross-protocol attacks. This follows the principle of domain separation
//! where Hash(domain1, x) != Hash(domain2, x) for any x.

use kaspa_hashes::{HASH_SIZE, Hash, HasherBase};

/// Domain separator for computing the blinding factor (tweak scalar)
/// Used in: t = Hash(domain, shared_secret) where P_dest = P_spend + t*G
const DOMAIN_BLINDING_FACTOR: &[u8] = b"StealthBlindingFactor";

/// Domain separator for computing the view tag
/// Used in: tag = Hash(domain, shared_secret)[0]
const DOMAIN_VIEW_TAG: &[u8] = b"StealthViewTag";

/// Blake2b hasher with domain separation for blinding factor computation.
///
/// The blinding factor `t` is derived as: t = BlindingFactorHash(shared_secret)
/// This scalar is then used to compute P_dest = P_spend + t*G
#[derive(Clone)]
pub struct BlindingFactorHash(blake2b_simd::State);

impl BlindingFactorHash {
    /// Creates a new hasher initialized with the domain separator
    #[inline]
    pub fn new() -> Self {
        Self(blake2b_simd::Params::new().hash_length(HASH_SIZE).key(DOMAIN_BLINDING_FACTOR).to_state())
    }

    /// Updates the hasher with additional data
    #[inline]
    pub fn write<A: AsRef<[u8]>>(&mut self, data: A) {
        self.0.update(data.as_ref());
    }

    /// Finalizes the hash and returns the result
    #[inline]
    pub fn finalize(self) -> Hash {
        let mut out = [0u8; HASH_SIZE];
        out.copy_from_slice(self.0.finalize().as_bytes());
        Hash::from_bytes(out)
    }

    /// Convenience method: hash data in one call
    #[inline]
    pub fn hash<A: AsRef<[u8]>>(data: A) -> Hash {
        let mut hasher = Self::new();
        hasher.write(data);
        hasher.finalize()
    }
}

impl Default for BlindingFactorHash {
    fn default() -> Self {
        Self::new()
    }
}

impl HasherBase for BlindingFactorHash {
    fn update<A: AsRef<[u8]>>(&mut self, data: A) -> &mut Self {
        self.write(data);
        self
    }
}

/// Blake2b hasher with domain separation for view tag computation.
///
/// The view tag is a single byte used to quickly filter transactions:
/// tag = ViewTagHash(shared_secret)[0]
///
/// This provides ~256x speedup in scanning by avoiding expensive
/// EC operations for outputs that clearly don't belong to us.
#[derive(Clone)]
pub struct ViewTagHash(blake2b_simd::State);

impl ViewTagHash {
    /// Creates a new hasher initialized with the domain separator
    #[inline]
    pub fn new() -> Self {
        Self(blake2b_simd::Params::new().hash_length(HASH_SIZE).key(DOMAIN_VIEW_TAG).to_state())
    }

    /// Updates the hasher with additional data
    #[inline]
    pub fn write<A: AsRef<[u8]>>(&mut self, data: A) {
        self.0.update(data.as_ref());
    }

    /// Finalizes the hash and returns the result
    #[inline]
    pub fn finalize(self) -> Hash {
        let mut out = [0u8; HASH_SIZE];
        out.copy_from_slice(self.0.finalize().as_bytes());
        Hash::from_bytes(out)
    }

    /// Convenience method: hash data and return first byte as view tag
    #[inline]
    pub fn compute_tag<A: AsRef<[u8]>>(data: A) -> u8 {
        let mut hasher = Self::new();
        hasher.write(data);
        hasher.finalize().as_bytes()[0]
    }
}

impl Default for ViewTagHash {
    fn default() -> Self {
        Self::new()
    }
}

impl HasherBase for ViewTagHash {
    fn update<A: AsRef<[u8]>>(&mut self, data: A) -> &mut Self {
        self.write(data);
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_domain_separation() {
        let data = b"test shared secret";

        let blinding_hash = BlindingFactorHash::hash(data);
        let view_tag_hash = {
            let mut h = ViewTagHash::new();
            h.write(data);
            h.finalize()
        };

        // Different domains must produce different hashes
        assert_ne!(blinding_hash.as_bytes(), view_tag_hash.as_bytes(), "Domain separation failed: same input produced same hash");
    }

    #[test]
    fn test_blinding_factor_deterministic() {
        let data = b"deterministic test";

        let hash1 = BlindingFactorHash::hash(data);
        let hash2 = BlindingFactorHash::hash(data);

        assert_eq!(hash1.as_bytes(), hash2.as_bytes());
    }

    #[test]
    fn test_view_tag_deterministic() {
        let data = b"deterministic test";

        let tag1 = ViewTagHash::compute_tag(data);
        let tag2 = ViewTagHash::compute_tag(data);

        assert_eq!(tag1, tag2);
    }

    #[test]
    fn test_incremental_hashing() {
        let data = b"hello world";

        // One-shot
        let hash1 = BlindingFactorHash::hash(data);

        // Incremental
        let mut hasher = BlindingFactorHash::new();
        hasher.write(b"hello ");
        hasher.write(b"world");
        let hash2 = hasher.finalize();

        assert_eq!(hash1.as_bytes(), hash2.as_bytes());
    }
}
