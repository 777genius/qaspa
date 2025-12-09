use super::events::EventType;
use borsh::{BorshDeserialize, BorshSerialize};
use derive_more::Display;
use kaspa_addresses::Address;
use serde::{Deserialize, Serialize};
use workflow_serializer::prelude::*;

macro_rules! scope_enum {
    ($(#[$meta:meta])* $vis:vis enum $name:ident {
    $($(#[$variant_meta:meta])* $variant_name:ident,)*
    }) => {
        paste::paste! {
            $(#[$meta])*
            $vis enum $name {
                $($(#[$variant_meta])* $variant_name([<$variant_name Scope>])),*
            }

            impl std::convert::From<EventType> for $name {
                fn from(value: EventType) -> Self {
                    match value {
                        $(EventType::$variant_name => $name::$variant_name(kaspa_notify::scope::[<$variant_name Scope>]::default())),*
                    }
                }
            }

            $(impl std::convert::From<[<$variant_name Scope>]> for Scope {
                fn from(value: [<$variant_name Scope>]) -> Self {
                    Scope::$variant_name(value)
                }
            })*
        }
    }
}

scope_enum! {
/// Subscription scope for every event type
#[derive(Clone, Display, Debug, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub enum Scope {
    BlockAdded,
    VirtualChainChanged,
    FinalityConflict,
    FinalityConflictResolved,
    UtxosChanged,
    SinkBlueScoreChanged,
    VirtualDaaScoreChanged,
    PruningPointUtxoSetOverride,
    NewBlockTemplate,
    /// Stealth UTXO changes filtered by script version
    StealthUtxosChanged,
}
}

impl Scope {
    pub fn event_type(&self) -> EventType {
        self.into()
    }
}

impl Serializer for Scope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        store!(Scope, self, writer)?;
        Ok(())
    }
}

impl Deserializer for Scope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        load!(Scope, reader)
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct BlockAddedScope {
    pub include_stealth_outputs: bool,
}

impl BlockAddedScope {
    pub fn new(include_stealth_outputs: bool) -> Self {
        Self { include_stealth_outputs }
    }
}

impl std::fmt::Display for BlockAddedScope {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "BlockAddedScope{}", if self.include_stealth_outputs { " with stealth outputs" } else { "" })
    }
}

impl Serializer for BlockAddedScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &2, writer)?;
        store!(bool, &self.include_stealth_outputs, writer)?;
        Ok(())
    }
}

impl Deserializer for BlockAddedScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let version = load!(u16, reader)?;
        let include_stealth_outputs = if version >= 2 { load!(bool, reader)? } else { false };
        Ok(Self { include_stealth_outputs })
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct VirtualChainChangedScope {
    pub include_accepted_transaction_ids: bool,
}

impl VirtualChainChangedScope {
    pub fn new(include_accepted_transaction_ids: bool) -> Self {
        Self { include_accepted_transaction_ids }
    }
}

impl std::fmt::Display for VirtualChainChangedScope {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "VirtualChainChangedScope{}", if self.include_accepted_transaction_ids { " with accepted transactions" } else { "" })
    }
}

impl Serializer for VirtualChainChangedScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        store!(bool, &self.include_accepted_transaction_ids, writer)?;
        Ok(())
    }
}

impl Deserializer for VirtualChainChangedScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        let include_accepted_transaction_ids = load!(bool, reader)?;
        Ok(Self { include_accepted_transaction_ids })
    }
}

#[derive(Clone, Display, Debug, PartialEq, Eq, Default, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct FinalityConflictScope {}

impl Serializer for FinalityConflictScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        Ok(())
    }
}

impl Deserializer for FinalityConflictScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        Ok(Self {})
    }
}

#[derive(Clone, Display, Debug, PartialEq, Eq, Default, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct FinalityConflictResolvedScope {}

impl Serializer for FinalityConflictResolvedScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        Ok(())
    }
}

impl Deserializer for FinalityConflictResolvedScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        Ok(Self {})
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct UtxosChangedScope {
    pub addresses: Vec<Address>,
}

impl std::fmt::Display for UtxosChangedScope {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let addresses = match self.addresses.len() {
            0 => "all".to_string(),
            1 => format!("{}", self.addresses[0]),
            n => format!("{} addresses", n),
        };
        write!(f, "UtxosChangedScope ({})", addresses)
    }
}

impl PartialEq for UtxosChangedScope {
    fn eq(&self, other: &Self) -> bool {
        self.addresses.len() == other.addresses.len() && self.addresses.iter().all(|x| other.addresses.contains(x))
    }
}

impl Eq for UtxosChangedScope {}

impl UtxosChangedScope {
    pub fn new(addresses: Vec<Address>) -> Self {
        Self { addresses }
    }
}

impl Serializer for UtxosChangedScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        store!(Vec<Address>, &self.addresses, writer)?;
        Ok(())
    }
}

impl Deserializer for UtxosChangedScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        let addresses = load!(Vec<Address>, reader)?;
        Ok(Self { addresses })
    }
}

#[derive(Clone, Display, Debug, Default, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct SinkBlueScoreChangedScope {}

impl Serializer for SinkBlueScoreChangedScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        Ok(())
    }
}

impl Deserializer for SinkBlueScoreChangedScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        Ok(Self {})
    }
}

#[derive(Clone, Display, Debug, Default, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct VirtualDaaScoreChangedScope {}

impl Serializer for VirtualDaaScoreChangedScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        Ok(())
    }
}

impl Deserializer for VirtualDaaScoreChangedScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        Ok(Self {})
    }
}

#[derive(Clone, Display, Debug, Default, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct PruningPointUtxoSetOverrideScope {}

impl Serializer for PruningPointUtxoSetOverrideScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        Ok(())
    }
}

impl Deserializer for PruningPointUtxoSetOverrideScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        Ok(Self {})
    }
}

#[derive(Clone, Display, Debug, Default, PartialEq, Eq, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct NewBlockTemplateScope {}

impl Serializer for NewBlockTemplateScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        Ok(())
    }
}

impl Deserializer for NewBlockTemplateScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        Ok(Self {})
    }
}

/// Scope for stealth UTXO notifications filtered by script version.
///
/// This allows clients to subscribe to UTXO changes for specific script versions
/// (e.g., STEALTH_SCRIPT_VERSION = 16) without needing to know addresses.
#[derive(Clone, Debug, Default, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct StealthUtxosChangedScope {
    /// Script versions to filter by. Empty means subscribe to ALL versions (dangerous!).
    pub script_versions: Vec<u16>,
}

impl std::fmt::Display for StealthUtxosChangedScope {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let versions = match self.script_versions.len() {
            0 => "all".to_string(),
            1 => format!("v{}", self.script_versions[0]),
            n => format!("{} versions", n),
        };
        write!(f, "StealthUtxosChangedScope ({})", versions)
    }
}

impl PartialEq for StealthUtxosChangedScope {
    fn eq(&self, other: &Self) -> bool {
        self.script_versions.len() == other.script_versions.len()
            && self.script_versions.iter().all(|x| other.script_versions.contains(x))
    }
}

impl Eq for StealthUtxosChangedScope {}

impl StealthUtxosChangedScope {
    pub fn new(script_versions: Vec<u16>) -> Self {
        Self { script_versions }
    }
}

impl Serializer for StealthUtxosChangedScope {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &1, writer)?;
        store!(Vec<u16>, &self.script_versions, writer)?;
        Ok(())
    }
}

impl Deserializer for StealthUtxosChangedScope {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let _version = load!(u16, reader)?;
        let script_versions = load!(Vec<u16>, reader)?;
        Ok(Self { script_versions })
    }
}
