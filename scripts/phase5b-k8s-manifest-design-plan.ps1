$ErrorActionPreference = "Stop"

$docPath = "PHASE5B_K8S_MANIFEST_DESIGN_PLAN.md"
$configPath = "config/phase5b-k8s-manifest-design-plan.yaml"
$manifestDesignPath = "k8s/phase5b-validator-manifest-design.yaml"
$kustomizationPath = "k8s/kustomization.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    $manifestDesignPath,
    $kustomizationPath,
    "k8s/namespace.yaml",
    "k8s/validator-rbac.yaml",
    "k8s/validator-configmap.yaml",
    "k8s/validator-secret.example.yaml",
    "k8s/validators.yaml",
    "PHASE5B_GKE_TERRAFORM_DESIGN_PLAN.md",
    "config/phase5b-gke-terraform-design-plan.yaml",
    "infra/terraform/phase5b_gke_terraform_design_plan.tf",
    "scripts/phase5b-gke-terraform-design-plan.ps1",
    "PHASE5B_GKE_COST_RESOURCE_PLAN.md",
    "config/phase5b-gke-cost-resource-plan.yaml",
    "scripts/phase5b-gke-cost-resource-plan.ps1",
    "PHASE5A_WRAPUP.md",
    "config/phase5a-wrapup.yaml",
    "scripts/phase5a-validate.ps1"
)

$missing = @()
foreach ($file in $requiredArtifacts) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5B Kubernetes manifest design artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: Kubernetes manifest design plan ready",
    "phase5b-k8s-manifest-design-plan-rc1",
    "phase5b-gke-terraform-design-plan-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Manifest Boundary",
    "k8s/phase5b-validator-manifest-design.yaml",
    "kubernetes_manifest_deployment_enabled = false",
    "kubectl_apply_allowed = false",
    "kustomization_inclusion_allowed = false",
    "Current Manifest Inventory",
    "validator-configmap.yaml",
    "Design Objective",
    "Future Manifest Component Families",
    "SecretProviderClass",
    "PodDisruptionBudget",
    "ResourceQuota",
    "Required Design Sections",
    "workload_identity_annotation_model",
    "Required Review Gates",
    "manifest_dry_run_reviewed",
    "Implementation Stages",
    "stage_4_apply_candidate",
    "Non-Enablement",
    "No Kubernetes resources are deployed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes manifest design doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5b-k8s-manifest-design-plan-rc1",
    "status: k8s_manifest_design_plan_ready",
    "inherits_from: phase5b-gke-terraform-design-plan-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "manifest_design_file: k8s/phase5b-validator-manifest-design.yaml",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "manifest_boundary:",
    "design_only: true",
    "kubernetes_manifest_deployment_enabled: false",
    "kubectl_apply_allowed: false",
    "kustomization_inclusion_allowed: false",
    "included_in_kustomization: false",
    "contains_deployable_kubernetes_objects: false",
    "declares_top_level_api_version_or_kind: false",
    "current_phase2_manifest_inventory:",
    "validator_configmap_yaml: present_placeholder",
    "selected_manifest_defaults:",
    "selected_resource_profile: lean_sandbox_standard_zonal",
    "validator_namespace: kani-validator",
    "kubernetes_service_account: kani-gke-validator",
    "validator_replicas: 3",
    "future_manifest_component_families:",
    "SecretProviderClass: deferred",
    "PodDisruptionBudget: deferred",
    "ResourceQuota: deferred",
    "required_design_sections:",
    "namespace_model: required",
    "workload_identity_annotation_model: required",
    "required_review_gates:",
    "manifest_design_reviewed: blocked",
    "manifest_dry_run_reviewed: blocked",
    "no_real_value_capability_enabled: blocked",
    "implementation_stages:",
    "stage_0_design_only:",
    "stage_4_apply_candidate:",
    "allowed_by_this_checkpoint: false",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "workload_identity_iam_mutation_enabled: false",
    "phase5b_k8s_manifest_design_plan_checked_in: true",
    "aggregate_phase5b_validator_includes_k8s_manifest_design_plan: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes manifest design config content: $expected"
    }
}

