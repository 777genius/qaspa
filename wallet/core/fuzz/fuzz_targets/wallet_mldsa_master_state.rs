#![no_main]

use arbitrary::{Arbitrary, Unstructured};
use kaspa_mldsa::MlDsaLevel;
use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
use libfuzzer_sys::fuzz_target;
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
enum Status {
    #[default]
    Inactive,
    Active,
    Revoked,
}

#[derive(Debug, Clone, Copy)]
enum Command {
    Create(u8),
    Rotate,
    Revoke,
    AttachStealth(u64),
    DetachStealth(u64),
    Unlock,
    Lock,
}

impl Arbitrary<'_> for Command {
    fn arbitrary(u: &mut Unstructured<'_>) -> arbitrary::Result<Self> {
        let tag = u.int_in_range::<u8>(0..=6)?;
        Ok(match tag {
            0 => Command::Create(u.arbitrary()?),
            1 => Command::Rotate,
            2 => Command::Revoke,
            3 => Command::AttachStealth(u.arbitrary()?),
            4 => Command::DetachStealth(u.arbitrary()?),
            5 => Command::Unlock,
            _ => Command::Lock,
        })
    }
}

#[derive(Default)]
struct MasterMachine {
    status: Status,
    anchor: Option<[u8; 32]>,
    level: Option<MlDsaLevel>,
    locked: bool,
    rotations: u64,
    stealth_links: HashMap<u64, [u8; 32]>,
}

impl MasterMachine {
    fn choose_level(seed: u8) -> MlDsaLevel {
        match seed % 3 {
            0 => MlDsaLevel::Level2,
            1 => MlDsaLevel::Level3,
            _ => MlDsaLevel::Level5,
        }
    }

    fn new_anchor(level: MlDsaLevel) -> [u8; 32] {
        let pair = MlDsaKeypair::random(level);
        *pair.anchor().as_bytes()
    }

    fn apply(&mut self, cmd: Command) {
        let before_anchor = self.anchor;
        let before_status = self.status;

        match cmd {
            Command::Create(seed) => {
                let level = Self::choose_level(seed);
                self.anchor = Some(Self::new_anchor(level));
                self.level = Some(level);
                self.status = Status::Active;
                self.locked = false;
                self.rotations = 0;
                self.stealth_links.clear();
            }
            Command::Rotate => {
                if self.status == Status::Revoked {
                    return;
                }
                if let Some(level) = self.level {
                    let mut candidate = Self::new_anchor(level);
                    if Some(candidate) == self.anchor {
                        candidate = Self::new_anchor(level);
                    }
                    self.anchor = Some(candidate);
                    self.status = Status::Active;
                    self.locked = false;
                    self.rotations = self.rotations.saturating_add(1);
                }
            }
            Command::Revoke => {
                if self.anchor.is_some() {
                    self.status = Status::Revoked;
                    self.locked = true;
                }
            }
            Command::AttachStealth(id) => {
                if let Some(anchor) = self.anchor {
                    if let Some(existing) = self.stealth_links.get(&id) {
                        // Stealth account must not hop between anchors.
                        assert_eq!(existing, &anchor);
                    } else {
                        self.stealth_links.insert(id, anchor);
                    }
                }
            }
            Command::DetachStealth(id) => {
                self.stealth_links.remove(&id);
            }
            Command::Unlock => {
                if self.status != Status::Revoked {
                    self.locked = false;
                }
            }
            Command::Lock => {
                self.locked = true;
            }
        }

        // Invariants
        if self.status == Status::Revoked {
            assert!(self.locked, "revoked state must remain locked");
        }
        if before_status == Status::Revoked {
            assert_eq!(before_anchor, self.anchor, "revoked anchor cannot change");
        }
        if self.anchor != before_anchor {
            assert!(
                matches!(cmd, Command::Rotate | Command::Create(_)),
                "anchor changes only on create/rotate"
            );
        }
        if matches!(cmd, Command::Rotate) && before_anchor.is_some() {
            assert_ne!(before_anchor, self.anchor, "rotate must change anchor");
        }
        for (_id, linked_anchor) in self.stealth_links.iter() {
            if let Some(current_anchor) = self.anchor {
                // Stealth links must always point to the current anchor.
                assert_eq!(linked_anchor, &current_anchor);
            }
        }
    }
}

fuzz_target!(|data: &[u8]| {
    let mut u = Unstructured::new(data);
    if let Ok(mut commands) = Vec::<Command>::arbitrary(&mut u) {
        commands.truncate(64);
        let mut machine = MasterMachine::default();
        for cmd in commands {
            machine.apply(cmd);
        }
    }
});
