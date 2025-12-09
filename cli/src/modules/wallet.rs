use crate::imports::*;
use crate::wizards;
use kaspa_utils::hex::ToHex;
use kaspa_wallet_core::api::message::{MasterDelegationApplyRequest, MasterDelegationSignRequest};
use kaspa_wallet_core::message::{MasterDelegationRequestBodyV1, MasterDelegationResponseBodyV1};
use kaspa_wallet_core::storage::PrvKeyDataId;
#[cfg(not(target_arch = "wasm32"))]
use qrcode::{render::unicode, QrCode};
use serde_json::json;
use std::str::FromStr;
use zeroize::Zeroize;

#[derive(Default, Handler)]
#[help("Wallet management operations")]
pub struct Wallet;

impl Wallet {
    async fn main(self: Arc<Self>, ctx: &Arc<dyn Context>, mut argv: Vec<String>, cmd: &str) -> Result<()> {
        let ctx = ctx.clone().downcast_arc::<KaspaCli>()?;

        let guard = ctx.wallet().guard();
        let guard = guard.lock().await;

        if argv.is_empty() {
            return self.display_help(ctx, argv).await;
        }

        let op = argv.remove(0);
        match op.as_str() {
            "list" => {
                let wallets = ctx.store().wallet_list().await?;
                if wallets.is_empty() {
                    tprintln!(ctx, "No wallets found");
                } else {
                    tprintln!(ctx, "");
                    tprintln!(ctx, "Wallets:");
                    tprintln!(ctx, "");
                    for wallet in wallets {
                        if let Some(title) = wallet.title {
                            tprintln!(ctx, "  {}: {}", wallet.filename, title);
                        } else {
                            tprintln!(ctx, "  {}", wallet.filename);
                        }
                    }
                    tprintln!(ctx, "");
                }
            }
            "create" | "import" => {
                let wallet_name = if argv.is_empty() {
                    None
                } else {
                    let name = argv.remove(0);
                    let name = name.trim().to_string();
                    let name_check = name.to_lowercase();
                    if name_check.as_str() == "wallet" {
                        return Err(Error::custom("Wallet name cannot be 'wallet'"));
                    }
                    Some(name)
                };

                let wallet_name = wallet_name.as_deref();
                let import_with_mnemonic = op.as_str() == "import";
                wizards::wallet::create(&ctx, guard.into(), wallet_name, import_with_mnemonic).await?;
            }
            "open" => {
                let name = if let Some(name) = argv.first().cloned() {
                    let name_check = name.to_lowercase();

                    if name_check.as_str() == "wallet" {
                        tprintln!(ctx, "you can not have a wallet named 'wallet'...");
                        tprintln!(ctx, "perhaps you are looking to use 'open <name>'");
                        return Ok(());
                    }
                    Some(name)
                } else {
                    ctx.wallet().settings().get(WalletSettings::Wallet).clone()
                };

                let (wallet_secret, _) = ctx.ask_wallet_secret(None).await?;
                let _ = ctx.notifier().show(Notification::Processing).await;
                let args = WalletOpenArgs::default_with_legacy_accounts();
                ctx.wallet().open(&wallet_secret, name, args, &guard).await?;
                ctx.wallet().activate_accounts(None, &guard).await?;
            }
            "close" => {
                ctx.wallet().close().await?;
            }
            "hint" => {
                if !argv.is_empty() {
                    let re = regex::Regex::new(r"wallet\s+hint\s+").unwrap();
                    let hint = re.replace(cmd, "");
                    let hint = hint.trim();
                    let store = ctx.store();
                    if hint == "remove" {
                        tprintln!(ctx, "Hint is empty - removing wallet hint");
                        store.set_user_hint(None).await?;
                    } else {
                        store.set_user_hint(Some(hint.into())).await?;
                    }
                } else {
                    tprintln!(ctx, "usage:\n'wallet hint <text>' or 'wallet hint remove' to remove the hint");
                }
            }
            "master" => {
                self.master_command(ctx.clone(), argv).await?;
            }
            v => {
                tprintln!(ctx, "unknown command: '{v}'");
                return self.display_help(ctx, argv).await;
            }
        }

        Ok(())
    }

