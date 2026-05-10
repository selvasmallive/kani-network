$ErrorActionPreference = "Stop"

$docPath = "PHASE5B_K8S_RENDER_DRY_RUN_EVIDENCE_PLAN.md"
$configPath = "config/phase5b-k8s-render-dry-run-evidence-plan.yaml"
$evidencePlanPath = "k8s/phase5b-render-dry-run-evidence-plan.yaml"
$kustomizationPath = "k8s/kustomization.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    $evidencePlanPath,
    $kustomizationPath,
    "PHASE5B_K8S_MANIFEST_DESIGN_PLAN.md",
    "config/phase5b-k8s-manifest-design-plan.yaml",
    "k8s/phase5b-validator-manifest-design.yaml",
    "scripts/phase5b-k8s-manifest-design-plan.ps1",
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
    throw "Missing Phase 5B Kubernetes render/dry-run evidence artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: Kubernetes render and dry-run evidence plan ready",
    "phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "phase5b-k8s-manifest-design-plan-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Evidence Boundary",
    "k8s/phase5b-render-dry-run-evidence-plan.yaml",
    "render_execution_enabled = false",
    "client_dry_run_execution_approved_by_this_checkpoint = false",
    "server_dry_run_execution_approved_by_this_checkpoint = false",
    "kubectl_apply_allowed = false",
    "Command Template Boundary",
    "kubectl kustomize k8s",
    "kubectl apply --dry-run=client -k k8s",
    "kubectl apply --dry-run=server -k k8s",
    "Required Evidence Pack",
    "rendered_manifest_sha256",
    "secret_redaction_evidence",
    "Required Review Gates",
    "render_evidence_plan_reviewed",
    "server_dry_run_reviewed",
    "Implementation Stages",
    "stage_7_apply_candidate",
    "Non-Enablement",
    "No render or dry-run command is executed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes render/dry-run evidence doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "status: k8s_render_dry_run_evidence_plan_ready",
    "inherits_from: phase5b-k8s-manifest-design-plan-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "evidence_plan_file: k8s/phase5b-render-dry-run-evidence-plan.yaml",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "evidence_boundary:",
    "design_only: true",
    "render_execution_enabled: false",
    "client_dry_run_execution_approved_by_this_checkpoint: false",
    "server_dry_run_execution_approved_by_this_checkpoint: false",
    "kubectl_apply_allowed: false",
    "kubernetes_manifest_deployment_enabled: false",
    "kustomization_inclusion_allowed: false",
    "included_in_kustomization: false",
    "kubeconfig_mutation_allowed: false",
    "cluster_context_mutation_allowed: false",
    "declares_top_level_api_version_or_kind: false",
    "command_template_scope:",
    "commands_documented_only: true",
    "non_dry_run_apply_template_allowed: false",
    "required_evidence_pack_sections:",
    "operator_identity: required",
    "rendered_manifest_sha256: required",
    "server_dry_run_stderr_redacted: required",
    "secret_redaction_evidence: required",
    "required_review_gates:",
    "render_evidence_plan_reviewed: blocked",
    "server_dry_run_reviewed: blocked",
    "no_apply_command_confirmed: blocked",
    "no_real_value_capability_enabled: blocked",
    "implementation_stages:",
    "stage_0_evidence_plan_only:",
    "stage_7_apply_candidate:",
    "allowed_by_this_checkpoint: false",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "workload_identity_iam_mutation_enabled: false",
    "phase5b_k8s_render_dry_run_evidence_plan_checked_in: true",
    "aggregate_phase5b_validator_includes_k8s_render_dry_run_evidence_plan: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes render/dry-run evidence config content: $expected"
    }
}

