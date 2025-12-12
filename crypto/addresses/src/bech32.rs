use crate::{Address, AddressError, Prefix, Version};

const CHARSET: &[u8] = b"qpzry9x8gf2tvdw0s3jn54khce6mua7l";
const REV_CHARSET: [u8; 123] = [
    100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
    100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 15, 100, 10, 17, 21,
    20, 26, 30, 7, 5, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
    100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 29, 100, 24, 13, 25, 9, 8, 23, 100, 18, 22,
    31, 27, 19, 100, 1, 0, 3, 16, 11, 28, 12, 14, 6, 4, 2,
];

// Checksome for bech32
// https://bch.info/en/specifications
fn polymod<I>(values: I) -> u64
where
    I: Iterator<Item = u8>,
{
    let mut c = 1u64;
    for d in values {
        let c0 = c >> 35;
        c = ((c & 0x07ffffffff) << 5) ^ (d as u64);

        if c0 & 0x01 != 0 {
            c ^= 0x98f2bc8e61;
        }
        if c0 & 0x02 != 0 {
            c ^= 0x79b76d99e2;
        }
        if c0 & 0x04 != 0 {
            c ^= 0xf33e5fb3c4;
        }
        if c0 & 0x08 != 0 {
            c ^= 0xae2eabe2a8;
        }
        if c0 & 0x10 != 0 {
            c ^= 0x1e4f43e470;
        }
    }
    c ^ 1
}

fn checksum<I>(payload: &[u8], prefix: I) -> u64
where
    I: Iterator<Item = u8>,
{
    polymod(prefix.chain([0u8]).chain(payload.iter().copied()).chain([0u8; 8]))
}

// Convert 8bit array to 5bit array with right padding
fn conv8to5(payload: &[u8]) -> Vec<u8> {
    let padding = match payload.len() % 5 == 0 {
        true => 0,
        false => 1,
    };
    let mut five_bit = vec![0u8; payload.len() * 8 / 5 + padding];
    let mut current_idx = 0;

    let mut buff = 0u16;
    let mut bits = 0;
    for c in payload.iter() {
        buff = (buff << 8) | *c as u16;
        bits += 8;
        while bits >= 5 {
            bits -= 5;
            five_bit[current_idx] = (buff >> bits) as u8;
            buff &= (1 << bits) - 1;
            current_idx += 1;
        }
    }
    if bits > 0 {
        five_bit[current_idx] = (buff << (5 - bits)) as u8;
    }
    five_bit
}

// Convert 5 bit array to 8 bit array, ignore right side padding
fn conv5to8(payload: &[u8]) -> Vec<u8> {
    let mut eight_bit = vec![0u8; payload.len() * 5 / 8];
    let mut current_idx = 0;

    let mut buff = 0u16;
    let mut bits = 0;
    for c in payload.iter() {
        buff = (buff << 5) | *c as u16;
        bits += 5;
        while bits >= 8 {
            bits -= 8;
            eight_bit[current_idx] = (buff >> bits) as u8;
            buff &= (1 << bits) - 1;
            current_idx += 1;
        }
    }
    eight_bit
}

impl Address {
    pub(crate) fn encode_payload(&self) -> String {
        // Convert into 5 bits vector
        let fivebit_payload = conv8to5(&[[self.version as u8].as_slice(), self.payload.as_slice()].concat());
        let fivebit_prefix = self.prefix.as_str().as_bytes().iter().copied().map(|c| c & 0x1fu8);

        let checksum = checksum(fivebit_payload.as_slice(), fivebit_prefix);

        String::from_utf8(
            [fivebit_payload, conv8to5(&checksum.to_be_bytes()[3..])].concat().iter().map(|c| CHARSET[*c as usize]).collect(),
        )
        .expect("All character are valid utf-8")
    }

    pub(crate) fn decode_payload(prefix: Prefix, address: &str) -> Result<Self, AddressError> {
        // From letters to bytes
        let mut err = Ok(());
        let address_u5 = address
            .as_bytes()
            .iter()
            .scan(&mut err, |err, b| match *REV_CHARSET.get(*b as usize).unwrap_or(&100) {
                100 => {
                    **err = Err(AddressError::DecodingError(*b as char));
                    None
                }
                i => Some(i),
            })
            .collect::<Vec<u8>>();
        err?;
        if address_u5.len() < 8 {
            return Err(AddressError::BadPayload);
        }

        let payload_split_idx = address_u5.len().saturating_sub(8);
        let (payload_u5, checksum_u5) = address_u5.split_at(payload_split_idx);
        let fivebit_prefix = prefix.as_str().as_bytes().iter().copied().map(|c| c & 0x1fu8);

        // Convert to number
        let checksum_ =
            u64::from_be_bytes([vec![0u8; 3], conv5to8(checksum_u5)].concat().try_into().map_err(|_| AddressError::BadChecksumSize)?);

        if checksum(payload_u5, fivebit_prefix) != checksum_ {
            return Err(AddressError::BadChecksum);
        }

        let payload_u8 = conv5to8(payload_u5);
        let (version_byte, payload) = payload_u8.split_first().ok_or(AddressError::BadPayload)?;
        let version: Version = (*version_byte).try_into()?;

        // Address::new enforces payload length via assert (except for special test prefixes),
        // so validate here and return a proper error instead of panicking on malformed input.
        if (version == Version::PubKeyMLDSA || !prefix.is_test()) && payload.len() != version.public_key_len() {
            return Err(AddressError::BadPayload);
        }

        Ok(Self::new(prefix, version, payload))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decode_payload_rejects_checksum_only_string() {
        // Construct a bech32 payload string that contains ONLY the checksum for an empty payload.
        // Previously this could panic (payload_u8[0]) if checksum happened to match.
        let prefix = Prefix::Mainnet;
        let payload_u5: Vec<u8> = vec![];
        let fivebit_prefix = prefix.as_str().as_bytes().iter().copied().map(|c| c & 0x1fu8);
        let check = checksum(payload_u5.as_slice(), fivebit_prefix);
        let checksum_u5 = conv8to5(&check.to_be_bytes()[3..]);
        let address = String::from_utf8(checksum_u5.iter().map(|c| CHARSET[*c as usize]).collect()).unwrap();

        let decoded = Address::decode_payload(prefix, &address);
        assert_eq!(decoded, Err(AddressError::BadPayload));
    }
}