    async fn display_help(self: Arc<Self>, ctx: Arc<KaspaCli>, _argv: Vec<String>) -> Result<()> {
        ctx.term().help(
            &[
                ("list", "List available local wallet files"),
                ("create [<name>]", "Create a new bip32 wallet"),
                (
                    "import [<name>]",
                    "Create a wallet from an existing mnemonic (bip32 only). \r\n\r\n\
                To import legacy wallets (KDX or kaspanet) please create \
                a new bip32 wallet and use the 'account import' command. \
                Legacy wallets can only be imported as accounts. \
                \r\n",
                ),
                ("open [<name>]", "Open an existing wallet (shorthand: 'open [<name>]')"),
                ("close", "Close an opened wallet (shorthand: 'close')"),
                ("hint", "Change the wallet phishing hint"),
            ],
            None,
        )?;

        Ok(())
    }

    async fn master_command(self: Arc<Self>, ctx: Arc<KaspaCli>, mut argv: Vec<String>) -> Result<()> {
        if argv.is_empty() {
            return self.display_master_help(ctx).await;
        }

        let op = argv.remove(0);
        match op.as_str() {
            "list" => self.master_list(ctx).await,
            "export" => self.master_export(ctx, argv).await,
            "verify-anchor" => {
                let anchor = argv.into_iter().next();
                self.master_verify_anchor(ctx, anchor).await
            }
            "sign-delegation" => self.master_sign_delegation(ctx, argv).await,
            "apply-delegation" => self.master_apply_delegation(ctx, argv).await,
            "enable" => self.set_master_flag(ctx, true).await,
            "disable" => self.set_master_flag(ctx, false).await,
            "help" => self.display_master_help(ctx).await,
            unknown => Err(Error::custom(format!("Unknown master command '{unknown}'"))),
        }
    }

    async fn master_list(self: Arc<Self>, ctx: Arc<KaspaCli>) -> Result<()> {
        Self::ensure_wallet_open(&ctx)?;
        let anchors = ctx.wallet().master_anchor_infos().await?;
        let master_enabled = Self::is_master_enabled(&ctx);

        if anchors.is_empty() {
            tprintln!(ctx, "MLDSA master anchors are not present in this wallet.");
            if !master_enabled {
                tprintln!(ctx, "Automatic derivation is disabled. Use 'wallet master enable' to turn it on.");
            }
            return Ok(());
        }

        struct Row {
            id: String,
            anchor: String,
            level: String,
            cipher: String,
        }

        let rows: Vec<Row> = anchors
            .into_iter()
            .map(|info| Row {
                id: info.id.to_string(),
                anchor: info.anchor.unwrap_or_else(|| "-".to_string()),
                level: info.level.map(|level| format!("L{level}")).unwrap_or_else(|| "-".to_string()),
                cipher: if info.is_encrypted { "encrypted".to_string() } else { "plain".to_string() },
            })
            .collect();

        let max_id = rows.iter().map(|row| row.id.len()).max().unwrap_or(2).max(2);
        let max_anchor = rows.iter().map(|row| row.anchor.len()).max().unwrap_or(6).max(6);
        let max_level = rows.iter().map(|row| row.level.len()).max().unwrap_or(5).max(5);
        let max_cipher = rows.iter().map(|row| row.cipher.len()).max().unwrap_or(6).max(6);

        tprintln!(ctx, "");
        tprintln!(
            ctx,
            "{}  {}  {}  {}",
            "ID".pad_to_width(max_id),
            "Anchor".pad_to_width(max_anchor),
            "Level".pad_to_width(max_level),
            "Cipher".pad_to_width(max_cipher)
        );
        tprintln!(ctx, "{}", "-".repeat(max_id + max_anchor + max_level + max_cipher + 6));

        for row in rows {
            tprintln!(
                ctx,
                "{}  {}  {}  {}",
                row.id.pad_to_width(max_id),
                row.anchor.pad_to_width(max_anchor),
                row.level.pad_to_width(max_level),
                row.cipher.pad_to_width(max_cipher)
            );
        }
        tprintln!(ctx, "");

        if !master_enabled {
            tprintln!(ctx, "Note: derivation flag is disabled; new wallets will not auto-create masters.");
        }

        Ok(())
    }

