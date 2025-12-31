//!
//! Transaction [`GeneratorSettings`] used when
//! constructing and instance of the [`Generator`](crate::tx::Generator).
//!

use crate::events::Events;
use crate::imports::*;
use crate::result::Result;
use crate::tx::generator::stealth_change::DynStealthChangeCreator;
use crate::tx::{Fees, PaymentDestination, RandomFeeSettings};
use crate::utxo::{UtxoContext, UtxoEntryReference, UtxoIterator};
use kaspa_addresses::Address;
use kaspa_consensus_core::tx::TransactionOutput;
use workflow_core::channel::Multiplexer;

pub struct GeneratorSettings {
    // Network type
    pub network_id: NetworkId,
    // Event multiplexer
    pub multiplexer: Option<Multiplexer<Box<Events>>>,
    // Utxo iterator
    pub utxo_iterator: Box<dyn Iterator<Item = UtxoEntryReference> + Send + Sync + 'static>,
    // Utxo Context
    pub source_utxo_context: Option<UtxoContext>,
    // Priority utxo entries that are consumed before others
    pub priority_utxo_entries: Option<Vec<UtxoEntryReference>>,
    // typically a number of keys required to sign the transaction
    pub sig_op_count: u8,
    // number of minimum signatures required to sign the transaction
    pub minimum_signatures: u16,
    // change address
    pub change_address: Address,
    // fee rate
    pub fee_rate: Option<f64>,
    // applies only to the final transaction
    pub final_transaction_priority_fee: Fees,
    // final transaction outputs
    pub final_transaction_destination: PaymentDestination,
    /// Optional override for final transaction outputs (raw ScriptPublicKey-based outputs).
    ///
    /// When set, the generator will use these outputs directly instead of deriving them from
    /// [`PaymentDestination::PaymentOutputs`]. This is useful for advanced cases such as
    /// stealth payouts where the caller already constructed an output script (e.g. version 16).
    pub final_transaction_outputs: Option<Vec<TransactionOutput>>,
    // payload
    pub final_transaction_payload: Option<Vec<u8>>,
    // transaction is a transfer between accounts
    pub destination_utxo_context: Option<UtxoContext>,
    /// Optional creator for stealth change outputs.
    /// Required when `change_address.version == Version::Stealth`.
    /// This allows pre-calculation of spending keys for change outputs,
    /// avoiding the need to re-scan the blockchain.
    pub stealth_change_creator: Option<DynStealthChangeCreator>,
    /// Optional randomization for final priority fee.
    pub random_fee_settings: RandomFeeSettings,
    /// Include delegation id TLV in stealth signatures (Iteration 4).
    pub include_delegation_id: bool,
}

// impl std::fmt::Debug for GeneratorSettings {
//     fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
//         f.debug_struct("GeneratorSettings")
//             .field("network_id", &self.network_id)
//             // .field("multiplexer", &self.multiplexer)
//             .field("utxo_iterator", &"Box<dyn Iterator<Item = UtxoEntryReference> + Send + Sync + 'static>")
//             // .field("source_utxo_context", &self.source_utxo_context)
//             .field("sig_op_count", &self.sig_op_count)
//             .field("minimum_signatures", &self.minimum_signatures)
//             .field("change_address", &self.change_address)
//             .field("final_transaction_priority_fee", &self.final_transaction_priority_fee)
//             .field("final_transaction_destination", &self.final_transaction_destination)
//             .field("final_transaction_payload", &self.final_transaction_payload)
//             // .field("destination_utxo_context", &self.destination_utxo_context)
//             .finish()
//     }
// }

impl GeneratorSettings {
    pub fn try_new_with_account(
        account: Arc<dyn Account>,
        final_transaction_destination: PaymentDestination,
        fee_rate: Option<f64>,
        final_priority_fee: Fees,
        final_transaction_payload: Option<Vec<u8>>,
        random_fee_settings: Option<RandomFeeSettings>,
    ) -> Result<Self> {
        let network_id = account.utxo_context().processor().network_id()?;
        let change_address = account.change_address()?;
        let multiplexer = account.wallet().multiplexer().clone();
        let sig_op_count = account.sig_op_count();
        let minimum_signatures = account.minimum_signatures();

        let utxo_iterator = UtxoIterator::new(account.utxo_context());
        let random_fee_settings = random_fee_settings.unwrap_or_default();
        random_fee_settings.validate()?;

        let settings = GeneratorSettings {
            network_id,
            multiplexer: Some(multiplexer),
            sig_op_count,
            minimum_signatures,
            change_address,
            utxo_iterator: Box::new(utxo_iterator),
            source_utxo_context: Some(account.utxo_context().clone()),
            priority_utxo_entries: None,

            fee_rate,
            final_transaction_priority_fee: final_priority_fee,
            final_transaction_destination,
            final_transaction_outputs: None,
            final_transaction_payload,
            destination_utxo_context: None,
            stealth_change_creator: None,
            random_fee_settings,
            include_delegation_id: true,
        };

        Ok(settings)
    }

