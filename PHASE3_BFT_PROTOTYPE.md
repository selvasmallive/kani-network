# KANI Phase 3 BFT Prototype

Status: implementation slice ready
Release candidate: `phase3-bft-prototype-rc1`
Date: 2026-05-09
Scope: sandbox-only BFT message model and deterministic consensus tests

This slice keeps the existing sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

It does not create GKE resources, validator network transport, production ingress, HSM-backed signing, or real-value settlement capability.

## Implemented Prototype

`kani-consensus` now includes `BftConsensus` behind the explicit config engine id `sandbox-bft-prototype`.

The default node and validator runtime still use `phase1-poa`. The BFT prototype is opt-in through `ConsensusEngineConfig::sandbox_bft_prototype()` and is currently exercised by tests only.

Implemented sandbox BFT objects:

- `ConsensusProposal`
- `ConsensusVote` with `PREVOTE` and `PRECOMMIT`
- `QuorumCertificate`
- `FinalityProof`
- `ValidatorSet`

The prototype simulates one height and one round at a time. It uses strict greater-than-two-thirds finality for the sandbox validator set, so 3 active validators require 3 precommits.

## Safety Boundary

The prototype is a local message/proof model, not a production BFT implementation.

Explicitly deferred:

- validator peer-to-peer networking
- mempool gossip
- timeout/round-change handling
- equivocation evidence persistence
- slashing or enforcement
- HSM/KMS signing
- GKE validator operations
- production finality claims

Current validator behavior remains Phase 1 PoA.

## Acceptance Evidence

The slice is accepted when these checks pass:

```powershell
cargo fmt --check
cargo clippy --workspace -- -D warnings
cargo test --workspace -j 1
powershell -ExecutionPolicy Bypass -File .\scripts\phase3-validate.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase2-validate.ps1
```
