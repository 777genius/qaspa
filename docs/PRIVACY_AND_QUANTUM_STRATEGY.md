# Privacy & Quantum Resistance Strategy

## Overview
Our goal is to build a high-performance DAG (based on Kaspa) that offers **Quantum Resistance** and **Privacy by Default**, without sacrificing the high TPS and low latency characteristics of the protocol.

### MLDSA master plan reference
- Detailed plan for Phase 2 (master key, anchor, delegation): `docs/plans/phase2/Phase2_MLDSA_master_key.md`.
- Wallet flag `enable_mldsa_master` (see `wallet/core/src/settings.rs`) controls auto-derivation/storage of the MLDSA master; default is `true`, can be disabled in test/dev.
- **Статус Iteration 8:** активация мастер-рута управляется консенсусным флагом `mldsa_master_activation` (dev/sim/test/mainnet включены); RPC `GetServerInfo` сообщает `mldsa_master_enabled` и `mldsa_master_activation_daa` (для `always` это `0`), кошелёк отражает сетевой статус и предупреждает о расхождениях.

## The "Smart" Architecture: Hybrid Approach

Instead of using heavy Post-Quantum (PQ) signatures for every transaction (which would kill throughput), we adopt a tiered key management and privacy approach.

### 1. Quantum Resistance: The "Master & Commander" Model
**Problem:** Pure Post-Quantum signatures (like MLDSA/Dilithium) are large (~2.5KB - 5KB). Using them for every transaction reduces TPS by 10-20x and bloats the chain.
**Solution:** **Hierarchical Deterministic PQ + Ephemeral Keys.**

*   **Master Key (Root of Trust):** Users generate a cold MLDSA (Dilithium) keypair. This is their long-term identity/vault.
*   **Ephemeral Keys (Daily Driver):** The Master Key is used *only* to authorize/delegate permissions to lightweight, standard ECC keys (Schnorr/Ed25519).
    *   Or, even better: **One-Time Keys (Stealth Addresses)** are derived mathematically. The Master Key is never exposed to the network for daily spending.
*   **Forward Secrecy:** Since keys are one-time (or short-lived), even if a Quantum Computer breaks the current ephemeral key, past transactions remain secure, and the Master Key remains hidden (hashed).

### 2. Receiver Privacy: Stealth Addresses
**Goal:** Hide *who* is receiving money.
**Mechanism:**
*   Sender uses the Recipient's Public Master Key to generate a unique, random one-time address (`P_temp`) for the transaction.
*   To the outside world, `P_temp` looks like random noise. Only the Recipient can mathematically derive the private key for `P_temp` and spend the funds.
*   **Benefit:** Complete unlinkability of addresses. A user has one public ID, but millions of unlinked addresses on-chain.

### 3. Mobile Performance: View Tags
**Problem:** With Stealth Addresses, a wallet doesn't know which transactions belong to it. It must try to decrypt *every* transaction in a block, which drains mobile battery.
**Solution:** **View Tags (1 byte).**
*   Sender calculates a shared secret `S` and adds `Tag = Hash(S)[0]` to the transaction.
*   Recipient's phone calculates the expected Tag. If it doesn't match the transaction's Tag, it skips it immediately.
*   **Result:** Reduces CPU load by ~256x, making mobile syncing fast again.

## Roadmap to "Monero-Level" Privacy (Future)
To achieve full anonymity (hiding Sender and Amounts), we plan to implement:

1.  **Sender Anonymity:** **Curve Trees** (Next-gen replacement for Ring Signatures).
    *   Allows proving membership in the set of all UTXOs without revealing which one is being spent.
    *   Unlike Ring Signatures, scales with log(N) and supports efficient pruning.
2.  **Amount Privacy:** **Confidential Transactions (Bulletproofs++ / BP++)**.
    *   Hides transaction amounts using Pedersen Commitments and Range Proofs.
3.  **Performance Optimization:** **Batch Verification**.
    *   Verifying proofs in parallel (batches of 100-1000) to keep DAG sync speed high.

