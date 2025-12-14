//!
//! Wallet framework network parameters that control maturity
//! durations and other transaction related properties.
//!

use crate::imports::*;

#[derive(Debug)]
pub struct NetworkParams {
    pub coinbase_transaction_maturity_period_daa: AtomicU64,
    pub coinbase_transaction_stasis_period_daa: u64,
    pub user_transaction_maturity_period_daa: AtomicU64,
    pub additional_compound_transaction_mass: u64,
}

impl NetworkParams {
    #[inline]
    pub fn coinbase_transaction_maturity_period_daa(&self) -> u64 {
        self.coinbase_transaction_maturity_period_daa.load(Ordering::Relaxed)
    }

    #[inline]
    pub fn coinbase_transaction_stasis_period_daa(&self) -> u64 {
        self.coinbase_transaction_stasis_period_daa
    }

    #[inline]
    pub fn user_transaction_maturity_period_daa(&self) -> u64 {
        self.user_transaction_maturity_period_daa.load(Ordering::Relaxed)
    }

    #[inline]
    pub fn additional_compound_transaction_mass(&self) -> u64 {
        self.additional_compound_transaction_mass
    }

    pub fn set_coinbase_transaction_maturity_period_daa(&self, value: u64) {
        self.coinbase_transaction_maturity_period_daa.store(value, Ordering::Relaxed);
    }

    pub fn set_user_transaction_maturity_period_daa(&self, value: u64) {
        self.user_transaction_maturity_period_daa.store(value, Ordering::Relaxed);
    }
}

static MAINNET_NETWORK_PARAMS: LazyLock<NetworkParams> = LazyLock::new(|| NetworkParams {
    coinbase_transaction_maturity_period_daa: AtomicU64::new(1_000),
    coinbase_transaction_stasis_period_daa: 500,
    user_transaction_maturity_period_daa: AtomicU64::new(100),
    additional_compound_transaction_mass: 100,
});

static TESTNET10_NETWORK_PARAMS: LazyLock<NetworkParams> = LazyLock::new(|| NetworkParams {
    coinbase_transaction_maturity_period_daa: AtomicU64::new(1_000),
    coinbase_transaction_stasis_period_daa: 500,
    user_transaction_maturity_period_daa: AtomicU64::new(100),
    additional_compound_transaction_mass: 100,
});

static SIMNET_NETWORK_PARAMS: LazyLock<NetworkParams> = LazyLock::new(|| NetworkParams {
    coinbase_transaction_maturity_period_daa: AtomicU64::new(1_000),
    coinbase_transaction_stasis_period_daa: 500,
    user_transaction_maturity_period_daa: AtomicU64::new(100),
    additional_compound_transaction_mass: 0,
});

static DEVNET_NETWORK_PARAMS: LazyLock<NetworkParams> = LazyLock::new(|| NetworkParams {
    coinbase_transaction_maturity_period_daa: AtomicU64::new(100),
    coinbase_transaction_stasis_period_daa: 50,
    user_transaction_maturity_period_daa: AtomicU64::new(10),
    additional_compound_transaction_mass: 0,
});

impl NetworkParams {
    pub fn from(value: NetworkId) -> &'static NetworkParams {
        match value.network_type {
            NetworkType::Mainnet => &MAINNET_NETWORK_PARAMS,
            NetworkType::Testnet => match value.suffix {
                Some(10) => &TESTNET10_NETWORK_PARAMS,
                Some(x) => {
                    log_warn!("Testnet suffix {x} is not explicitly supported; using testnet-10 network params");
                    &TESTNET10_NETWORK_PARAMS
                }
                None => {
                    log_warn!("Testnet suffix not provided; using testnet-10 network params");
                    &TESTNET10_NETWORK_PARAMS
                }
            },
            NetworkType::Devnet => &DEVNET_NETWORK_PARAMS,
            NetworkType::Simnet => &SIMNET_NETWORK_PARAMS,
        }
    }
}

/// Set the coinbase transaction maturity period DAA score for a given network.
/// This controls the DAA period after which the user transactions are considered mature
/// and the wallet subsystem emits the transaction maturity event.
pub fn set_coinbase_transaction_maturity_period_daa(network_id: &NetworkId, value: u64) -> Result<()> {
    let network_params = NetworkParams::from(*network_id);
    if value <= network_params.coinbase_transaction_stasis_period_daa() {
        return Err(Error::InvalidArgument(format!(
            "Coinbase transaction maturity period must be greater than the stasis period of {} DAA",
            network_params.coinbase_transaction_stasis_period_daa()
        )));
    }
    network_params.set_coinbase_transaction_maturity_period_daa(value);
    Ok(())
}

/// Set the user transaction maturity period DAA score for a given network.
/// This controls the DAA period after which the user transactions are considered mature
/// and the wallet subsystem emits the transaction maturity event.
pub fn set_user_transaction_maturity_period_daa(network_id: &NetworkId, value: u64) -> Result<()> {
    let network_params = NetworkParams::from(*network_id);
    if value == 0 {
        return Err(Error::InvalidArgument("User transaction maturity period must be greater than 0".to_string()));
    }
    network_params.set_user_transaction_maturity_period_daa(value);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn testnet_unknown_suffix_falls_back_to_testnet10_params() {
        let params_10 = NetworkParams::from(NetworkId::with_suffix(NetworkType::Testnet, 10));
        let params_11 = NetworkParams::from(NetworkId::with_suffix(NetworkType::Testnet, 11));
        assert_eq!(params_11.coinbase_transaction_stasis_period_daa(), params_10.coinbase_transaction_stasis_period_daa());
    }

    #[test]
    fn set_coinbase_maturity_rejects_value_not_greater_than_stasis() {
        let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);
        let stasis = NetworkParams::from(network_id).coinbase_transaction_stasis_period_daa();
        assert!(set_coinbase_transaction_maturity_period_daa(&network_id, stasis).is_err());
        assert!(set_coinbase_transaction_maturity_period_daa(&network_id, stasis.saturating_sub(1)).is_err());
    }

    #[test]
    fn set_user_maturity_rejects_zero() {
        let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);
        assert!(set_user_transaction_maturity_period_daa(&network_id, 0).is_err());
    }
}
