use parking_lot::RwLock;
use std::collections::HashSet;
use std::sync::Arc;
use tracing::debug;

use crate::docker::ContainerInfo;
use crate::error::{ControllerError, Result};

/// Port pair for P2P and gRPC
#[derive(Debug, Clone, Copy)]
pub struct PortPair {
    pub p2p: u16,
    pub grpc: u16,
}

/// Centralized port allocator for testnet nodes
pub struct PortAllocator {
    grpc_base: u16,
    p2p_base: u16,
    allocated: Arc<RwLock<HashSet<u16>>>,
}

/// Maximum start port to ensure we can allocate at least a few containers
/// Port range for 100 containers: base + (99 * 100) = base + 9900
/// So max safe base is 65535 - 9900 = 55635
const MAX_SAFE_BASE_PORT: u16 = 55635;

impl PortAllocator {
    /// Create a new port allocator.
    ///
    /// # Errors
    /// Returns error if base ports are too high to allocate any containers.
    pub fn new(grpc_base: u16, p2p_base: u16) -> Result<Self> {
        // Validate that start ports allow reasonable allocation
        if grpc_base > MAX_SAFE_BASE_PORT {
            return Err(ControllerError::InvalidConfig(format!(
                "grpc_base {} is too high, max allowed is {}",
                grpc_base, MAX_SAFE_BASE_PORT
            )));
        }
        if p2p_base > MAX_SAFE_BASE_PORT {
            return Err(ControllerError::InvalidConfig(format!(
                "p2p_base {} is too high, max allowed is {}",
                p2p_base, MAX_SAFE_BASE_PORT
            )));
        }

        Ok(Self { grpc_base, p2p_base, allocated: Arc::new(RwLock::new(HashSet::new())) })
    }

    /// Allocate a new port pair
    pub fn allocate(&self) -> Result<PortPair> {
        let mut allocated = self.allocated.write();

        // Find next available port pair
        // Pattern: grpc=16210, p2p=16211; grpc=16310, p2p=16311; etc.
        for offset in (0..100).map(|i: u16| i * 100) {
            // Check for port overflow (must not exceed u16::MAX = 65535)
            let Some(grpc) = self.grpc_base.checked_add(offset) else {
                continue;
            };
            let Some(p2p) = self.p2p_base.checked_add(offset) else {
                continue;
            };

            if !allocated.contains(&grpc) && !allocated.contains(&p2p) {
                allocated.insert(grpc);
                allocated.insert(p2p);
                debug!("Allocated ports: grpc={}, p2p={}", grpc, p2p);
                return Ok(PortPair { p2p, grpc });
            }
        }

        Err(ControllerError::NoPortsAvailable)
    }

    /// Release a port pair
    pub fn release(&self, pair: PortPair) {
        let mut allocated = self.allocated.write();
        allocated.remove(&pair.grpc);
        allocated.remove(&pair.p2p);
        debug!("Released ports: grpc={}, p2p={}", pair.grpc, pair.p2p);
    }

    /// Restore allocated ports from existing containers
    pub fn restore_from_containers(&self, containers: &[ContainerInfo]) {
        let mut allocated = self.allocated.write();

        for container in containers {
            if container.p2p_port > 0 {
                allocated.insert(container.p2p_port);
            }
            if container.grpc_port > 0 {
                allocated.insert(container.grpc_port);
            }
        }

        debug!("Restored {} allocated ports", allocated.len());
    }

    /// Get count of allocated port pairs
    pub fn allocated_count(&self) -> usize {
        self.allocated.read().len() / 2
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_allocate_ports() {
        let allocator = PortAllocator::new(16210, 16211).unwrap();

        let pair1 = allocator.allocate().unwrap();
        assert_eq!(pair1.grpc, 16210);
        assert_eq!(pair1.p2p, 16211);

        let pair2 = allocator.allocate().unwrap();
        assert_eq!(pair2.grpc, 16310);
        assert_eq!(pair2.p2p, 16311);

        allocator.release(pair1);

        let pair3 = allocator.allocate().unwrap();
        assert_eq!(pair3.grpc, 16210);
        assert_eq!(pair3.p2p, 16211);
    }
}
