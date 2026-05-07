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

## Current Sandbox Project

The current Google Cloud sandbox project is:

```text
Project ID: kani-network-sandbox
Project name: kani-network
Organization: kani.network
Billing: linked
```

The original `kani-network` project ID is not accessible to the `selva@kani.network` account, so Phase 2 uses the dedicated `kani-network-sandbox` project ID.

## Lean Free-Trial Profile

The default Terraform variables now target the minimum useful Phase 2 sandbox footprint. This profile is designed for the Google Cloud 90-day free trial and keeps paid runtime resources as small as possible while still exercising Cloud Run, GKE validators, Cloud SQL, Secret Manager, Artifact Registry, Cloud Storage, and KMS.

Default lean settings:

- Cloud Run `kani-sandbox-api` scales to zero and is capped at `1` instance.
- GKE uses one zonal Standard cluster in `northamerica-northeast1-a`.
- GKE validator nodes use a single `e2-small` node with a `20 GB` standard persistent disk.
- The three validators run as pods on the single node. This preserves the Phase 2 validator shape, but it is not high availability.
- Cloud SQL PostgreSQL uses `db-f1-micro` with a `10 GB` HDD disk.
- Cloud SQL automated backups and point-in-time recovery are disabled for cost control.
- Cloud Storage starts empty and is reserved for future block/audit archive writes.
- KMS uses one software key for future signing integration.

Resources that can create billable usage:

- GKE Standard cluster management plane and the one Compute Engine node.
- Cloud SQL PostgreSQL instance and its persistent disk.
- Cloud Run request CPU/memory when the API is receiving traffic.
- Artifact Registry image storage beyond the free allowance.
- Cloud Storage object storage once archives are written.
- Secret Manager active secret versions beyond the free allowance.
- Cloud KMS software key version and key operations.
- Cloud Build minutes when building container images.

This profile is intentionally a sandbox cost profile. It should not be used for production, availability testing, regulated value movement, or disaster recovery validation. Before real value movement, switch to a production profile with multi-zone or regional capacity, backups, PITR, stricter ingress, mTLS/API Gateway, Cloud Armor, monitoring, alerting, key ceremonies, and legal/compliance sign-off.

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

## Local Planning Commands

Use the installed tool paths on this workstation if they are not on `PATH`:

```powershell
& 'C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd' config set project kani-network-sandbox
& 'C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd' auth application-default login --project=kani-network-sandbox
& 'C:\ProgramData\chocolatey\bin\terraform.exe' -chdir=infra\terraform init -backend=false
& 'C:\ProgramData\chocolatey\bin\terraform.exe' -chdir=infra\terraform validate
& 'C:\ProgramData\chocolatey\bin\terraform.exe' -chdir=infra\terraform plan
```

Do not run `terraform apply` until you are ready to create paid sandbox resources.

To keep the free-trial budget safe:

```powershell
# Preview only; does not create paid resources.
& 'C:\ProgramData\chocolatey\bin\terraform.exe' -chdir=infra\terraform plan

# Destroy sandbox resources after testing if you apply later.
& 'C:\ProgramData\chocolatey\bin\terraform.exe' -chdir=infra\terraform destroy
```

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
