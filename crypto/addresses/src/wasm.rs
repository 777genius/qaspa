use alloc::{
    string::{String, ToString},
    vec::Vec,
};

use wasm_bindgen::prelude::*;
use workflow_wasm::{
    convert::{Cast, TryCastFromJs},
    extensions::object::*,
};

use crate::{Address, AddressError, Prefix, Version};

impl From<workflow_wasm::error::Error> for AddressError {
    fn from(e: workflow_wasm::error::Error) -> Self {
        AddressError::WASM(e.to_string())
    }
}

#[wasm_bindgen]
impl Address {
    #[wasm_bindgen(constructor)]
    pub fn constructor(address: &str) -> Result<Address, JsValue> {
        address.try_into().map_err(|err| JsValue::from_str(&format!("invalid address `{address}`: {err}")))
    }

    #[wasm_bindgen(js_name = validate)]
    pub fn validate(address: &str) -> bool {
        Self::try_from(address).is_ok()
    }

    /// Convert an address to a string.
    #[wasm_bindgen(js_name = toString)]
    pub fn address_to_string(&self) -> String {
        self.into()
    }

    /// Convert an address to a string, using `qaspa*` aliases for regular (non-stealth) prefixes.
    #[wasm_bindgen(js_name = toStringQaspa)]
    pub fn address_to_string_qaspa(&self) -> String {
        self.to_string_qaspa()
    }

    #[wasm_bindgen(getter, js_name = "version")]
    pub fn version_to_string(&self) -> String {
        self.version.to_string()
    }

    #[wasm_bindgen(getter, js_name = "prefix")]
    pub fn prefix_to_string(&self) -> String {
        self.prefix.to_string()
    }

    #[wasm_bindgen(setter, js_name = "setPrefix")]
    pub fn set_prefix_from_str(&mut self, prefix: &str) -> Result<(), JsValue> {
        let candidate = Prefix::try_from(prefix).map_err(|err| JsValue::from_str(&format!("invalid prefix `{prefix}`: {err}")))?;
        if candidate.is_stealth() != (self.version == Version::Stealth) {
            return Err(JsValue::from_str("invalid stealth prefix/version combination"));
        }
        self.prefix = candidate;
        Ok(())
    }

    #[wasm_bindgen(getter, js_name = "payload")]
    pub fn payload_to_string(&self) -> String {
        self.encode_payload()
    }

    #[wasm_bindgen(js_name = short)]
    pub fn short_wasm(&self, n: usize) -> String {
        self.short(n)
    }

    #[wasm_bindgen(js_name = shortQaspa)]
    pub fn short_qaspa_wasm(&self, n: usize) -> String {
        self.short_qaspa(n)
    }
}

impl TryCastFromJs for Address {
    type Error = AddressError;

    fn try_cast_from<'a, R>(value: &'a R) -> Result<Cast<'a, Self>, Self::Error>
    where
        R: AsRef<JsValue> + 'a,
    {
        Self::resolve(value, || {
            if let Some(string) = value.as_ref().as_string() {
                Address::try_from(string.trim())
            } else if let Some(object) = js_sys::Object::try_from(value.as_ref()) {
                let prefix: Prefix = object.get_string("prefix")?.as_str().try_into()?;
                let payload = object.get_string("payload")?;
                Address::decode_payload(prefix, &payload)
            } else {
                Err(AddressError::InvalidAddress)
            }
        })
    }
}

#[wasm_bindgen]
extern "C" {
    /// WASM (TypeScript) type representing an Address-like object: `Address | string`.
    ///
    /// @category Address
    #[wasm_bindgen(extends = js_sys::Array, typescript_type = "Address | string")]
    pub type AddressT;
    /// WASM (TypeScript) type representing an array of Address-like objects: `(Address | string)[]`.
    ///
    /// @category Address
    #[wasm_bindgen(extends = js_sys::Array, typescript_type = "(Address | string)[]")]
    pub type AddressOrStringArrayT;
    /// WASM (TypeScript) type representing an array of [`Address`] objects: `Address[]`.
    ///
    /// @category Address
    #[wasm_bindgen(extends = js_sys::Array, typescript_type = "Address[]")]
    pub type AddressArrayT;
    /// WASM (TypeScript) type representing an [`Address`] or an undefined value: `Address | undefined`.
    ///
    /// @category Address
    #[wasm_bindgen(typescript_type = "Address | undefined")]
    pub type AddressOrUndefinedT;
}

