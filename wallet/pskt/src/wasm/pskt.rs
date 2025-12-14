use crate::pskt::{Input, PSKT as Native};
use crate::role::*;
use kaspa_consensus_core::network::NetworkType;
use kaspa_consensus_core::tx::TransactionId;
use wasm_bindgen::prelude::*;
// use js_sys::Object;
use crate::pskt::Inner;
use kaspa_consensus_client::{Transaction, TransactionInput, TransactionInputT, TransactionOutput, TransactionOutputT};
use serde::{Deserialize, Serialize};
use std::str::FromStr;
use std::sync::MutexGuard;
use std::sync::{Arc, Mutex};
use workflow_wasm::{
    convert::{Cast, CastFromJs, TryCastFromJs},
    // extensions::object::*,
    // error::Error as CastError,
};

use super::error::*;
use super::result::*;

#[derive(Clone, Serialize, Deserialize)]
#[serde(tag = "state", content = "payload")]
pub enum State {
    NoOp(Option<Inner>),
    Creator(Native<Creator>),
    Constructor(Native<Constructor>),
    Updater(Native<Updater>),
    Signer(Native<Signer>),
    Combiner(Native<Combiner>),
    Finalizer(Native<Finalizer>),
    Extractor(Native<Extractor>),
}

impl AsRef<State> for State {
    fn as_ref(&self) -> &State {
        self
    }
}

impl State {
    // this is not a Display trait intentionally
    pub fn display(&self) -> &'static str {
        match self {
            State::NoOp(_) => "Init",
            State::Creator(_) => "Creator",
            State::Constructor(_) => "Constructor",
            State::Updater(_) => "Updater",
            State::Signer(_) => "Signer",
            State::Combiner(_) => "Combiner",
            State::Finalizer(_) => "Finalizer",
            State::Extractor(_) => "Extractor",
        }
    }
}

impl From<State> for PSKT {
    fn from(state: State) -> Self {
        PSKT { state: Arc::new(Mutex::new(Some(state))) }
    }
}

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(typescript_type = "PSKT | Transaction | string | undefined")]
    pub type CtorT;
}

#[derive(Clone, Serialize, Deserialize)]
pub struct Payload {
    data: String,
}

impl<T> TryFrom<Payload> for Native<T> {
    type Error = Error;

    fn try_from(value: Payload) -> Result<Self> {
        let Payload { data } = value;
        if data.starts_with("PSKT") {
            unimplemented!("PSKT binary serialization")
        } else {
            Ok(serde_json::from_str(&data).map_err(|err| format!("Invalid JSON: {err}"))?)
        }
    }
}

#[wasm_bindgen(inspectable)]
#[derive(Clone, CastFromJs)]
pub struct PSKT {
    state: Arc<Mutex<Option<State>>>,
}

impl TryCastFromJs for PSKT {
    type Error = Error;
    fn try_cast_from<'a, R>(value: &'a R) -> std::result::Result<Cast<'a, Self>, Self::Error>
    where
        R: AsRef<JsValue> + 'a,
    {
        Self::resolve(value, || {
            if JsValue::is_undefined(value.as_ref()) {
                Ok(PSKT::from(State::Creator(Native::<Creator>::default())))
            } else if let Some(data) = value.as_ref().as_string() {
                let pskt_inner: Inner = serde_json::from_str(&data).map_err(|_| Error::InvalidPayload)?;
                Ok(PSKT::from(State::NoOp(Some(pskt_inner))))
            } else if let Ok(transaction) = Transaction::try_owned_from(value) {
                let pskt_inner: Inner = transaction.try_into()?;
                Ok(PSKT::from(State::NoOp(Some(pskt_inner))))
            } else {
                Err(Error::InvalidPayload)
            }
        })
    }
}

#[wasm_bindgen]
impl PSKT {
    #[wasm_bindgen(constructor)]
    pub fn new(payload: CtorT) -> Result<PSKT> {
        PSKT::try_owned_from(payload.unchecked_into::<JsValue>().as_ref()).map_err(|err| Error::Ctor(err.to_string()))
    }

