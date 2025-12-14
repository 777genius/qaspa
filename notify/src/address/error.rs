use thiserror::Error;

#[derive(Clone, Debug, Error)]
pub enum Error {
    #[error("the address store reached the maximum capacity")]
    MaxCapacityReached,

    #[error("stealth addresses are not supported by address tracking")]
    StealthAddressNotSupported,

    #[error("invalid address: {0}")]
    InvalidAddress(String),
}

pub type Result<T> = std::result::Result<T, Error>;
