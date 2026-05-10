$ErrorActionPreference = "Stop"

$docPath = "PHASE5B_WRAPUP.md"
$configPath = "config/phase5b-wrapup.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5B_GKE_OPERATOR_APPROVAL_PACKET.md",
    "config/phase5b-gke-operator-approval-packet.yaml",
    "scripts/phase5b-gke-operator-approval-packet.ps1",
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
    throw "Missing Phase 5B wrap-up artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: GKE validator ops planning complete",
    "phase5b-wrapup-rc1",
    "phase5b-gke-operator-approval-packet-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Completed Phase 5B Checkpoints",
    "phase5b-gke-cost-resource-plan-rc1",
    "phase5b-gke-terraform-design-plan-rc1",
    "phase5b-k8s-manifest-design-plan-rc1",
    "phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "phase5b-gke-apply-readiness-gate-rc1",
    "phase5b-gke-operator-approval-packet-rc1",
    "Phase 5B Result",
    "Aggregate Phase 5B validator coverage",
    "GKE resource creation",
    "Terraform apply approval",
    "Phase 5B can hand off to",
    "phase6-gke-apply-candidate",
    "Required Blocks That Remain",
    "GKE resource approval",
    "Production authorization",
    "Real-value settlement",
    "Non-Enablement",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B wrap-up doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5b-wrapup-rc1",
    "status: gke_validator_ops_planning_complete",
    "inherits_from: phase5b-gke-operator-approval-packet-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "phase5a_baseline: phase5a-wrapup-rc1",
    "next_phase: phase6-gke-apply-candidate",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "completed_release_candidates:",
    "phase5b_gke_cost_resource_plan_rc1: true",
    "phase5b_gke_terraform_design_plan_rc1: true",
    "phase5b_k8s_manifest_design_plan_rc1: true",
    "phase5b_k8s_render_dry_run_evidence_plan_rc1: true",
    "phase5b_gke_apply_readiness_gate_rc1: true",
    "phase5b_gke_operator_approval_packet_rc1: true",
    "phase_result:",
    "gke_validator_ops_planning_complete: true",
    "planning_validation_and_evidence_only: true",
    "cloud_run_scheduler_runtime_preserved: true",
    "aggregate_phase5b_validator_coverage_complete: true",
    "phase5b_ready_to_close: true",
    "phase6_apply_candidate_deferred_until_explicit_approval: true",
    "production_ready: false",
    "real_value_ready: false",
    "google_cloud_resources_created: false",
    "paid_resources_created: false",
    "terraform_plan_execution_approved_by_this_checkpoint: false",
    "terraform_apply_allowed: false",
    "kubectl_apply_allowed: false",
    "gcloud_mutation_allowed: false",
    "gke_cluster_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "kubernetes_manifest_deployment_enabled: false",
    "live_validator_operations_enabled: false",
    "phase6_handoff:",
    "handoff_allowed_only_after_explicit_approvals: true",
    "active_runtime_remains_no_gke_until_later_checkpoint: true",
    "approved_gke_cost_estimate_and_budget_guardrail_reference",
    "remaining_blocked_gates:",
    "gke_resource_approval: blocked",
    "gke_cost_estimate_approval: blocked",
    "terraform_plan_execution_approval: blocked",
    "terraform_apply_approval: blocked",
    "operator_signoff_approval: blocked",
    "production_authorization: blocked",
    "real_value_settlement: blocked",
    "non_enablement:",
    "phase5b_wrapup_checked_in: true",
    "aggregate_phase5b_validator_includes_wrapup: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B wrap-up config content: $expected"
    }
}

foreach ($forbidden in @(
    "production_ready",
    "real_value_ready",
    "legal_advice_provided",
    "google_cloud_resources_created",
    "paid_resources_created",
    "terraform_plan_execution_approved_by_this_checkpoint",
    "terraform_apply_allowed",
    "kubectl_apply_allowed",
    "gcloud_mutation_allowed",
    "gke_cluster_enabled",
    "gke_cluster_creation_enabled",
    "gke_node_pool_creation_enabled",
    "kubernetes_manifest_deployment_enabled",
    "live_validator_operations_enabled",
    "operator_approval_packet_complete",
    "operator_signoff_approved",
    "reviewer_signoff_approved",
    "apply_candidate_authorized",
    "apply_readiness_gate_passed",
    "gke_apply_ready",
    "apply_window_approved",
    "terraform_apply_execution_approved_by_this_checkpoint",
    "kubernetes_apply_execution_approved_by_this_checkpoint",
    "terraform_gke_apply_allowed",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "cloud_billing_change_allowed",
    "workload_identity_iam_mutation_enabled",
    "kubectl_apply_allowed",
    "render_execution_enabled",
    "client_dry_run_execution_approved_by_this_checkpoint",
    "server_dry_run_execution_approved_by_this_checkpoint",
    "kustomization_inclusion_allowed",
    "kubeconfig_mutation_allowed",
    "cluster_context_mutation_allowed",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "public_endpoint_exposure_enabled",
    "hsm_kms_production_signing_enabled",
    "scheduler_changes_enabled",
    "cloud_run_job_execution_approved_by_this_checkpoint",
    "secret_rotation_approved_by_this_checkpoint",
    "failure_injection_enabled",
    "live_failure_drills_enabled",
    "live_retry_drills_enabled",
    "live_recovery_drills_enabled",
    "live_drill_execution_approved_by_this_checkpoint",
    "production_replay_enabled",
    "restore_drill_executed",
    "production_recovery_executed",
    "external_evidence_export_enabled",
    "external_institution_onboarding_enabled",
    "production_authorization_granted",
    "legal_or_compliance_approval_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B wrap-up must not enable $forbidden"
    }
}

$completedCount = ([regex]::Matches($config, "phase5b_[a-z0-9_]+_rc1:\s+true")).Count
if ($completedCount -lt 6) {
    throw "Expected at least 6 completed Phase 5B release candidates, found $completedCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 30) {
    throw "Expected at least 30 blocked Phase 5B wrap-up gates, found $blockedGateCount"
}

$handoffFocusCount = ([regex]::Matches($config, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($handoffFocusCount -lt 8) {
    throw "Expected at least 8 Phase 6 handoff focus items, found $handoffFocusCount"
}

[pscustomobject]@{
    release_candidate = "phase5b-wrapup-rc1"
    status = "gke_validator_ops_planning_complete"
    track = "phase5b-gke-validator-ops"
    completed_release_candidate_count = $completedCount
    blocked_gate_count = $blockedGateCount
    handoff_focus_count = $handoffFocusCount
    active_runtime_baseline = "phase2-lean-no-gke"
    phase5b_ready_to_close = $true
    next_phase = "phase6-gke-apply-candidate"
    gke_enabled = $false
    gke_cluster_creation_enabled = $false
    gke_node_pool_creation_enabled = $false
    google_cloud_resources_created = $false
    terraform_plan_execution_approved = $false
    terraform_apply_allowed = $false
    kubectl_apply_allowed = $false
    gcloud_mutation_allowed = $false
    kubernetes_manifest_deployment_enabled = $false
    live_validator_operations_enabled = $false
    production_authorization_enabled = $false
    legal_or_compliance_approval_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