    #[wasm_bindgen(getter, js_name = "role")]
    pub fn role_getter(&self) -> String {
        self.state().as_ref().map(|s| s.display().to_string()).unwrap_or_else(|| "Invalid".to_string())
    }

    #[wasm_bindgen(getter, js_name = "payload")]
    pub fn payload_getter(&self) -> JsValue {
        let state = self.state();
        state.as_ref().and_then(|s| workflow_wasm::serde::to_value(s).ok()).unwrap_or(JsValue::UNDEFINED)
    }

    pub fn serialize(&self) -> String {
        let state = self.state();
        state.as_ref().and_then(|s| serde_json::to_string(s).ok()).unwrap_or_default()
    }

    fn state(&self) -> MutexGuard<'_, Option<State>> {
        self.state.lock().unwrap()
    }

    fn with_state<R>(&self, f: impl FnOnce(&State) -> Result<R>) -> Result<R> {
        let guard = self.state();
        let state = guard.as_ref().ok_or(Error::NotInitialized)?;
        f(state)
    }

    fn update_state(&self, f: impl FnOnce(State) -> Result<State>) -> Result<PSKT> {
        let mut guard = self.state.lock().unwrap();
        let current = guard.take().ok_or(Error::NotInitialized)?;
        let backup = current.clone();
        match f(current) {
            Ok(next) => {
                *guard = Some(next);
                Ok(self.clone())
            }
            Err(err) => {
                *guard = Some(backup);
                Err(err)
            }
        }
    }

    /// Change role to `CREATOR`
    /// #[wasm_bindgen(js_name = toCreator)]
    pub fn creator(&self) -> Result<PSKT> {
        self.update_state(|state| {
            let next = match state {
                State::NoOp(inner) => match inner {
                    None => State::Creator(Native::default()),
                    Some(_) => return Err(Error::CreateNotAllowed),
                },
                other => return Err(Error::state(other)),
            };
            Ok(next)
        })
    }

    /// Change role to `CONSTRUCTOR`
    #[wasm_bindgen(js_name = toConstructor)]
    pub fn constructor(&self) -> Result<PSKT> {
        self.update_state(|state| {
            let next = match state {
                State::NoOp(inner) => State::Constructor(inner.ok_or(Error::NotInitialized)?.into()),
                State::Creator(pskt) => State::Constructor(pskt.constructor()),
                other => return Err(Error::state(other)),
            };
            Ok(next)
        })
    }

    /// Change role to `UPDATER`
    #[wasm_bindgen(js_name = toUpdater)]
    pub fn updater(&self) -> Result<PSKT> {
        self.update_state(|state| {
            let next = match state {
                State::NoOp(inner) => State::Updater(inner.ok_or(Error::NotInitialized)?.into()),
                State::Constructor(constructor) => State::Updater(constructor.updater()),
                other => return Err(Error::state(other)),
            };
            Ok(next)
        })
    }

    /// Change role to `SIGNER`
    #[wasm_bindgen(js_name = toSigner)]
    pub fn signer(&self) -> Result<PSKT> {
        self.update_state(|state| {
            let next = match state {
                State::NoOp(inner) => State::Signer(inner.ok_or(Error::NotInitialized)?.into()),
                State::Constructor(pskt) => State::Signer(pskt.signer()),
                State::Updater(pskt) => State::Signer(pskt.signer()),
                State::Combiner(pskt) => State::Signer(pskt.signer()),
                other => return Err(Error::state(other)),
            };
            Ok(next)
        })
    }

    /// Change role to `COMBINER`
    #[wasm_bindgen(js_name = toCombiner)]
    pub fn combiner(&self) -> Result<PSKT> {
        self.update_state(|state| {
            let next = match state {
                State::NoOp(inner) => State::Combiner(inner.ok_or(Error::NotInitialized)?.into()),
                State::Constructor(pskt) => State::Combiner(pskt.combiner()),
                State::Updater(pskt) => State::Combiner(pskt.combiner()),
                State::Signer(pskt) => State::Combiner(pskt.combiner()),
                other => return Err(Error::state(other)),
            };
            Ok(next)
        })
    }

    /// Change role to `FINALIZER`
    #[wasm_bindgen(js_name = toFinalizer)]
    pub fn finalizer(&self) -> Result<PSKT> {
        self.update_state(|state| {
            let next = match state {
                State::NoOp(inner) => State::Finalizer(inner.ok_or(Error::NotInitialized)?.into()),
                State::Combiner(pskt) => State::Finalizer(pskt.finalizer()),
                other => return Err(Error::state(other)),
            };
            Ok(next)
        })
    }

    /// Change role to `EXTRACTOR`
    #[wasm_bindgen(js_name = toExtractor)]
    pub fn extractor(&self) -> Result<PSKT> {
        self.update_state(|state| {
            let next = match state {
                State::NoOp(inner) => State::Extractor(inner.ok_or(Error::NotInitialized)?.into()),
                State::Finalizer(pskt) => State::Extractor(pskt.extractor()?),
                other => return Err(Error::state(other)),
            };
            Ok(next)
        })
    }

    #[wasm_bindgen(js_name = fallbackLockTime)]
    pub fn fallback_lock_time(&self, lock_time: u64) -> Result<PSKT> {
        self.update_state(|state| match state {
            State::Creator(pskt) => Ok(State::Creator(pskt.fallback_lock_time(lock_time))),
            _ => Err(Error::expected_state("Creator")),
        })
    }

    #[wasm_bindgen(js_name = inputsModifiable)]
    pub fn inputs_modifiable(&self) -> Result<PSKT> {
        self.update_state(|state| match state {
            State::Creator(pskt) => Ok(State::Creator(pskt.inputs_modifiable())),
            _ => Err(Error::expected_state("Creator")),
        })
    }

    #[wasm_bindgen(js_name = outputsModifiable)]
    pub fn outputs_modifiable(&self) -> Result<PSKT> {
        self.update_state(|state| match state {
            State::Creator(pskt) => Ok(State::Creator(pskt.outputs_modifiable())),
            _ => Err(Error::expected_state("Creator")),
        })
    }

    #[wasm_bindgen(js_name = noMoreInputs)]
    pub fn no_more_inputs(&self) -> Result<PSKT> {
        self.update_state(|state| match state {
            State::Constructor(pskt) => Ok(State::Constructor(pskt.no_more_inputs())),
            _ => Err(Error::expected_state("Constructor")),
        })
    }

    #[wasm_bindgen(js_name = noMoreOutputs)]
    pub fn no_more_outputs(&self) -> Result<PSKT> {
        self.update_state(|state| match state {
            State::Constructor(pskt) => Ok(State::Constructor(pskt.no_more_outputs())),
            _ => Err(Error::expected_state("Constructor")),
        })
    }

    #[wasm_bindgen(js_name = inputAndRedeemScript)]
    pub fn input_with_redeem(&self, input: &TransactionInputT, data: &JsValue) -> Result<PSKT> {
        let obj = js_sys::Object::from(data.clone());

        let input = TransactionInput::try_owned_from(input)?;
        let mut input: Input = input.try_into()?;
        let redeem_script = js_sys::Reflect::get(&obj, &"redeemScript".into())
            .map_err(|_| Error::custom("redeemScript is missing"))?
            .as_string()
            .ok_or_else(|| Error::custom("redeemScript must be a string"))?;
        input.redeem_script =
            Some(hex::decode(redeem_script).map_err(|e| Error::custom(format!("Redeem script is not a hex string: {}", e)))?);
        self.update_state(|state| match state {
            State::Constructor(pskt) => Ok(State::Constructor(pskt.input(input))),
            _ => Err(Error::expected_state("Constructor")),
        })
    }

    pub fn input(&self, input: &TransactionInputT) -> Result<PSKT> {
        let input = TransactionInput::try_owned_from(input)?;
        self.update_state(|state| match state {
            State::Constructor(pskt) => Ok(State::Constructor(pskt.input(input.try_into()?))),
            _ => Err(Error::expected_state("Constructor")),
        })
    }

    pub fn output(&self, output: &TransactionOutputT) -> Result<PSKT> {
        let output = TransactionOutput::try_owned_from(output)?;
        self.update_state(|state| match state {
            State::Constructor(pskt) => Ok(State::Constructor(pskt.output(output.try_into()?))),
            _ => Err(Error::expected_state("Constructor")),
        })
    }

    #[wasm_bindgen(js_name = setSequence)]
    pub fn set_sequence(&self, n: u64, input_index: usize) -> Result<PSKT> {
        self.update_state(|state| match state {
            State::Updater(pskt) => Ok(State::Updater(pskt.set_sequence(n, input_index)?)),
            _ => Err(Error::expected_state("Updater")),
        })
    }

    #[wasm_bindgen(js_name = calculateId)]
    pub fn calculate_id(&self) -> Result<TransactionId> {
        self.with_state(|state| match state {
            State::Signer(pskt) => Ok(pskt.calculate_id()),
            _ => Err(Error::expected_state("Signer")),
        })
    }

    #[wasm_bindgen(js_name = calculateMass)]
    pub fn calculate_mass(&self, data: &JsValue) -> Result<u64> {
        let obj = js_sys::Object::from(data.clone());
        let network_id = js_sys::Reflect::get(&obj, &"networkId".into())
            .map_err(|_| Error::custom("networkId is missing"))?
            .as_string()
            .ok_or_else(|| Error::custom("networkId must be a string"))?;

        let network_id = NetworkType::from_str(&network_id).map_err(|e| Error::custom(format!("Invalid networkId: {}", e)))?;

        let state_snapshot = self.with_state(|state| Ok(state.clone()))?;
        let cloned_pskt = PSKT::from(state_snapshot);

        let extractor = {
            let finalizer = cloned_pskt.finalizer()?;

            let finalizer_state = finalizer.with_state(|s| Ok(s.clone()))?;

            match finalizer_state {
                State::Finalizer(pskt) => {
                    for input in pskt.inputs.iter() {
                        if input.redeem_script.is_some() {
                            return Err(Error::custom("Mass calculation is not supported for inputs with redeem scripts"));
                        }
                    }
                    let pskt = pskt
                        .finalize_sync(|inner: &Inner| -> Result<Vec<Vec<u8>>> { Ok(vec![vec![0u8, 65]; inner.inputs.len()]) })
                        .map_err(|e| Error::custom(format!("Failed to finalize PSKT: {e}")))?;
                    pskt.extractor()?
                }
                _ => return Err(Error::expected_state("Finalizer")),
            }
        };
        let tx = extractor
            .extract_tx_unchecked(&network_id.into())
            .map_err(|e| Error::custom(format!("Failed to extract transaction: {e}")))?;
        Ok(tx.tx.mass())
    }
}

#[cfg(test)]
mod wasm_pskt_tests {
    use super::*;

    #[test]
    fn state_is_restored_when_transition_returns_error() {
        let pskt = PSKT::from(State::NoOp(Some(Inner::default())));
        assert_eq!(pskt.role_getter(), "Init");

        let err = pskt.creator().err().expect("must fail for payload-initialized PSKT");
        assert!(matches!(err, Error::CreateNotAllowed));

        // Must not be corrupted after the error.
        assert_eq!(pskt.role_getter(), "Init");
    }

    #[test]
    fn state_is_restored_when_expected_state_mismatch() {
        let pskt = PSKT::from(State::Creator(Native::<Creator>::default()));
        assert_eq!(pskt.role_getter(), "Creator");

        assert!(pskt.no_more_inputs().is_err());
        assert_eq!(pskt.role_getter(), "Creator");
    }

    #[test]
    fn role_getter_does_not_panic_when_state_is_missing() {
        let pskt = PSKT { state: Arc::new(Mutex::new(None)) };
        assert_eq!(pskt.role_getter(), "Invalid");
    }
}