    pub fn try_new_with_context(
        utxo_context: UtxoContext,
        priority_utxo_entries: Option<Vec<UtxoEntryReference>>,
        change_address: Address,
        sig_op_count: u8,
        minimum_signatures: u16,
        final_transaction_destination: PaymentDestination,
        fee_rate: Option<f64>,
        final_priority_fee: Fees,
        final_transaction_payload: Option<Vec<u8>>,
        multiplexer: Option<Multiplexer<Box<Events>>>,
        random_fee_settings: Option<RandomFeeSettings>,
    ) -> Result<Self> {
        let network_id = utxo_context.processor().network_id()?;
        let utxo_iterator = UtxoIterator::new(&utxo_context);
        let random_fee_settings = random_fee_settings.unwrap_or_default();
        random_fee_settings.validate()?;

        let settings = GeneratorSettings {
            network_id,
            multiplexer,
            sig_op_count,
            minimum_signatures,
            change_address,
            utxo_iterator: Box::new(utxo_iterator),
            source_utxo_context: Some(utxo_context),
            priority_utxo_entries,

            fee_rate,
            final_transaction_priority_fee: final_priority_fee,
            final_transaction_destination,
            final_transaction_outputs: None,
            final_transaction_payload,
            destination_utxo_context: None,
            stealth_change_creator: None,
            random_fee_settings,
            include_delegation_id: true,
        };

        Ok(settings)
    }

    #[allow(clippy::too_many_arguments)]
    pub fn try_new_with_iterator(
        network_id: NetworkId,
        utxo_iterator: Box<dyn Iterator<Item = UtxoEntryReference> + Send + Sync + 'static>,
        priority_utxo_entries: Option<Vec<UtxoEntryReference>>,
        change_address: Address,
        sig_op_count: u8,
        minimum_signatures: u16,
        final_transaction_destination: PaymentDestination,
        fee_rate: Option<f64>,
        final_priority_fee: Fees,
        final_transaction_payload: Option<Vec<u8>>,
        multiplexer: Option<Multiplexer<Box<Events>>>,
        random_fee_settings: Option<RandomFeeSettings>,
    ) -> Result<Self> {
        let random_fee_settings = random_fee_settings.unwrap_or_default();
        random_fee_settings.validate()?;

        let settings = GeneratorSettings {
            network_id,
            multiplexer,
            sig_op_count,
            minimum_signatures,
            change_address,
            utxo_iterator: Box::new(utxo_iterator),
            source_utxo_context: None,
            priority_utxo_entries,

            fee_rate,
            final_transaction_priority_fee: final_priority_fee,
            final_transaction_destination,
            final_transaction_outputs: None,
            final_transaction_payload,
            destination_utxo_context: None,
            stealth_change_creator: None,
            random_fee_settings,
            include_delegation_id: true,
        };

        Ok(settings)
    }

    /// Overrides final transaction outputs with a raw list of transaction outputs.
    ///
    /// This is intended for advanced callers that need to supply a pre-built
    /// `ScriptPublicKey` (for example, stealth scripts with version 16).
    pub fn with_final_transaction_outputs(mut self, outputs: Vec<TransactionOutput>) -> Self {
        self.final_transaction_outputs = Some(outputs);
        self
    }

    /// Sets the stealth change creator for creating change outputs to stealth addresses.
    ///
    /// This is required when `change_address` is a stealth address (Version::Stealth).
    /// The creator pre-calculates the spending key so we don't need to re-scan
    /// the blockchain to find our own change output.
    pub fn with_stealth_change_creator(mut self, creator: DynStealthChangeCreator) -> Self {
        self.stealth_change_creator = Some(creator);
        self
    }

    pub fn with_include_delegation_id(mut self, include: bool) -> Self {
        self.include_delegation_id = include;
        self
    }

    pub fn utxo_context_transfer(mut self, destination_utxo_context: &UtxoContext) -> Self {
        self.destination_utxo_context = Some(destination_utxo_context.clone());
        self
    }

    pub fn with_random_fee_settings(mut self, settings: RandomFeeSettings) -> Result<Self> {
        settings.validate()?;
        self.random_fee_settings = settings;
        Ok(self)
    }
}
