# KANI Phase 3 Consensus Interface

Status: implementation slice ready
Release candidate: `phase3-consensus-interface-rc1`
Date: 2026-05-09
Scope: sandbox-only consensus engine abstraction and PoA adapter

This slice keeps the existing Phase 2/Phase 3 sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

It does not enable BFT production claims, GKE validator operations, production ingress, or real-value settlement.

## Implemented Interface

`kani-consensus` now exposes:

- `ConsensusEngine`: common interface for validator sets, leaders, finality thresholds, and finality voters.
- `ConsensusAlgorithm`: profile marker for `POA` and deferred `BFT`.
- `ConsensusEngineConfig`: config object that builds the selected engine.
- `ConfiguredConsensusEngine`: runtime wrapper for configured engines.
- `PoAConsensus`: Phase 1 PoA adapter implementing `ConsensusEngine`.

The default configured engine is `phase1-poa`, which preserves the existing 3-validator round-robin behavior and 2-of-3 finality.

## Shared Types

`kani-types` now has consensus-domain types for the later BFT slice:

- `ConsensusValidator`
- `ValidatorSet`
- `ConsensusProposal`
- `ConsensusVote`
- `ConsensusVoteKind`
- `QuorumCertificate`
- `FinalityProof`

These types are inert in this slice. They give the next BFT prototype a stable message/proof vocabulary without changing the current settlement path.

## Node Wiring

`kani-node` now stores a `ConfiguredConsensusEngine` and block construction/verification uses the `ConsensusEngine` trait boundary. The validator runtime still runs the same PoA flow, but the engine selection is now profile-driven instead of hardcoded at call sites.

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

## Deferred

- BFT consensus implementation.
- Network message transport.
- Equivocation evidence handling.
- Multi-node validator operations in GKE.
- Production finality or safety claims.
