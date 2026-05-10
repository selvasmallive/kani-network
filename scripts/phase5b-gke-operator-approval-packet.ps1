$ErrorActionPreference = "Stop"

$docPath = "PHASE5B_GKE_OPERATOR_APPROVAL_PACKET.md"
$configPath = "config/phase5b-gke-operator-approval-packet.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5B_GKE_APPLY_READINESS_GATE.md",
    "config/phase5b-gke-apply-readiness-gate.yaml",
    "scripts/phase5b-gke-apply-readiness-gate.ps1",
    "PHASE5B_K8S_RENDER_DRY_RUN_EVIDENCE_PLAN.md",
    "config/phase5b-k8s-render-dry-run-evidence-plan.yaml",
    "k8s/phase5b-render-dry-run-evidence-plan.yaml",
    "scripts/phase5b-k8s-render-dry-run-evidence-plan.ps1",
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
    throw "Missing Phase 5B GKE operator approval packet artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: GKE operator approval packet defined and blocked",
    "phase5b-gke-operator-approval-packet-rc1",
    "phase5b-gke-apply-readiness-gate-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Packet Outcome",
    "operator_approval_packet_state = BLOCKED",
    "operator_approval_packet_complete = FALSE",
    "apply_candidate_authorized = FALSE",
    "Required Roles",
    "primary_operator",
    "evidence_custodian",
    "Required Packet Sections",
    "terraform_plan_hash",
    "no_real_value_attestation",
    "Required Signoffs",
    "primary_operator_signoff",
    "no_real_value_capability_acknowledgement",
    "Implementation Stages",
    "stage_6_apply_readiness_re_evaluation_candidate",
    "Non-Enablement",
    "No Terraform plan, Terraform apply, render, dry-run"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE operator approval packet doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5b-gke-operator-approval-packet-rc1",
    "status: gke_operator_approval_packet_defined_and_blocked",
    "inherits_from: phase5b-gke-apply-readiness-gate-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_apply_readiness_baseline: phase5b-gke-apply-readiness-gate-rc1",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "packet_outcome:",
    "operator_approval_packet_state: BLOCKED",
    "operator_approval_packet_complete: false",
    "operator_signoff_approved: false",
    "reviewer_signoff_approved: false",
    "apply_candidate_authorized: false",
    "apply_readiness_gate_passed: false",
    "gke_apply_ready: false",
    "apply_window_approved: false",
    "required_roles:",
    "primary_operator: required",
    "evidence_custodian: required",
    "required_packet_sections:",
    "terraform_plan_hash: required",
    "no_real_value_attestation: required",
    "required_signoffs:",
    "primary_operator_signoff: blocked",
    "no_real_value_capability_acknowledgement: blocked",
    "implementation_stages:",
    "stage_0_operator_packet_defined:",
    "stage_6_apply_readiness_re_evaluation_candidate:",
    "allowed_by_this_checkpoint: false",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "workload_identity_iam_mutation_enabled: false",
    "phase5b_gke_operator_approval_packet_checked_in: true",
    "aggregate_phase5b_validator_includes_gke_operator_approval_packet: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE operator approval packet config content: $expected"
    }
}

foreach ($forbidden in @(
    "operator_approval_packet_complete",
    "operator_signoff_approved",
    "reviewer_signoff_approved",
    "apply_candidate_authorized",
    "apply_readiness_gate_passed",
    "gke_apply_ready",
    "apply_window_approved",
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_plan_execution_approved_by_this_checkpoint",
    "terraform_apply_execution_approved_by_this_checkpoint",
    "kubernetes_apply_execution_approved_by_this_checkpoint",
    "terraform_apply_allowed",
    "terraform_gke_apply_allowed",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "cloud_billing_change_allowed",
    "gcloud_mutation_allowed",
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
        throw "Phase 5B GKE operator approval packet must not enable $forbidden"
    }
}

$requiredRoleCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($requiredRoleCount -lt 10) {
    throw "Expected at least 10 required Phase 5B operator roles, found $requiredRoleCount"
}

$requiredPacketSectionCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($requiredPacketSectionCount -lt 42) {
    throw "Expected at least 42 required Phase 5B operator packet sections, found $requiredPacketSectionCount"
}

$blockedSignoffCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedSignoffCount -lt 23) {
    throw "Expected at least 23 blocked Phase 5B operator signoffs, found $blockedSignoffCount"
}

$blockedStageCount = ([regex]::Matches($config, "allowed_by_this_checkpoint:\s+false")).Count
if ($blockedStageCount -lt 6) {
    throw "Expected at least 6 blocked Phase 5B operator approval stages, found $blockedStageCount"
}

[pscustomobject]@{
    release_candidate = "phase5b-gke-operator-approval-packet-rc1"
    status = "gke_operator_approval_packet_defined_and_blocked"
    track = "phase5b-gke-validator-ops"
    active_runtime_baseline = "phase2-lean-no-gke"
    phase5b_apply_readiness_baseline = "phase5b-gke-apply-readiness-gate-rc1"
    required_role_count = 10
    required_packet_section_count = $requiredPacketSectionCount
    blocked_signoff_count = $blockedSignoffCount
    blocked_operator_stage_count = $blockedStageCount
    operator_approval_packet_complete = $false
    operator_signoff_approved = $false
    reviewer_signoff_approved = $false
    apply_candidate_authorized = $false
    apply_readiness_gate_passed = $false
    gke_apply_ready = $false
    apply_window_approved = $false
    terraform_plan_execution_approved = $false
    terraform_apply_allowed = $false
    kubectl_apply_allowed = $false
    gcloud_mutation_allowed = $false
    gke_enabled = $false
    gke_node_pool_creation_enabled = $false
    workload_identity_iam_mutation_enabled = $false
    kubernetes_manifest_deployment_enabled = $false
    live_validator_operations_enabled = $false
    google_cloud_resources_changed = $false
    kubernetes_resources_deployed = $false
    production_authorization_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