    async fn master_export(self: Arc<Self>, ctx: Arc<KaspaCli>, mut argv: Vec<String>) -> Result<()> {
        Self::ensure_wallet_open(&ctx)?;
        if argv.is_empty() {
            return Err(Error::custom("Usage: wallet master export <master-id> [--format plain|json|qr]"));
        }

        let master_id_hex = argv.remove(0);
        let master_id = PrvKeyDataId::from_hex(&master_id_hex)?;

        let mut format = MasterExportFormat::Plain;
        let mut idx = 0;
        while idx < argv.len() {
            let arg = argv[idx].as_str();
            if let Some(value) = arg.strip_prefix("--format=") {
                format = value.parse()?;
                idx += 1;
                continue;
            }
            match arg {
                "--format" => {
                    let value = argv.get(idx + 1).ok_or_else(|| Error::custom("--format expects a value (plain|json|qr)"))?;
                    format = value.parse()?;
                    idx += 2;
                    continue;
                }
                unknown => {
                    return Err(Error::UnrecognizedArgument(unknown.to_string(), "--format".to_string()));
                }
            }
        }

        let (wallet_secret, _) = ctx.ask_wallet_secret(None).await?;
        let confirmation = ctx.term().ask(false, "Type 'EXPORT' to confirm master seed export: ").await?;
        let mut seed_hex = ctx.wallet().export_master_seed_hex(&wallet_secret, &master_id, confirmation.trim()).await?;

        match format {
            MasterExportFormat::Plain => {
                tprintln!(ctx, "\nMaster {master_id_hex} seed (hex):\n");
                for chunk in seed_hex.as_bytes().chunks(64) {
                    if let Ok(line) = std::str::from_utf8(chunk) {
                        tprintln!(ctx, "  {line}");
                    }
                }
                tprintln!(ctx, "\nStore this seed offline. Anyone with this value can derive all MLDSA keys.");
            }
            MasterExportFormat::Json => {
                let payload = json!({
                    "masterId": master_id_hex,
                    "seedHex": seed_hex,
                });
                tprintln!(ctx, "\n{}\n", serde_json::to_string_pretty(&payload)?);
            }
            MasterExportFormat::Qr => {
                #[cfg(not(target_arch = "wasm32"))]
                {
                    let payload = json!({
                        "masterId": master_id_hex,
                        "seedHex": seed_hex,
                    })
                    .to_string();
                    let code = QrCode::new(payload.as_bytes()).map_err(|err| Error::custom(err.to_string()))?;
                    let image = code.render::<unicode::Dense1x2>().quiet_zone(true).build();
                    tprintln!(ctx, "\n{image}\n");
                }
                #[cfg(target_arch = "wasm32")]
                {
                    seed_hex.zeroize();
                    return Err(Error::custom("QR export is not available in wasm builds"));
                }
            }
        }

        seed_hex.zeroize();
        Ok(())
    }

    async fn master_verify_anchor(self: Arc<Self>, ctx: Arc<KaspaCli>, anchor: Option<String>) -> Result<()> {
        Self::ensure_wallet_open(&ctx)?;
        let Some(anchor) = anchor else {
            return Err(Error::custom("Usage: wallet master verify-anchor <anchor-hex>"));
        };
        let normalized = anchor.trim().trim_start_matches("0x").to_ascii_lowercase();

        let anchors = ctx.wallet().master_anchor_infos().await?;
        if let Some(info) =
            anchors.iter().find(|info| info.anchor.as_ref().map(|value| value.eq_ignore_ascii_case(&normalized)).unwrap_or(false))
        {
            tprintln!(ctx, "Anchor {normalized} belongs to master {}", info.id);
        } else {
            tprintln!(ctx, "Anchor {normalized} is not present in this wallet.");
        }
        Ok(())
    }

    async fn set_master_flag(self: Arc<Self>, ctx: Arc<KaspaCli>, enabled: bool) -> Result<()> {
        ctx.wallet().settings().set(WalletSettings::EnableMldsaMaster, enabled).await?;
        ctx.wallet().settings().try_store().await?;
        let state = if enabled { "enabled" } else { "disabled" };
        tprintln!(ctx, "Automatic MLDSA master derivation is {state}.");
        Ok(())
    }

