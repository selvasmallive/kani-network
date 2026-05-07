# KANI Validators On GKE

These manifests deploy the Phase 2 sandbox validator set:

```text
validator-a
validator-b
validator-c
```

The API remains a Cloud Run service in Phase 2. These Kubernetes manifests are only for validator processes.

## Before Applying

1. Build and push the shared image to Artifact Registry.
2. Replace `PROJECT_ID` in `kustomization.yaml`.
3. Replace `REPLACE_WITH_VALIDATOR_GSA_EMAIL` in `validator-rbac.yaml` with the Terraform output `validator_service_account`.
4. Replace `REPLACE_WITH_CLOUD_SQL_CONNECTION_NAME` in `validator-configmap.yaml` with the Terraform output `cloud_sql_connection_name`.
5. Create a real Kubernetes secret from `validator-secret.example.yaml`.

```powershell
kubectl apply -f k8s/validator-secret.example.yaml
kubectl apply -k k8s
```

The example secret contains placeholders and must not be committed with real credentials.

Each validator pod includes a Cloud SQL proxy sidecar bound to `127.0.0.1:5432`, so the validator `DATABASE_URL` should target localhost inside the pod.

## Required Runtime Flags

The ConfigMap keeps all validators inside the sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```
