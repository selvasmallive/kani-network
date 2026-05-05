# KANI Phase 2 Cloud MVP

Status: started
Scope: sandbox cloud deployment path

## Objective

Phase 2 moves the Phase 1 local MVP toward a Google Cloud sandbox:

- `kani-api` runs on Cloud Run.
- Three `kani-node` validators run on GKE.
- PostgreSQL ledger state moves to Cloud SQL.
- Container images are built into Artifact Registry.
- Secrets are held in Secret Manager.
- Audit/block archive storage is prepared in Cloud Storage.
- KMS key rings are provisioned for future production key work.

This phase still does not move real value.

## Non-Negotiable Runtime Boundary

Every Phase 2 sandbox workload must keep:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

Do not deploy a production value-moving environment from this branch.

## First Cloud MVP Topology

```text
Institution / operator
        |
        | future: API Gateway + mTLS + Cloud Armor
        v
Cloud Run: kani-api
        |
        | DATABASE_URL from Secret Manager
        v
Cloud SQL PostgreSQL
        ^
        |
GKE: validator-a, validator-b, validator-c
```

Supporting services:

- Artifact Registry for the shared `kani-api` / `kani-node` image.
- Cloud Storage bucket for future finalized block and audit archives.
- Cloud KMS key ring and key for future signing/HSM integration.
- Workload Identity ready service account boundary for validators.
- Cloud SQL connector/proxy path for Cloud Run and GKE validator database access.

## Included In This Starter

- Terraform skeleton in `infra/terraform`.
- Kubernetes validator manifests in `k8s`.
- Cloud Build container build config in `cloudbuild.yaml`.
- Cloud sandbox environment contract in `config/cloud-sandbox.yaml`.
- Static Phase 2 file validator in `scripts/phase2-validate.ps1`.

Run the static validator on Windows with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase2-validate.ps1
```

## Deployment Sequence

1. Create or select a sandbox Google Cloud project.
2. Configure billing and required IAM for the operator account.
3. Build and push the container image with Cloud Build.
4. Populate Terraform variables from `infra/terraform/terraform.tfvars.example`.
5. Run Terraform plan/apply for the sandbox cloud foundation.
6. Create the Kubernetes `kani-ledger-database` secret from `k8s/validator-secret.example.yaml`.
7. Replace placeholder image, Cloud SQL connection name, and Workload Identity values in the GKE manifests.
8. Apply the validator manifests to the GKE cluster.
9. Deploy `kani-api` to Cloud Run through Terraform.
10. Run Phase 1 smoke checks against the Cloud Run URL once network access is enabled.

## Phase 2 Acceptance Criteria

- Container image builds in Cloud Build and is available in Artifact Registry.
- Cloud SQL ledger instance exists for sandbox use.
- Cloud Run `kani-api` starts with sandbox runtime flags.
- GKE has three validator deployments.
- Validators can reach Cloud SQL and finalize pending transactions.
- `GET /health` returns `ok` from Cloud Run.
- The Phase 1 smoke flow passes against the cloud API endpoint.
- Audit events are still persisted.

## Known Gaps

- mTLS, API Gateway, and Cloud Armor are not wired yet.
- The database connection URL remains operator-supplied for this starter.
- ISO 20022 is still a placeholder crate.
- KMS/HSM signing is not integrated into transaction or validator signatures yet.
- BFT consensus is not part of this phase.