$evidencePlan = Get-Content $evidencePlanPath -Raw
foreach ($expected in @(
    "release_candidate: phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "status: render_dry_run_evidence_contract",
    "phase5b-gke-validator-ops",
    "phase2-lean-no-gke",
    "phase5b-k8s-manifest-design-plan-rc1",
    "design_boundary:",
    "do_not_apply_with_kubectl: true",
    "not_included_in_kustomization: true",
    "contains_deployable_kubernetes_objects: false",
    "declares_top_level_api_version_or_kind: false",
    "render_execution_enabled: false",
    "client_dry_run_execution_approved_by_this_checkpoint: false",
    "server_dry_run_execution_approved_by_this_checkpoint: false",
    "kubectl_apply_allowed: false",
    "future_command_templates:",
    "kubectl version --client --output=yaml",
    "kubectl kustomize k8s",
    "kubectl apply --dry-run=client -k k8s",
    "kubectl apply --dry-run=server -k k8s",
    "non_dry_run_apply:",
    "command_allowed: false",
    "future_evidence_pack:",
    "rendered_manifest_sha256: required",
    "server_dry_run_stderr_redacted: required",
    "secret_redaction_evidence: required",
    "redaction_rules:",
    "database_urls: redact",
    "review_gates:",
    "server_dry_run_reviewed: blocked",
    "non_enablement:",
    "live_validator_operations_enabled: false"
)) {
    if ($evidencePlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes render/dry-run evidence contract content: $expected"
    }
}

$kustomization = Get-Content $kustomizationPath -Raw
if ($kustomization -match [regex]::Escape("phase5b-render-dry-run-evidence-plan.yaml")) {
    throw "Phase 5B render/dry-run evidence file must not be included in k8s/kustomization.yaml"
}

if ($evidencePlan -match "(?m)^(apiVersion|kind):") {
    throw "Phase 5B render/dry-run evidence contract must not declare top-level apiVersion or kind fields"
}

$applyTemplateMatches = [regex]::Matches($evidencePlan, "kubectl apply[^\r\n]*")
foreach ($match in $applyTemplateMatches) {
    if ($match.Value -notmatch "--dry-run=(client|server)") {
        throw "Phase 5B render/dry-run evidence contract must not include non-dry-run kubectl apply templates: $($match.Value)"
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
    "render_execution_enabled",
    "local_render_execution_approved_by_this_checkpoint",
    "client_dry_run_execution_approved_by_this_checkpoint",
    "server_dry_run_execution_approved_by_this_checkpoint",
    "kustomization_inclusion_allowed",
    "kubeconfig_mutation_allowed",
    "cluster_context_mutation_allowed",
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
        throw "Phase 5B render/dry-run evidence plan must not enable $forbidden"
    }
    if ($evidencePlan -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B render/dry-run evidence contract must not enable $forbidden"
    }
}

$evidenceSectionCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($evidenceSectionCount -lt 31) {
    throw "Expected at least 31 required render/dry-run evidence pack sections, found $evidenceSectionCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 28) {
    throw "Expected at least 28 blocked Phase 5B render/dry-run evidence gates, found $blockedGateCount"
}

$blockedStageCount = ([regex]::Matches($config, "allowed_by_this_checkpoint:\s+false")).Count
if ($blockedStageCount -lt 6) {
    throw "Expected at least 6 blocked Phase 5B render/dry-run execution stages, found $blockedStageCount"
}

$commandTemplateCount = ([regex]::Matches($evidencePlan, "execution_status:\s+deferred")).Count
if ($commandTemplateCount -lt 4) {
    throw "Expected at least 4 deferred command templates, found $commandTemplateCount"
}

[pscustomobject]@{
    release_candidate = "phase5b-k8s-render-dry-run-evidence-plan-rc1"
    status = "k8s_render_dry_run_evidence_plan_ready"
    track = "phase5b-gke-validator-ops"
    active_runtime_baseline = "phase2-lean-no-gke"
    phase5b_k8s_manifest_design_baseline = "phase5b-k8s-manifest-design-plan-rc1"
    evidence_plan_file = $evidencePlanPath
    required_evidence_section_count = $evidenceSectionCount
    blocked_review_gate_count = $blockedGateCount
    blocked_execution_stage_count = $blockedStageCount
    deferred_command_template_count = $commandTemplateCount
    included_in_kustomization = $false
    render_execution_enabled = $false
    client_dry_run_execution_enabled = $false
    server_dry_run_execution_enabled = $false
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