    async fn display_master_help(self: Arc<Self>, ctx: Arc<KaspaCli>) -> Result<()> {
        ctx.term().help(
            &[
                ("list", "List stored MLDSA master anchors"),
                ("export <id> [--format plain|json|qr]", "Export encrypted master seed"),
                ("verify-anchor <hex>", "Check whether anchor exists locally"),
                (
                    "sign-delegation --input <path|-> --out <path|-> [--force-network-mismatch] [--summary-only] [--no-confirm]",
                    "Sign offline delegation request JSON",
                ),
                (
                    "apply-delegation [--request <path>] --response <path> [--force-network-mismatch]",
                    "Apply signed delegation response JSON (request optional if cached)",
                ),
                ("enable|disable", "Toggle automatic master creation"),
            ],
            Some("master"),
        )?;
        Ok(())
    }

    async fn master_sign_delegation(self: Arc<Self>, ctx: Arc<KaspaCli>, argv: Vec<String>) -> Result<()> {
        Self::ensure_wallet_open(&ctx)?;
        if argv.is_empty() {
            tprintln!(
                ctx,
                "Usage: wallet master sign-delegation --input <path|-> --out <path|-> [--force-network-mismatch] [--summary-only] [--no-confirm]"
            );
            return Ok(());
        }

        let mut input: Option<String> = None;
        let mut output: Option<String> = None;
        let mut force_network_mismatch = false;
        let mut summary_only = false;
        let mut no_confirm = false;
        let mut idx = 0;
        while idx < argv.len() {
            match argv[idx].as_str() {
                "--input" => {
                    input = argv.get(idx + 1).cloned();
                    idx += 2;
                }
                "--out" => {
                    output = argv.get(idx + 1).cloned();
                    idx += 2;
                }
                "--force-network-mismatch" => {
                    force_network_mismatch = true;
                    idx += 1;
                }
                "--summary-only" => {
                    summary_only = true;
                    idx += 1;
                }
                "--no-confirm" => {
                    no_confirm = true;
                    idx += 1;
                }
                other => return Err(Error::custom(format!("Unknown argument {other}"))),
            }
        }

        let (wallet_secret, _) = ctx.ask_wallet_secret(None).await?;
        let json = if input.as_deref() == Some("-") {
            use std::io::Read;
            let mut buf = String::new();
            std::io::stdin().read_to_string(&mut buf)?;
            buf
        } else {
            let path = input.ok_or_else(|| Error::custom("missing --input"))?;
            std::fs::read_to_string(&path)?
        };

        let request: MasterDelegationRequestBodyV1 =
            serde_json::from_str(&json).map_err(|e| Error::custom(format!("invalid request json: {e}")))?;

        if !no_confirm {
            print_delegation_summary(&ctx, &request, "Request");
            let anchor_hex = request.master_anchor.to_vec().to_hex();
            let request_hex = request.request_id.to_vec().to_hex();
            let anchor_short = anchor_hex.get(0..12).unwrap_or(&anchor_hex);
            let request_short = request_hex.get(0..12).unwrap_or(&request_hex);
            let prompt =
                format!("Type 'DELEGATE' to sign (anchor {anchor_short}, request {request_short}) or anything else to abort: ");
            let answer = ctx.term().ask(false, &prompt).await?;
            if answer.trim() != "DELEGATE" {
                tprintln!(ctx, "Aborted by user.");
                return Ok(());
            }
        }

        let response = ctx
            .wallet()
            .master_delegation_sign_call(MasterDelegationSignRequest {
                wallet_secret,
                request: request.clone(),
                force_network_mismatch,
            })
            .await?;

        let out_json = response.response_json;
        if !summary_only && (output.as_deref() == Some("-") || output.is_none()) {
            tprintln!(ctx, "{out_json}");
        } else if let Some(path) = output {
            std::fs::write(path, out_json)?;
        }

        print_delegation_summary(&ctx, &request, "Request");
        tprintln!(
            ctx,
            "Signed delegations: {} | anchor: {} | requestId: {}",
            response.response.delegations.len(),
            response.response.master_anchor.to_vec().to_hex(),
            response.response.request_id.to_vec().to_hex()
        );
        Ok(())
    }

