use crate::events::Events;
use crate::imports::*;
use crate::metrics::MasterMetrics;
use crate::settings::WalletSettings;
use crate::wallet::Wallet;
use kaspa_wallet_keys::keypair_mldsa::MasterAnchor;

pub struct DelegationExpiryWatcher {
    wallet: Arc<Wallet>,
}

impl DelegationExpiryWatcher {
    pub fn new(wallet: Arc<Wallet>) -> Self {
        Self { wallet }
    }

    pub async fn on_daa_score_change(&self, current_daa_score: u64) -> Result<()> {
        let warn_window = self
            .wallet
            .settings()
            .get::<u64>(WalletSettings::DelegationWarnWindowDaa)
            .unwrap_or(1_000);

        for (id, rec) in self.wallet.delegation_store().active_records() {
            if let Some(until) = rec.valid_until_daa {
                if current_daa_score >= until {
                    continue;
                }

                if current_daa_score + warn_window >= until && !rec.warned_recently(current_daa_score, warn_window) {
                    self.wallet.delegation_store().mark_warned_at(id, current_daa_score);
                    let _ = self
                        .wallet
                        .notify(Events::MasterDelegationExpiringSoon {
                            account_id: rec.account_id,
                            delegation_id: id.0,
                            anchor: rec.anchor,
                            valid_until_daa: until,
                            current_daa_score,
                            warn_window_daa: warn_window,
                        })
                        .await;
                    MasterMetrics::global().inc_delegations_expiring_soon();
                    log_warn!(
                        "Master delegation expiring soon: master_anchor={} delegation_id={} valid_until_daa={} current_daa_score={} warn_window_daa={}",
                        crate::account::variants::mldsa_master::format_master_anchor_short(&MasterAnchor::new(rec.anchor)),
                        id.0,
                        until,
                        current_daa_score,
                        warn_window
                    );
                }
            }
        }
        Ok(())
    }
}
