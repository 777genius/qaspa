# Privacy & Quantum Resistance Strategy

## Overview
Our goal is to build a high-performance DAG (based on Kaspa) that offers **Quantum Resistance** and **Full Privacy by Default** (Monero-level), without sacrificing the high TPS and low latency characteristics of the protocol. We aim to achieve this through a "Speedrun" development strategy leveraging AI-assisted coding and rigorous property-based testing.

### MLDSA master plan reference
- Детализированный план Phase 2 (master key, anchor, делегации): `docs/plans/phase2/Phase2_MLDSA_master_key.md`.
- Флаг кошелька `enable_mldsa_master` (см. `wallet/core/src/settings.rs`) по умолчанию `true`, отвечает за автоматическое создание и хранение MLDSA master seed/anchor; может быть выключен в тестовых окружениях.

## The "Smart" Architecture: Hybrid Approach

Instead of using heavy Post-Quantum (PQ) signatures for every transaction (which would kill throughput), we adopt a tiered key management and privacy approach.

### 1. Quantum Resistance: The "Master & Commander" Model
**Problem:** Pure Post-Quantum signatures (like MLDSA/Dilithium) are large (~2.5KB - 5KB). Using them for every transaction reduces TPS by 10-20x and bloats the chain.
**Solution:** **Hierarchical Deterministic PQ + Ephemeral Keys.**

*   **Master Key (Root of Trust):** Users generate a cold MLDSA (Dilithium) keypair. This is their long-term identity/vault. The Public Key is never exposed directly; only its Hash is used as an address anchor.
*   **Ephemeral Keys (Daily Driver):** The Master Key is used *only* as a mathematical base to derive **One-Time Keys (Stealth Addresses)**.
*   **Forward Secrecy:** Since keys are one-time, even if a Quantum Computer breaks the current ephemeral key (Schnorr), past transactions remain secure, and the Master Key remains hidden. This provides "Military-Grade" future-proofing without the performance penalty of full PQ-signatures on every tx.

### 2. Receiver Privacy: Stealth Addresses
**Goal:** Hide *who* is receiving money.
**Mechanism:**
*   Sender uses the Recipient's Public Master Key to generate a unique, random one-time address (`P_temp`) for the transaction via Diffie-Hellman Key Exchange (ECDH).
*   To the outside world, `P_temp` looks like random noise. Only the Recipient can mathematically derive the private key for `P_temp` and spend the funds.
*   **Benefit:** Complete unlinkability of addresses. A user has one public ID, but millions of unlinked addresses on-chain.

### 3. Mobile Performance: View Tags
**Problem:** With Stealth Addresses, a wallet doesn't know which transactions belong to it. It must try to decrypt *every* transaction in a block, which drains mobile battery.
**Solution:** **View Tags (1 byte).**
*   Sender calculates a shared secret `S` and adds `Tag = Hash(S)[0]` to the transaction.
*   Recipient's phone calculates the expected Tag. If it doesn't match the transaction's Tag, it skips it immediately.
*   **Result:** Reduces CPU load by ~256x, making mobile syncing fast again.

---

## The "Full Privacy" Stack (Speedrun Plan)

To achieve true "Monero 2.0" status (Hiding Sender + Hiding Amounts) while maintaining DAG speed, we will implement the following stack.

### Phase 1: Stealth Addresses (Privacy L1)
*   **Tech:** ECDH on `secp256k1` or `curve25519`.
*   **Implementation:**
    *   Update `ScriptPublicKey` to handle ephemeral keys.
    *   Implement scanning logic with View Tags in the Wallet core.
*   **AI Strategy:** Generate Property-Based tests to verify that only the intended recipient can derive the private key.
*   **Est. Time:** 1 week.

### Phase 2: Confidential Amounts (Privacy L2)
*   **Goal:** Hide the amount being transferred.
*   **Tech:** **Pedersen Commitments** + **Bulletproofs++**.
    *   Replace cleartext `u64` amounts in UTXO with encrypted commitments.
    *   Use Bulletproofs++ (BP++) for efficient Range Proofs (proving value is > 0 without revealing it).
*   **Why BP++?** It is significantly smaller and faster to verify than older Bulletproofs (Monero) or Borromean Ring Signatures.
*   **AI Strategy:** Use AI to write fuzzers that attempt to create "negative" amounts or inflate supply.
*   **Est. Time:** 2 weeks.

### Phase 3: Sender Anonymity (Privacy L3)
*   **Goal:** Hide *which* UTXO is being spent (break the link between input and output).
*   **Tech:** **Curve Trees**.
    *   A modern replacement for Ring Signatures (Monero).
    *   Proves membership in the global UTXO set without revealing the specific index.
*   **Why Curve Trees?**
    *   **Scalability:** Verification complexity is logarithmic `O(log N)`, whereas Ring Signatures are linear `O(N)`.
    *   **Pruning-Friendly:** Unlike Ring Signatures which require keeping old "decoys" forever, Curve Trees allow for efficient state management and pruning, essential for a high-speed DAG.
*   **Est. Time:** 3-4 weeks.

### Phase 4: Performance & Scaling (The "Secret Sauce")
*   **Goal:** Handle the increased transaction weight (~2.5KB vs 0.3KB) and verification load.
*   **Tech:** **Batch Verification**.
    *   Instead of verifying transactions one-by-one, nodes verify them in batches of 100-1000.
    *   Curve Trees and BP++ support mathematical aggregation where checking `Sum(Proofs)` is faster than `Sum(Check(Proof))`.
*   **Network Scaling:**
    *   Increase Block Size / BPS limits to accommodate ~10MB/sec throughput.
    *   This enables **~4,000 Private TPS** (vs ~10 TPS in Monero).
    *   Relies on the robust P2P layer of Kaspa to handle orphan blocks via GhostDAG.

## Development Methodology: AI-Assisted Speedrun
We leverage a "Senior Engineer + AI" loop:
1.  **Code Generation:** AI writes the boilerplate, serialization, and standard crypto logic.
2.  **Fuzzing & Property Testing:** AI generates aggressive fuzzing suites (`proptest`) to hammer the crypto primitives with edge cases (invalid keys, overflows, malleability attacks).
3.  **AI Code Review:** We run multiple AI models (Claude 3.7, Gemini 1.5 Pro) as "Red Team" auditors to find logic flaws in the implementation.
4.  **Result:** High-velocity development with improved security assurance compared to manual coding alone.
