use rand::Rng;

pub(crate) struct _CoinFlip {
    _p: f64,
}

impl Default for _CoinFlip {
    fn default() -> Self {
        Self { _p: 1.0 / 200.0 }
    }
}

impl _CoinFlip {
    pub(crate) fn _new(p: f64) -> Self {
        Self { _p: p }
    }

    pub fn _flip(self) -> bool {
        rand::thread_rng().gen_bool(self._p)
    }
}
