//!
//! Primitives for network metrics.
//!

use crate::imports::*;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::OnceLock;

/// Metrics posted by the wallet subsystem.
/// See [`UtxoProcessor::start_metrics`] to enable metrics processing.
/// This struct contains mempool size that can be used to estimate
/// current network congestion.
#[derive(Debug, Clone, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[serde(tag = "type", content = "data")]
#[serde(rename_all = "kebab-case")]
pub enum MetricsUpdate {
    WalletMetrics {
        #[serde(rename = "mempoolSize")]
        mempool_size: u64,
    },
    MasterMetrics {
        metrics: MasterMetricsSnapshot,
    },
}

/// [`MetricsUpdate`] variant identifier.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub enum MetricsUpdateKind {
    WalletMetrics,
    MasterMetrics,
}

impl MetricsUpdate {
    pub fn kind(&self) -> MetricsUpdateKind {
        match self {
            MetricsUpdate::WalletMetrics { .. } => MetricsUpdateKind::WalletMetrics,
            MetricsUpdate::MasterMetrics { .. } => MetricsUpdateKind::MasterMetrics,
        }
    }
}

/// Process-wide counters for MLDSA master usage.
#[derive(Default)]
pub struct MasterMetrics {
    sign_ops_total: AtomicU64,
    rotations_total: AtomicU64,
    delegations_issued_total: AtomicU64,
    delegations_revoked_total: AtomicU64,
    delegations_expiring_soon_total: AtomicU64,
    delegation_requests_total: AtomicU64,
    delegation_responses_total: AtomicU64,
    delegation_responses_failed_total: AtomicU64,
    anchor_mismatch_total: AtomicU64,
    healthcheck_failures_total: AtomicU64,
}

impl MasterMetrics {
    pub fn global() -> &'static Self {
        static INSTANCE: OnceLock<MasterMetrics> = OnceLock::new();
        INSTANCE.get_or_init(Default::default)
    }

    pub fn inc_sign_ops(&self) {
        self.sign_ops_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_rotations(&self) {
        self.rotations_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_delegations_issued(&self) {
        self.delegations_issued_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_delegations_revoked(&self) {
        self.delegations_revoked_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_delegations_expiring_soon(&self) {
        self.delegations_expiring_soon_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_delegation_requests(&self) {
        self.delegation_requests_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_delegation_responses(&self) {
        self.delegation_responses_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_delegation_responses_failed(&self) {
        self.delegation_responses_failed_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_anchor_mismatch(&self) {
        self.anchor_mismatch_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_healthcheck_failures(&self) {
        self.healthcheck_failures_total.fetch_add(1, Ordering::Relaxed);
    }

    pub fn snapshot(&self) -> MasterMetricsSnapshot {
        MasterMetricsSnapshot {
            sign_ops_total: self.sign_ops_total.load(Ordering::Relaxed),
            rotations_total: self.rotations_total.load(Ordering::Relaxed),
            delegations_issued_total: self.delegations_issued_total.load(Ordering::Relaxed),
            delegations_revoked_total: self.delegations_revoked_total.load(Ordering::Relaxed),
            delegations_expiring_soon_total: self.delegations_expiring_soon_total.load(Ordering::Relaxed),
            delegation_requests_total: self.delegation_requests_total.load(Ordering::Relaxed),
            delegation_responses_total: self.delegation_responses_total.load(Ordering::Relaxed),
            delegation_responses_failed_total: self.delegation_responses_failed_total.load(Ordering::Relaxed),
            anchor_mismatch_total: self.anchor_mismatch_total.load(Ordering::Relaxed),
            healthcheck_failures_total: self.healthcheck_failures_total.load(Ordering::Relaxed),
        }
    }
}

/// Serializable snapshot exported via `Events::Metrics`.
#[derive(Debug, Clone, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[serde(rename_all = "camelCase")]
pub struct MasterMetricsSnapshot {
    pub sign_ops_total: u64,
    pub rotations_total: u64,
    pub delegations_issued_total: u64,
    pub delegations_revoked_total: u64,
    pub delegations_expiring_soon_total: u64,
    pub delegation_requests_total: u64,
    pub delegation_responses_total: u64,
    pub delegation_responses_failed_total: u64,
    pub anchor_mismatch_total: u64,
    pub healthcheck_failures_total: u64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn master_metrics_increments_and_snapshot() {
        let metrics = MasterMetrics::default();
        metrics.inc_sign_ops();
        metrics.inc_rotations();
        metrics.inc_delegations_issued();
        metrics.inc_delegations_revoked();
        metrics.inc_delegations_expiring_soon();
        metrics.inc_delegation_requests();
        metrics.inc_delegation_responses();
        metrics.inc_delegation_responses_failed();
        metrics.inc_anchor_mismatch();
        metrics.inc_healthcheck_failures();

        let snapshot = metrics.snapshot();
        assert_eq!(snapshot.sign_ops_total, 1);
        assert_eq!(snapshot.rotations_total, 1);
        assert_eq!(snapshot.delegations_issued_total, 1);
        assert_eq!(snapshot.delegations_revoked_total, 1);
        assert_eq!(snapshot.delegations_expiring_soon_total, 1);
        assert_eq!(snapshot.delegation_requests_total, 1);
        assert_eq!(snapshot.delegation_responses_total, 1);
        assert_eq!(snapshot.delegation_responses_failed_total, 1);
        assert_eq!(snapshot.anchor_mismatch_total, 1);
        assert_eq!(snapshot.healthcheck_failures_total, 1);
    }
}