$manifestDesign = Get-Content $manifestDesignPath -Raw
foreach ($expected in @(
    "release_candidate: phase5b-k8s-manifest-design-plan-rc1",
    "status: design_only_manifest_blueprint",
    "phase5b-gke-validator-ops",
    "phase2-lean-no-gke",
    "phase5b-gke-terraform-design-plan-rc1",
    "design_boundary:",
    "do_not_apply_with_kubectl: true",
    "not_included_in_kustomization: true",
    "contains_deployable_kubernetes_objects: false",
    "declares_top_level_api_version_or_kind: false",
    "kubernetes_manifest_deployment_enabled: false",
    "kubectl_apply_allowed: false",
    "kustomization_inclusion_allowed: false",
    "ENV: SANDBOX",
    "REAL_VALUE: `"FALSE`"",
    "REDEEMABLE: `"FALSE`"",
    "future_manifest_blueprint:",
    "kubernetes_kind: Namespace",
    "kubernetes_kind: ServiceAccount",
    "kubernetes_kind: Deployment",
    "validator_id: validator-a",
    "validator_id: validator-b",
    "validator_id: validator-c",
    "kubernetes_kind: PodDisruptionBudget",
    "kubernetes_kind: NetworkPolicy",
    "kubernetes_kind: ResourceQuota",
    "future_pod_requirements:",
    "pinned_digest_required_before_apply",
    "run_as_non_root_required: true",
    "review_gates:",
    "manifest_dry_run_reviewed: blocked",
    "non_enablement:",
    "live_validator_operations_enabled: false"
)) {
    if ($manifestDesign -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes manifest design blueprint content: $expected"
    }
}

$kustomization = Get-Content $kustomizationPath -Raw
if ($kustomization -match [regex]::Escape("phase5b-validator-manifest-design.yaml")) {
    throw "Phase 5B manifest design file must not be included in k8s/kustomization.yaml"
}

if ($manifestDesign -match "(?m)^(apiVersion|kind):") {
    throw "Phase 5B manifest design blueprint must not declare top-level apiVersion or kind fields"
}

$validatorConfigMap = Get-Content "k8s/validator-configmap.yaml" -Raw
foreach ($expected in @(
    "ENV: SANDBOX",
    'REAL_VALUE: "FALSE"',
    'REDEEMABLE: "FALSE"'
)) {
    if ($validatorConfigMap -notmatch [regex]::Escape($expected)) {
        throw "Expected sandbox runtime flag in current validator ConfigMap: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "terraform_gke_apply_allowed",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "gke_cluster_enabled",
    "gke_cluster_creation_enabled",
    "gke_node_pool_creation_enabled",
    "gke_resource_creation_allowed",
    "workload_identity_iam_mutation_enabled",
    "kubernetes_manifest_deployment_enabled",
    "kubectl_apply_allowed",
    "kustomization_inclusion_allowed",
    "live_validator_operations_enabled",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "public_endpoint_exposure_enabled",
    "hsm_kms_production_signing_enabled",
    "production_authorization_granted",
    "legal_or_compliance_approval_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B Kubernetes manifest design must not enable $forbidden"
    }
    if ($manifestDesign -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B Kubernetes manifest blueprint must not enable $forbidden"
    }
}

$futureManifestComponentCount = ([regex]::Matches($config, "(?m)^\s{2}[A-Za-z0-9]+:\s+deferred\s*$")).Count
if ($futureManifestComponentCount -lt 14) {
    throw "Expected at least 14 future Kubernetes manifest component families, found $futureManifestComponentCount"
}

$requiredDesignSectionCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($requiredDesignSectionCount -lt 21) {
    throw "Expected at least 21 required Kubernetes manifest design sections, found $requiredDesignSectionCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 24) {
    throw "Expected at least 24 blocked Phase 5B Kubernetes manifest design gates, found $blockedGateCount"
}

$blockedStageCount = ([regex]::Matches($config, "allowed_by_this_checkpoint:\s+false")).Count
if ($blockedStageCount -lt 4) {
    throw "Expected at least 4 blocked Phase 5B Kubernetes manifest implementation stages, found $blockedStageCount"
}

$blueprintWorkloadCount = ([regex]::Matches($manifestDesign, "(?m)^\s{4}kubernetes_kind:\s+Deployment\s*$")).Count
if ($blueprintWorkloadCount -ne 3) {
    throw "Expected exactly 3 future validator Deployment blueprint entries, found $blueprintWorkloadCount"
}

[pscustomobject]@{
    release_candidate = "phase5b-k8s-manifest-design-plan-rc1"
    status = "k8s_manifest_design_plan_ready"
    track = "phase5b-gke-validator-ops"
    active_runtime_baseline = "phase2-lean-no-gke"
    phase5b_terraform_design_baseline = "phase5b-gke-terraform-design-plan-rc1"
    manifest_design_file = $manifestDesignPath
    future_manifest_component_family_count = $futureManifestComponentCount
    required_design_section_count = $requiredDesignSectionCount
    blocked_review_gate_count = $blockedGateCount
    blocked_implementation_stage_count = $blockedStageCount
    validator_deployment_blueprint_count = $blueprintWorkloadCount
    design_only_manifest_blueprint = $true
    included_in_kustomization = $false
    gke_enabled = $false
    gke_node_pool_creation_enabled = $false
    workload_identity_iam_mutation_enabled = $false
    terraform_apply_allowed = $false
    kubectl_apply_allowed = $false
    kubernetes_manifest_deployment_enabled = $false
    live_validator_operations_enabled = $false
    google_cloud_resources_changed = $false
    kubernetes_resources_deployed = $false
    production_authorization_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
