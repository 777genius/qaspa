use crate::imports::*;
use kaspa_wallet_core::metrics::MasterMetrics;

#[derive(Default, Handler)]
#[help("Wallet health check operations")]
pub struct Health;

impl Health {
    async fn main(self: Arc<Self>, ctx: &Arc<dyn Context>, mut argv: Vec<String>, _cmd: &str) -> Result<()> {
        let ctx = ctx.clone().downcast_arc::<KaspaCli>()?;

        if argv.is_empty() {
            return self.display_help(ctx).await;
        }

        let mode_arg = argv.remove(0);
        let mode = if mode_arg.starts_with("--mode=") {
            mode_arg.trim_start_matches("--mode=").to_string()
        } else if mode_arg == "--mode" {
            argv.first().cloned().unwrap_or_default()
        } else {
            mode_arg
        };

        match mode.as_str() {
            "airgap" => self.check_airgap(ctx).await,
            _ => {
                tprintln!(ctx, "Unknown health check mode: {}", mode);
                self.display_help(ctx).await
            }
        }
    }

    async fn check_airgap(self: Arc<Self>, ctx: Arc<KaspaCli>) -> Result<()> {
        let wallet = ctx.wallet();

        if !wallet.is_open() {
            MasterMetrics::global().inc_healthcheck_failures();
            return Err(Error::custom("Wallet is not open"));
        }

        let store = ctx.store();
        if store.location().is_err() {
            MasterMetrics::global().inc_healthcheck_failures();
            return Err(Error::custom("Wallet storage location is not accessible"));
        }

        let settings = wallet.settings();
        let enable_mldsa_master = settings.get::<bool>(WalletSettings::EnableMldsaMaster).unwrap_or(true);
        if !enable_mldsa_master {
            MasterMetrics::global().inc_healthcheck_failures();
            return Err(Error::custom("MLDSA master is not enabled (ENABLE_MLDSA_MASTER=0)"));
        }

        let masters = wallet.list_master_accounts().await?;
        if masters.is_empty() {
            MasterMetrics::global().inc_healthcheck_failures();
            return Err(Error::custom("No MLDSA master accounts found"));
        }

        let utxo_processor = wallet.utxo_processor();
        if !utxo_processor.is_connected() {
            MasterMetrics::global().inc_healthcheck_failures();
            return Err(Error::custom("UTXO processor is not connected"));
        }

        tprintln!(ctx, "Health check passed: airgap mode");
        Ok(())
    }

    async fn display_help(self: Arc<Self>, ctx: Arc<KaspaCli>) -> Result<()> {
        ctx.term().help(
            &[
                ("airgap", "Check wallet health for airgap operations (MLDSA master, storage, RPC)"),
                ("--mode=airgap", "Alias for airgap mode"),
            ],
            None,
        )?;
        Ok(())
    }
}
