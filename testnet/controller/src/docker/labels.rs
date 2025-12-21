/// Docker label constants for testnet containers
pub const LABEL_CLUSTER: &str = "qaspa.cluster";
pub const LABEL_ROLE: &str = "qaspa.role";
pub const LABEL_NAME: &str = "qaspa.name";
pub const LABEL_P2P_PORT: &str = "qaspa.ports.p2p";
pub const LABEL_GRPC_PORT: &str = "qaspa.ports.grpc";
pub const LABEL_STATS_PORT: &str = "qaspa.ports.stats";
pub const LABEL_TARGET_NODE: &str = "qaspa.target_node";

/// Role constants
pub const ROLE_SEED: &str = "seed";
pub const ROLE_PEER: &str = "peer";
pub const ROLE_MINER: &str = "miner";
pub const ROLE_TXGEN: &str = "txgen";
pub const ROLE_CONTROLLER: &str = "controller";

/// Get label filter for cluster containers
pub fn cluster_filter(cluster_name: &str) -> String {
    format!("{}={}", LABEL_CLUSTER, cluster_name)
}

/// Get label filter for specific role
pub fn role_filter(cluster_name: &str, role: &str) -> Vec<String> {
    vec![format!("{}={}", LABEL_CLUSTER, cluster_name), format!("{}={}", LABEL_ROLE, role)]
}
