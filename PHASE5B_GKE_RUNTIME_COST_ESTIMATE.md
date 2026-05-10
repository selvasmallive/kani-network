# KANI Phase 5B GKE Runtime Cost Estimate

Status: planning estimate for live sandbox runtime
Captured: 2026-05-10
Project: `kani-network-sandbox`
Region: `northamerica-northeast1`
Currency: USD, with approximate CAD conversion at `1 USD = 1.365982 CAD`

This estimate is for deciding whether to keep the Phase 5B GKE sandbox pilot running longer. It is not a Google Cloud invoice or billing export. Taxes, committed-use discounts, free-trial credit treatment, currency conversion, Cloud Logging volume, network egress, and any unrelated project usage can change the real bill.

## Live Footprint

Observed resources:

- GKE Standard zonal cluster: `kani-sandbox-validators`
- GKE node pool: 1 node, `e2-medium`, on-demand, `pd-standard` 20 GB boot disk
- Validators: 3 Kubernetes deployments in `kani-system`
- Cloud SQL PostgreSQL: `db-g1-small`, zonal, 10 GiB HDD, backups and PITR enabled
- Cloud Run API: min scale 0, max scale 1, 1 vCPU, 512 MiB
- Artifact Registry: 12 images, about 0.496 GiB total
- Cloud Scheduler validator job: paused while GKE validators are active
- Budget guardrail: CAD 200 monthly budget on `kani-network-sandbox`, with 50%, 80%, and 100% thresholds

## Monthly Run-Rate Estimate

Assumption: 730 hours per month.

| Cost item | Input | Estimate USD/month | Estimate CAD/month |
|---|---:|---:|---:|
| GKE cluster management fee | $0.10/hour gross, expected covered by one zonal-cluster free-tier credit | $0.00 net | $0.00 net |
| GKE node VM | 1 x `e2-medium` at $0.03350571/hour | $24.46 | $33.41 |
| GKE node boot disk | 20 GB `pd-standard`, estimated at $0.04/GB-month | $0.80 | $1.09 |
| Cloud SQL instance | 1 x `db-g1-small` at $0.035/hour | $25.55 | $34.90 |
| Cloud SQL data disk | 10 GiB HDD at $0.000123288/GiB-hour | $0.90 | $1.23 |
| Cloud SQL backup storage allowance | Worst-case placeholder: 10 GiB used backup at $0.000109589/GiB-hour | $0.80 | $1.09 |
| Cloud Run API | Min scale 0; low sandbox traffic expected inside free tier | $0.00-$2.00 | $0.00-$2.73 |
| Artifact Registry storage | 0.496 GiB observed; first 0.5 GB free | $0.00 | $0.00 |
| Logging and Monitoring | Expected under free allotments for current low traffic; alert-policy charges can apply | $0.00-$10.00 | $0.00-$13.66 |

Estimated active pilot total:

- Baseline estimate: about `$52.51 USD/month`, or about `CAD $71.73/month`.
- With a small observability and Cloud Run cushion: about `$55-$65 USD/month`, or about `CAD $75-$89/month`.
- If the GKE cluster management free tier is not available because the billing account is already consuming it elsewhere, add about `$73.00 USD/month`, or about `CAD $99.72/month`.

## Free Trial Impact

The user reported a 90-day, $300 Google Cloud free trial. If credits are available and this project is the main consumer:

- One month at the baseline estimate consumes about `$52.51 USD`.
- A full 90-day run consumes about `$157.53 USD`.
- `$300 USD` would cover about `5.7 months` at the baseline run rate, but the trial ends after 90 days.

This means the GKE pilot can likely run through the 90-day trial from a credit-burn perspective. The current CAD 200 budget alert is intended to allow a one-month GKE observation run while still sending warnings before the free-trial credit is materially consumed.

## Recommendation

Recommended decision:

- Keep GKE running for the approved one-month observation window from May 10, 2026 through June 10, 2026.
- Keep the Terraform-managed budget guardrail at CAD 200 for this window, with alert thresholds at CAD 100, CAD 160, and CAD 200.
- If you are not actively testing validators, tear down the `infra/terraform-gke` root and keep the no-GKE Cloud Run plus Cloud SQL baseline.
- Before more builds, clean old Artifact Registry images or add a retention policy. Current image storage is just under the 0.5 GiB free tier.

## Pricing Sources

- GKE pricing: https://cloud.google.com/kubernetes-engine/pricing
- Compute Engine VM pricing: https://cloud.google.com/compute/all-pricing
- Compute Engine disk pricing: https://cloud.google.com/compute/disks-image-pricing
- Cloud SQL pricing: https://cloud.google.com/sql/docs/postgres/pricing
- Cloud Run pricing: https://cloud.google.com/run/pricing
- Artifact Registry pricing: https://cloud.google.com/artifact-registry/pricing
- Google Cloud Observability pricing: https://cloud.google.com/stackdriver/pricing