    async fn master_apply_delegation(self: Arc<Self>, ctx: Arc<KaspaCli>, argv: Vec<String>) -> Result<()> {
        Self::ensure_wallet_open(&ctx)?;
        if argv.is_empty() {
            tprintln!(ctx, "Usage: wallet master apply-delegation [--request <path>] --response <path> [--force-network-mismatch]");
            return Ok(());
        }

        let mut request_path: Option<String> = None;
        let mut response_path: Option<String> = None;
        let mut force_network_mismatch = false;
        let mut idx = 0;
        while idx < argv.len() {
            match argv[idx].as_str() {
                "--request" => {
                    request_path = argv.get(idx + 1).cloned();
                    idx += 2;
                }
                "--response" => {
                    response_path = argv.get(idx + 1).cloned();
                    idx += 2;
                }
                "--force-network-mismatch" => {
                    force_network_mismatch = true;
                    idx += 1;
                }
                other => return Err(Error::custom(format!("Unknown argument {other}"))),
            }
        }

        let response_json = std::fs::read_to_string(response_path.ok_or_else(|| Error::custom("missing --response"))?)?;
        let response: MasterDelegationResponseBodyV1 =
            serde_json::from_str(&response_json).map_err(|e| Error::custom(format!("invalid response json: {e}")))?;

        let request = if let Some(path) = request_path {
            let request_json = std::fs::read_to_string(path)?;
            Some(serde_json::from_str(&request_json).map_err(|e| Error::custom(format!("invalid request json: {e}")))?)
        } else {
            ctx.wallet().load_cached_master_delegation_request(&response.request_id).await?
        };

        let request =
            request.ok_or_else(|| Error::custom("missing --request and cached delegation_request.json not found for requestId"))?;

        let (wallet_secret, _) = ctx.ask_wallet_secret(None).await?;
        let result = ctx
            .wallet()
            .master_delegation_apply_call(MasterDelegationApplyRequest { wallet_secret, request, response, force_network_mismatch })
            .await?;

        tprintln!(ctx, "Applied: {}, skipped: {}", result.applied, result.skipped);
        if !result.missing_accounts.is_empty() {
            let missing = result.missing_accounts.iter().map(|id| id.to_string()).collect::<Vec<_>>().join(", ");
            tprintln!(ctx, "Missing accounts: {missing}");
        }
        Ok(())
    }

    fn ensure_wallet_open(ctx: &Arc<KaspaCli>) -> Result<()> {
        if ctx.wallet().is_open() {
            Ok(())
        } else {
            Err(Error::WalletIsNotOpen)
        }
    }

    fn is_master_enabled(ctx: &Arc<KaspaCli>) -> bool {
        ctx.wallet().settings().get::<bool>(WalletSettings::EnableMldsaMaster).unwrap_or(true)
    }
}

fn print_delegation_summary(ctx: &Arc<KaspaCli>, request: &MasterDelegationRequestBodyV1, label: &str) {
    if request.delegations.is_empty() {
        tprintln!(ctx, "{label} summary → no delegations in request");
        return;
    }
    let min_from = request.delegations.iter().map(|d| d.valid_from_daa).min().unwrap_or(0);
    let max_until = request.delegations.iter().filter_map(|d| d.valid_until_daa).max();
    let window = match max_until {
        Some(until) => format!("{min_from}..{until}"),
        None => format!("{min_from}..(open)"),
    };
    tprintln!(
        ctx,
        "{label} summary → delegations: {} | DAA window: {} | network: {} | requestId: {}",
        request.delegations.len(),
        window,
        request.network_id,
        request.request_id.to_vec().to_hex()
    );
}

enum MasterExportFormat {
    Plain,
    Json,
    Qr,
}

impl FromStr for MasterExportFormat {
    type Err = Error;

    fn from_str(input: &str) -> Result<Self> {
        match input.to_ascii_lowercase().as_str() {
            "plain" => Ok(Self::Plain),
            "json" => Ok(Self::Json),
            "qr" => Ok(Self::Qr),
            _ => Err(Error::custom("Format must be one of plain|json|qr")),
        }
    }
}
