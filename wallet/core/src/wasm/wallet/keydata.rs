use crate::imports::*;
use crate::result::Result;
use crate::storage::keydata;
use kaspa_utils::hex::ToHex;

/// @category Wallet SDK
#[wasm_bindgen]
pub struct PrvKeyDataInfo {
    inner: Arc<keydata::PrvKeyDataInfo>,
    #[allow(dead_code)]
    wallet: Arc<Wallet>,
}

impl PrvKeyDataInfo {
    pub fn new(wallet: Arc<Wallet>, inner: Arc<keydata::PrvKeyDataInfo>) -> PrvKeyDataInfo {
        PrvKeyDataInfo { wallet, inner }
    }
}

#[wasm_bindgen]
impl PrvKeyDataInfo {
    #[wasm_bindgen(getter)]
    pub fn id(&self) -> String {
        self.inner.id.to_hex()
    }

    #[wasm_bindgen(getter)]
    pub fn name(&self) -> JsValue {
        self.inner.name.clone().map(JsValue::from).unwrap_or(JsValue::UNDEFINED)
    }

    #[wasm_bindgen(getter, js_name = "isEncrypted")]
    pub fn is_encrypted(&self) -> JsValue {
        self.inner.is_encrypted.into()
    }

    #[wasm_bindgen(getter)]
    pub fn kind(&self) -> String {
        format!("{:?}", self.inner.kind)
    }

    #[wasm_bindgen(getter)]
    pub fn level(&self) -> JsValue {
        self.inner.level.map(JsValue::from).unwrap_or(JsValue::UNDEFINED)
    }

    #[wasm_bindgen(getter)]
    pub fn anchor(&self) -> JsValue {
        self.inner.anchor.map(|anchor| anchor.to_vec().to_hex()).map(JsValue::from).unwrap_or(JsValue::UNDEFINED)
    }

    #[wasm_bindgen(js_name = "setName")]
    pub fn set_name(&mut self, _name: String) -> Result<()> {
        todo!()
    }
}