impl TryFrom<AddressOrStringArrayT> for Vec<Address> {
    type Error = AddressError;

    fn try_from(js_value: AddressOrStringArrayT) -> Result<Self, Self::Error> {
        if js_value.is_array() {
            js_value.iter().map(Address::try_owned_from).collect::<Result<Vec<Address>, AddressError>>()
        } else {
            Err(AddressError::InvalidAddressArray)
        }
    }
}

#[cfg(all(test, target_arch = "wasm32"))]
mod tests {
    extern crate std;

    use crate::{Address, Prefix, Version};
    use js_sys::Object;
    use wasm_bindgen::{__rt::IntoJsResult, JsValue, convert::IntoWasmAbi};
    use wasm_bindgen_test::wasm_bindgen_test;
    use workflow_wasm::{extensions::ObjectExtension, serde::from_value, serde::to_value};

    #[wasm_bindgen_test]
    fn test_wasm_serde_constructor() {
        let str = "kaspa:qpauqsvk7yf9unexwmxsnmg547mhyga37csh0kj53q6xxgl24ydxjsgzthw5j";
        let a = Address::constructor(str).unwrap();
        let value = to_value(&a).unwrap();

        assert_eq!(JsValue::from_str("string"), value.js_typeof());
        assert_eq!(value, JsValue::from_str(str));
        assert_eq!(a, from_value(value).unwrap());
    }

    #[wasm_bindgen_test]
    fn test_wasm_js_serde_object() {
        let expected = Address::constructor("kaspa:qpauqsvk7yf9unexwmxsnmg547mhyga37csh0kj53q6xxgl24ydxjsgzthw5j").unwrap();

        let obj = Object::new();
        obj.set("version", &JsValue::from_str("PubKey")).unwrap();
        obj.set("prefix", &JsValue::from_str("kaspa")).unwrap();
        obj.set("payload", &JsValue::from_str("qpauqsvk7yf9unexwmxsnmg547mhyga37csh0kj53q6xxgl24ydxjsgzthw5j")).unwrap();

        assert_eq!(JsValue::from_str("object"), obj.js_typeof());

        let obj_js = obj.into_js_result().unwrap();
        let actual = from_value(obj_js).unwrap();
        assert_eq!(expected, actual);
    }

    #[wasm_bindgen_test]
    fn test_wasm_serde_object() {
        let expected = Address::constructor("kaspa:qpauqsvk7yf9unexwmxsnmg547mhyga37csh0kj53q6xxgl24ydxjsgzthw5j").unwrap();
        let wasm_js_value: JsValue = expected.clone().into_abi().into();

        let actual = from_value(wasm_js_value).unwrap();
        assert_eq!(expected, actual);
    }

    #[wasm_bindgen_test]
    fn set_prefix_rejects_stealth_prefix_on_non_stealth_address() {
        let mut addr =
            Address::constructor("kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx9awp4e").expect("valid address");
        let original = addr.prefix;
        let err = addr.set_prefix_from_str("qs").expect_err("must reject stealth prefix for non-stealth version");
        assert!(err.as_string().unwrap_or_default().to_lowercase().contains("stealth"));
        assert_eq!(addr.prefix, original);
    }

    #[wasm_bindgen_test]
    fn set_prefix_rejects_regular_prefix_on_stealth_address() {
        let mut addr = Address::new(Prefix::StealthTestnet, Version::Stealth, &[7u8; 64]);
        let original = addr.prefix;
        let err = addr.set_prefix_from_str("kaspa").expect_err("must reject regular prefix for stealth version");
        assert!(err.as_string().unwrap_or_default().to_lowercase().contains("stealth"));
        assert_eq!(addr.prefix, original);
    }

    #[wasm_bindgen_test]
    fn set_prefix_allows_regular_to_regular() {
        let mut addr =
            Address::constructor("kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx9awp4e").expect("valid address");
        addr.set_prefix_from_str("kaspatest").expect("regular prefix change should succeed");
        assert_eq!(addr.prefix, Prefix::Testnet);
        assert_eq!(addr.version, Version::PubKey);
    }

    #[wasm_bindgen_test]
    fn set_prefix_allows_stealth_to_stealth() {
        let mut addr = Address::new(Prefix::StealthMainnet, Version::Stealth, &[9u8; 64]);
        addr.set_prefix_from_str("qstest").expect("stealth prefix change should succeed");
        assert_eq!(addr.prefix, Prefix::StealthTestnet);
        assert_eq!(addr.version, Version::Stealth);
    }
}
