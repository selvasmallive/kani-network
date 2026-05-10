$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE4_PRE_PRODUCTION_READINESS.md",
    "PHASE4_COST_MODEL.md",
    "PHASE4_SECURITY_REVIEW_SCOPE.md",
    "PHASE4_HSM_KMS_IMPLEMENTATION_PLAN.md",
    "PHASE4_PROD_INGRESS_IMPLEMENTATION_PLAN.md",
    "PHASE4_DR_READINESS.md",
    "PHASE4_LEGAL_COMPLIANCE_EVIDENCE.md",
    "PHASE4_WRAPUP.md",
    "config/phase4-pre-production-readiness.yaml",
    "config/phase4-cost-model.yaml",
    "config/phase4-security-review-scope.yaml",
    "config/phase4-hsm-kms-implementation-plan.yaml",
    "config/phase4-prod-ingress-implementation-plan.yaml",
    "config/phase4-dr-readiness.yaml",
    "config/phase4-legal-compliance-evidence.yaml",
    "config/phase4-wrapup.yaml",
    "scripts/phase4-validate.ps1",
    "scripts/phase4-cost-model.ps1",
    "scripts/phase4-security-review-scope.ps1",
    "scripts/phase4-hsm-kms-implementation-plan.ps1",
    "scripts/phase4-prod-ingress-implementation-plan.ps1",
    "scripts/phase4-dr-readiness.ps1",
    "scripts/phase4-legal-compliance-evidence.ps1",
    "scripts/phase4-wrapup.ps1",
    "infra/terraform/phase4_hsm_kms_implementation_plan.tf",
    "infra/terraform/phase4_prod_ingress_implementation_plan.tf",
    "infra/terraform/phase4_dr_readiness.tf",
    "PHASE3_WRAPUP.md",
    "scripts/phase3-validate.ps1",
    "scripts/phase2-validate.ps1"
)

$missing = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 4 readiness files: $($missing -join ', ')"
}

$plan = Get-Content "PHASE4_PRE_PRODUCTION_READINESS.md" -Raw
foreach ($expected in @(
    "Status: readiness planning started",
    "phase4-pre-production-readiness-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase4-no-gke-preprod-readiness",
    "GKE remains deferred",
    "phase5b-gke-validator-ops",
    "phase2-lean-no-gke",
    "Cloud Run Job plus Cloud Scheduler",
    "No GKE cluster creation",
    "Readiness Gates",
    "legal_classification_review",
    "production_cost_estimate_review",
    "terraform_plan_review",
    "executive_go_live_approval",
    "Cost Gate",
    "Phase 5 Split",
    "phase5a-no-gke-validator-hardening",
    "phase5b-gke-validator-ops",
    "Non-Enablement",
    "GKE cluster creation",
    "Real-value settlement",
    "No Google Cloud resources are created",
    "No paid production-style resources are enabled"
)) {
    if ($plan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 readiness plan content: $expected"
    }
}

$costModel = Get-Content "PHASE4_COST_MODEL.md" -Raw
foreach ($expected in @(
    "Status: cost model ready",
    "phase4-cost-model-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Cost Model Principle",
    "Current No-GKE Baseline",
    "Deferred Production-Style Estimates",
    "GKE validator operations estimate",
    "Scenario Matrix",
    "preprod_no_gke",
    "validator_ops_gke_lab",
    "Approval Gates",
    "phase5b-gke-validator-ops",
    "Phase 5A remains no-GKE",
    "No Google Cloud resources are created or changed"
)) {
    if ($costModel -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 cost model content: $expected"
    }
}

$securityScope = Get-Content "PHASE4_SECURITY_REVIEW_SCOPE.md" -Raw
foreach ($expected in @(
    "Status: security scope ready",
    "phase4-security-review-scope-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Review Objectives",
    "In-Scope Assets",
    "Out-Of-Scope Until Explicit Approval",
    "Threat Areas",
    "Test Evidence Requirements",
    "Required Review Workstreams",
    "api_authorization_review",
    "deferred_gke_hsm_ingress_review",
    "Penetration test execution",
    "Production target testing",
    "No Google Cloud resources are created or changed"
)) {
    if ($securityScope -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 security review scope content: $expected"
    }
}

$hsmKmsPlan = Get-Content "PHASE4_HSM_KMS_IMPLEMENTATION_PLAN.md" -Raw
foreach ($expected in @(
    "Status: implementation plan ready",
    "phase4-hsm-kms-implementation-plan-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Target Signing Purposes",
    "validator_block_signing",
    "treasury_asset_authority",
    "Implementation Stages",
    "stage_0_design_only",
    "stage_2_kms_mock_adapter",
    "Signing Request Contract",
    "Raw private keys must never leave managed custody",
    "Required Gates Before Apply",
    "Terraform Boundary",
    "phase4_hsm_kms_implementation_enabled = false",
    'Declare no `resource "google_*"` blocks',
    "No Google Cloud resources are created or changed"
)) {
    if ($hsmKmsPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS implementation plan content: $expected"
    }
}

$prodIngressPlan = Get-Content "PHASE4_PROD_INGRESS_IMPLEMENTATION_PLAN.md" -Raw
foreach ($expected in @(
    "Status: implementation plan ready",
    "phase4-prod-ingress-implementation-plan-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Implementation Objective",
    "This plan is not an approval to enable production ingress",
    "Target Components",
    "external_https_load_balancer_or_api_gateway_decision",
    "serverless_neg_to_cloud_run_api",
    "certificate_manager_tls_certificate",
    "certificate_manager_trust_config",
    "institution_mtls",
    "cloud_armor_waf",
    "admin_oidc",
    "private_cloud_run_ingress",
    "Request Paths",
    "institution_api_path",
    "admin_api_path",
    "validator_internal_path",
    "health_path",
    "Implementation Stages",
    "stage_0_design_only",
    "stage_3_mtls_trust_design",
    "Required Gates Before Apply",
    "DNS owner approval recorded",
    "Cloud Armor policy reviewed",
    "Terraform Boundary",
    "phase4_prod_ingress_implementation_enabled = false",
    'Declare no `resource "google_*"` blocks',
    "allUsers",
    "allAuthenticatedUsers",
    "Public endpoint exposure",
    "No Google Cloud resources are created or changed"
)) {
    if ($prodIngressPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress implementation plan content: $expected"
    }
}

$drReadinessPlan = Get-Content "PHASE4_DR_READINESS.md" -Raw
foreach ($expected in @(
    "Status: DR readiness ready",
    "phase4-dr-readiness-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Readiness Objective",
    "This plan is not an approval to execute production recovery",
    "Recovery Domains",
    "ledger_database",
    "ledger_integrity",
    "api_runtime",
    "validator_runtime",
    "secrets_and_credentials",
    "audit_and_reporting",
    "Target RTO/RPO",
    "sandbox_no_gke",
    'target RTO `4h`',
    'target RPO `15m`',
    "Evidence Drills",
    "backup_configuration_inventory",
    "pitr_restore_to_separate_instance",
    "ledger_reconciliation_check",
    "validator_recovery_check",
    "post_drill_report",
    "Restore Runbook",
    "Required Gates Before Drill Execution",
    "Terraform Boundary",
    "phase4_dr_readiness_enabled = false",
    'Declare no `resource "google_*"` blocks',
    "No Google Cloud resources are created or changed"
)) {
    if ($drReadinessPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 DR readiness content: $expected"
    }
}

$legalComplianceEvidence = Get-Content "PHASE4_LEGAL_COMPLIANCE_EVIDENCE.md" -Raw
foreach ($expected in @(
    "Status: evidence register ready",
    "phase4-legal-compliance-evidence-rc1",
    "not legal advice",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Evidence Objective",
    "Required Evidence Gates",
    "legal_classification_review",
    "registration_and_msb_analysis",
    "aml_kyc_program_review",
    "sanctions_screening_review",
    "privacy_and_data_retention_review",
    "custody_and_safeguarding_review",
    "institution_agreement_review",
    "security_architecture_review",
    "penetration_test_scope",
    "incident_response_and_dr_review",
    "production_cost_estimate_review",
    "terraform_plan_review",
    "executive_go_live_approval",
    'Every evidence gate starts as `blocked`',
    "Evidence Fields",
    "Reviewer Requirements",
    "qualified_external_legal_counsel",
    "independent_security_reviewer",
    "Production Blockers",
    "Non-Enablement",
    "Legal classification approval",
    "External institution onboarding",
    "Real-value settlement",
    "No Google Cloud resources are created or changed"
)) {
    if ($legalComplianceEvidence -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 legal/compliance evidence content: $expected"
    }
}

$phase4Wrapup = Get-Content "PHASE4_WRAPUP.md" -Raw
foreach ($expected in @(
    "Status: sandbox pre-production readiness complete",
    "phase4-wrapup-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Completed Phase 4 Checkpoints",
    "phase4-pre-production-readiness-rc1",
    "phase4-cost-model-rc1",
    "phase4-security-review-scope-rc1",
    "phase4-hsm-kms-implementation-plan-rc1",
    "phase4-prod-ingress-implementation-plan-rc1",
    "phase4-dr-readiness-rc1",
    "phase4-legal-compliance-evidence-rc1",
    "Phase 4 Result",
    "No-GKE pre-production readiness gates",
    "Aggregate Phase 4 validator coverage",
    "Production approval",
    "Legal advice",
    "Real-value capability",
    'Ready to move into `phase5a-no-gke-validator-hardening`',
    'GKE remains deferred to `phase5b-gke-validator-ops`',
    "Required Blocks That Remain",
    "Legal classification approval",
    "Executive go-live approval",
    "Non-Enablement",
    "No Google Cloud resources are created or changed"
)) {
    if ($phase4Wrapup -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 wrap-up content: $expected"
    }
}

$config = Get-Content "config/phase4-pre-production-readiness.yaml" -Raw
foreach ($expected in @(
    "phase: phase-4-pre-production-readiness",
    "release_candidate: phase4-pre-production-readiness-rc1",
    "status: readiness_planning_started",
    "inherits_from: phase3-wrapup-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "enables_gke_validator_operations: false",
    "enables_hsm_or_kms_signing: false",
    "enables_production_ingress: false",
    "enables_real_value_settlement: false",
    "authorizes_external_institution_onboarding: false",
    "id: phase2-lean-no-gke",
    "validator_runtime: cloud_run_job_plus_cloud_scheduler",
    "gke_enabled: false",
    "readiness_gates:",
    "legal_classification_review:",
    "registration_and_msb_analysis:",
    "aml_kyc_program_review:",
    "sanctions_screening_review:",
    "privacy_and_data_retention_review:",
    "custody_and_safeguarding_review:",
    "institution_agreement_review:",
    "security_architecture_review:",
    "penetration_test_scope:",
    "incident_response_and_dr_review:",
    "production_cost_estimate_review:",
    "terraform_plan_review:",
    "executive_go_live_approval:",
    "status: blocked",
    "required_before_paid_resource_apply: true",
    "required_before_gke_apply: true",
    "gke_estimate_separate: true",
    "future_gke_validator_operations",
    "phase5a_no_gke_validator_hardening:",
    "gke_required: false",
    "phase5b_gke_validator_ops:",
    "gke_required: true",
    "gke_cluster_enabled: false",
    "production_bft_validator_network_enabled: false",
    "production_ingress_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "external_institution_onboarding_enabled: false",
    "real_value_settlement_enabled: false",
    "production_go_live_allowed: false",
    "no_google_cloud_resources_created: true",
    "no_paid_production_resources_enabled: true",
    "no_gke_enabled: true",
    "no_real_value_capability_enabled: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 readiness config content: $expected"
    }
}

$costConfig = Get-Content "config/phase4-cost-model.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-cost-model-rc1",
    "status: cost_model_ready",
    "inherits_from: phase4-pre-production-readiness-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "enables_gke_validator_operations: false",
    "fixed_live_prices_recorded: false",
    "live_pricing_must_be_checked_before_apply: true",
    "current_no_gke_baseline:",
    "cloud_run_api:",
    "cloud_run_validator_job:",
    "cloud_sql_postgresql_ledger:",
    "deferred_estimates:",
    "production_ingress:",
    "hsm_kms_signing:",
    "gke_validator_operations:",
    "deferred_to: phase5b-gke-validator-ops",
    "scenario_matrix:",
    "sandbox_minimal:",
    "preprod_no_gke:",
    "validator_ops_gke_lab:",
    "approval_gates:",
    "phase5a_remains_no_gke: true",
    "google_cloud_resource_creation_allowed: false",
    "paid_resource_enablement_allowed: false",
    "gke_cluster_enabled: false",
    "production_ingress_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_cost_model: true"
)) {
    if ($costConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 cost model config content: $expected"
    }
}

$securityConfig = Get-Content "config/phase4-security-review-scope.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-security-review-scope-rc1",
    "status: security_scope_ready",
    "inherits_from: phase4-cost-model-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "penetration_test_execution_allowed: false",
    "production_target_testing_allowed: false",
    "external_institution_testing_allowed: false",
    "enables_gke_validator_operations: false",
    "enables_public_endpoint_exposure: false",
    "review_objectives:",
    "gke_deferred_to_phase5b_confirmation",
    "in_scope_assets:",
    "out_of_scope:",
    "threat_areas:",
    "test_evidence_requirements:",
    "forbidden_evidence:",
    "review_workstreams:",
    "api_authorization_review:",
    "deferred_gke_hsm_ingress_review:",
    "google_cloud_resource_creation_allowed: false",
    "gke_cluster_enabled: false",
    "public_endpoint_exposure_enabled: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_security_scope: true"
)) {
    if ($securityConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 security review scope config content: $expected"
    }
}

$hsmKmsConfig = Get-Content "config/phase4-hsm-kms-implementation-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-hsm-kms-implementation-plan-rc1",
    "status: implementation_plan_ready",
    "inherits_from: phase4-security-review-scope-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "creates_kms_key_ring: false",
    "creates_kms_crypto_key: false",
    "creates_hsm_key: false",
    "deploys_signing_service: false",
    "enables_kms_hsm_signing: false",
    "target_signing_purposes:",
    "validator_block_signing:",
    "treasury_asset_authority:",
    "implementation_stages:",
    "stage_0_design_only:",
    "stage_6_production_candidate:",
    "signing_request_contract:",
    "private_keys_exportable: false",
    "key_lifecycle:",
    "required_gates_before_apply:",
    "terraform_boundary:",
    "design_file: infra/terraform/phase4_hsm_kms_implementation_plan.tf",
    "guard_variable: phase4_hsm_kms_implementation_enabled",
    "declares_google_cloud_resources: false",
    "output_only: true",
    "kms_key_ring_created: false",
    "signing_service_deployed: false",
    "phase4_validator_includes_hsm_kms_plan: true"
)) {
    if ($hsmKmsConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS implementation plan config content: $expected"
    }
}

$prodIngressConfig = Get-Content "config/phase4-prod-ingress-implementation-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-prod-ingress-implementation-plan-rc1",
    "status: implementation_plan_ready",
    "inherits_from: phase4-hsm-kms-implementation-plan-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "creates_external_https_load_balancer: false",
    "creates_api_gateway: false",
    "creates_reserved_static_ip: false",
    "creates_dns_record: false",
    "creates_certificate_manager_certificate: false",
    "creates_certificate_manager_trust_config: false",
    "applies_cloud_armor_policy: false",
    "changes_cloud_run_ingress: false",
    "enables_institution_mtls: false",
    "enables_public_endpoint_exposure: false",
    "target_components:",
    "external_https_load_balancer_or_api_gateway_decision:",
    "serverless_neg_to_cloud_run_api:",
    "certificate_manager_tls_certificate:",
    "certificate_manager_trust_config:",
    "institution_mtls:",
    "cloud_armor_waf:",
    "admin_oidc:",
    "private_cloud_run_ingress:",
    "request_paths:",
    "institution_api_path:",
    "admin_api_path:",
    "validator_internal_path:",
    "health_path:",
    "implementation_stages:",
    "stage_0_design_only:",
    "stage_6_production_candidate:",
    "required_gates_before_apply:",
    "terraform_boundary:",
    "design_file: infra/terraform/phase4_prod_ingress_implementation_plan.tf",
    "guard_variable: phase4_prod_ingress_implementation_enabled",
    "guard_default: false",
    "declares_google_cloud_resources: false",
    "output_only: true",
    "iam_boundary:",
    "allUsers",
    "allAuthenticatedUsers",
    "external_https_load_balancer_created: false",
    "api_gateway_created: false",
    "dns_record_created: false",
    "certificate_manager_certificate_created: false",
    "certificate_manager_trust_config_created: false",
    "institution_mtls_enabled: false",
    "cloud_armor_waf_applied: false",
    "cloud_run_ingress_changed: false",
    "public_endpoint_exposure_enabled: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_prod_ingress_plan: true"
)) {
    if ($prodIngressConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress implementation plan config content: $expected"
    }
}

$drReadinessConfig = Get-Content "config/phase4-dr-readiness.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-dr-readiness-rc1",
    "status: dr_readiness_ready",
    "inherits_from: phase4-prod-ingress-implementation-plan-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "executes_restore_drill: false",
    "creates_restore_instance: false",
    "changes_cloud_sql_backup_configuration: false",
    "creates_cross_region_replica: false",
    "creates_archive_bucket: false",
    "changes_validator_scheduler: false",
    "promotes_restored_database: false",
    "executes_production_recovery: false",
    "recovery_domains:",
    "ledger_database:",
    "ledger_integrity:",
    "api_runtime:",
    "validator_runtime:",
    "secrets_and_credentials:",
    "artifact_and_config:",
    "audit_and_reporting:",
    "operator_runbooks:",
    "target_rto_rpo:",
    "sandbox_no_gke:",
    "target_rto: 4h",
    "target_rpo: 15m",
    "preprod_no_gke_candidate:",
    "production_candidate:",
    "evidence_drills:",
    "backup_configuration_inventory:",
    "pitr_restore_to_separate_instance:",
    "ledger_reconciliation_check:",
    "validator_recovery_check:",
    "post_drill_report:",
    "restore_runbook:",
    "required_gates_before_drill_execution:",
    "terraform_boundary:",
    "design_file: infra/terraform/phase4_dr_readiness.tf",
    "guard_variable: phase4_dr_readiness_enabled",
    "guard_default: false",
    "declares_google_cloud_resources: false",
    "output_only: true",
    "restore_drill_executed: false",
    "restore_instance_created: false",
    "cloud_sql_backup_configuration_changed: false",
    "production_recovery_executed: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_dr_readiness: true"
)) {
    if ($drReadinessConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 DR readiness config content: $expected"
    }
}

$legalComplianceConfig = Get-Content "config/phase4-legal-compliance-evidence.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-legal-compliance-evidence-rc1",
    "status: evidence_register_ready",
    "inherits_from: phase4-dr-readiness-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "legal_advice: false",
    "requires_external_legal_review: true",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "enables_external_institution_onboarding: false",
    "enables_real_value_settlement: false",
    "approval_boundary:",
    "legal_advice_provided: false",
    "legal_classification_approved: false",
    "registration_analysis_approved: false",
    "aml_kyc_program_approved: false",
    "sanctions_screening_approved: false",
    "privacy_review_approved: false",
    "custody_safeguarding_approved: false",
    "institution_agreement_approved: false",
    "executive_go_live_approved: false",
    "production_authorization_granted: false",
    "evidence_requirements:",
    "required_status_before_production: approved",
    "named_owner_required: true",
    "qualified_external_legal_review_required: true",
    "independent_security_review_required: true",
    "reviewer_roles:",
    "qualified_external_legal_counsel",
    "compliance_officer",
    "privacy_officer",
    "independent_security_reviewer",
    "executive_approver",
    "evidence_register:",
    "legal_classification_review:",
    "registration_and_msb_analysis:",
    "aml_kyc_program_review:",
    "sanctions_screening_review:",
    "privacy_and_data_retention_review:",
    "custody_and_safeguarding_review:",
    "institution_agreement_review:",
    "security_architecture_review:",
    "penetration_test_scope:",
    "incident_response_and_dr_review:",
    "production_cost_estimate_review:",
    "terraform_plan_review:",
    "executive_go_live_approval:",
    "approval_status: blocked",
    "owner: unassigned",
    "evidence_location: pending",
    "approval_date: pending",
    "residual_risk: pending",
    "fintrac_msb_analysis",
    "suspicious_activity_escalation",
    "cross_border_data_flow_review",
    "terraform_plan_output",
    "signed_go_live_record",
    "external_institution_onboarding_enabled: false",
    "production_go_live_allowed: false",
    "phase4_validator_includes_legal_compliance_evidence: true"
)) {
    if ($legalComplianceConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 legal/compliance evidence config content: $expected"
    }
}

$phase4WrapupConfig = Get-Content "config/phase4-wrapup.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-wrapup-rc1",
    "status: sandbox_pre_production_readiness_complete",
    "inherits_from: phase4-legal-compliance-evidence-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "next_phase: phase5a-no-gke-validator-hardening",
    "gke_phase: phase5b-gke-validator-ops",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "completed_release_candidates:",
    "phase4_pre_production_readiness_rc1: true",
    "phase4_cost_model_rc1: true",
    "phase4_security_review_scope_rc1: true",
    "phase4_hsm_kms_implementation_plan_rc1: true",
    "phase4_prod_ingress_implementation_plan_rc1: true",
    "phase4_dr_readiness_rc1: true",
    "phase4_legal_compliance_evidence_rc1: true",
    "phase_result:",
    "no_gke_preprod_readiness_complete: true",
    "planning_and_evidence_only: true",
    "production_ready: false",
    "real_value_ready: false",
    "legal_advice_provided: false",
    "google_cloud_resources_created: false",
    "paid_resources_created: false",
    "terraform_apply_allowed: false",
    "phase5a_ready_to_start: true",
    "phase5b_gke_deferred: true",
    "phase5a_scope:",
    "gke_required: false",
    "validator_runtime: cloud_run_job_plus_cloud_scheduler",
    "remaining_blocked_gates:",
    "legal_classification_review: blocked",
    "executive_go_live_approval: blocked",
    "non_enablement:",
    "gke_cluster_enabled: false",
    "production_ingress_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "external_institution_onboarding_enabled: false",
    "production_authorization_granted: false",
    "legal_or_compliance_approval_enabled: false",
    "real_value_settlement_enabled: false",
    "terraform_apply_allowed: false",
    "google_cloud_resource_creation_allowed: false",
    "production_go_live_allowed: false",
    "aggregate_phase4_validator_includes_wrapup: true"
)) {
    if ($phase4WrapupConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 wrap-up config content: $expected"
    }
}

$hsmKmsTerraform = Get-Content "infra/terraform/phase4_hsm_kms_implementation_plan.tf" -Raw
foreach ($expected in @(
    'variable "phase4_hsm_kms_implementation_enabled"',
    "default     = false",
    "phase4-hsm-kms-implementation-plan-rc1",
    "creates_paid_resources         = false",
    "changes_google_cloud_resources = false",
    "production_signing_enabled     = false",
    "validator_block_signing",
    "treasury_asset_authority",
    "stage_0_design_only",
    "google_kms_key_ring",
    'output "phase4_hsm_kms_implementation_plan"'
)) {
    if ($hsmKmsTerraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS Terraform design content: $expected"
    }
}

$prodIngressTerraform = Get-Content "infra/terraform/phase4_prod_ingress_implementation_plan.tf" -Raw
foreach ($expected in @(
    'variable "phase4_prod_ingress_implementation_enabled"',
    "default     = false",
    "phase4-prod-ingress-implementation-plan-rc1",
    "active_runtime_baseline        = `"phase2-lean-no-gke`"",
    "creates_paid_resources         = false",
    "changes_google_cloud_resources = false",
    "creates_real_value_capability  = false",
    "public_endpoint_exposure       = false",
    "production_ingress_enabled     = false",
    "institution_api_path",
    "admin_api_path",
    "validator_internal_path",
    "stage_0_design_only",
    "stage_3_mtls_trust_design",
    "google_compute_global_address",
    "google_certificate_manager_certificate",
    "google_certificate_manager_trust_config",
    "google_api_gateway_api",
    "google_dns_record_set",
    'output "phase4_prod_ingress_implementation_plan"'
)) {
    if ($prodIngressTerraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress Terraform design content: $expected"
    }
}

$drReadinessTerraform = Get-Content "infra/terraform/phase4_dr_readiness.tf" -Raw
foreach ($expected in @(
    'variable "phase4_dr_readiness_enabled"',
    "default     = false",
    "phase4-dr-readiness-rc1",
    "active_runtime_baseline        = `"phase2-lean-no-gke`"",
    "creates_paid_resources         = false",
    "changes_google_cloud_resources = false",
    "creates_real_value_capability  = false",
    "restore_drill_executed         = false",
    "restore_instance_created       = false",
    "production_recovery_enabled    = false",
    "ledger_database",
    "ledger_integrity",
    "backup_configuration_inventory",
    "pitr_restore_to_separate_instance",
    "google_sql_database_instance_restore_target",
    "google_sql_backup_restore",
    "google_storage_bucket_archive",
    'output "phase4_dr_readiness"'
)) {
    if ($drReadinessTerraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 DR readiness Terraform design content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "paid_resources_created",
    "changes_google_cloud_resources",
    "google_cloud_resources_created",
    "production_ready",
    "real_value_ready",
    "enables_gke_validator_operations",
    "enables_hsm_or_kms_signing",
    "enables_production_ingress",
    "enables_external_institution_onboarding",
    "enables_real_value_settlement",
    "authorizes_external_institution_onboarding",
    "legal_advice_provided",
    "legal_classification_approved",
    "registration_analysis_approved",
    "aml_kyc_program_approved",
    "sanctions_screening_approved",
    "privacy_review_approved",
    "custody_safeguarding_approved",
    "institution_agreement_approved",
    "security_architecture_approved",
    "penetration_test_approved",
    "production_cost_approved",
    "terraform_plan_approved",
    "executive_go_live_approved",
    "production_authorization_granted",
    "legal_or_compliance_approval_enabled",
    "gke_enabled",
    "gke_cluster_enabled",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "creates_external_https_load_balancer",
    "creates_api_gateway",
    "creates_reserved_static_ip",
    "creates_dns_record",
    "creates_certificate_manager_certificate",
    "creates_certificate_manager_trust_config",
    "applies_cloud_armor_policy",
    "changes_cloud_run_ingress",
    "enables_institution_mtls",
    "enables_public_endpoint_exposure",
    "executes_restore_drill",
    "creates_restore_instance",
    "changes_cloud_sql_backup_configuration",
    "creates_cross_region_replica",
    "creates_archive_bucket",
    "changes_validator_scheduler",
    "promotes_restored_database",
    "executes_production_recovery",
    "external_https_load_balancer_created",
    "api_gateway_created",
    "reserved_static_ip_created",
    "dns_record_created",
    "certificate_manager_certificate_created",
    "certificate_manager_trust_config_created",
    "cloud_armor_waf_applied",
    "cloud_armor_rate_limits_applied",
    "mtls_trust_config_applied",
    "institution_mtls_enabled",
    "cloud_run_ingress_changed",
    "public_endpoint_exposure_enabled",
    "restore_drill_executed",
    "restore_instance_created",
    "cloud_sql_backup_configuration_changed",
    "cross_region_replica_created",
    "archive_bucket_created",
    "validator_scheduler_changed",
    "restored_database_promoted",
    "production_recovery_executed",
    "hsm_kms_production_signing_enabled",
    "external_institution_onboarding_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 readiness must not enable $forbidden"
    }
    if ($costConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 cost model must not enable $forbidden"
    }
    if ($securityConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 security review scope must not enable $forbidden"
    }
    if ($hsmKmsConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 HSM/KMS implementation plan must not enable $forbidden"
    }
    if ($prodIngressConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 production ingress implementation plan must not enable $forbidden"
    }
    if ($drReadinessConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 DR readiness must not enable $forbidden"
    }
    if ($legalComplianceConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 legal/compliance evidence must not enable $forbidden"
    }
    if ($phase4WrapupConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 wrap-up must not enable $forbidden"
    }
}

if ($costConfig -match "(?m)^\s*terraform_apply_allowed:\s+true\s*$") {
    throw "Phase 4 cost model must not allow Terraform apply"
}

if ($securityConfig -match "(?m)^\s*penetration_test_execution_allowed:\s+true\s*$") {
    throw "Phase 4 security review scope must not allow penetration test execution"
}

if ($securityConfig -match "(?m)^\s*production_target_testing_allowed:\s+true\s*$") {
    throw "Phase 4 security review scope must not allow production target testing"
}

if ($hsmKmsConfig -match "(?m)^\s*enables_kms_hsm_signing:\s+true\s*$") {
    throw "Phase 4 HSM/KMS implementation plan must not enable KMS/HSM signing"
}

if ($prodIngressConfig -match "(?m)^\s*terraform_apply_allowed:\s+true\s*$") {
    throw "Phase 4 production ingress implementation plan must not allow Terraform apply"
}

if ($prodIngressConfig -match "(?m)^\s*enables_public_endpoint_exposure:\s+true\s*$") {
    throw "Phase 4 production ingress implementation plan must not enable public endpoint exposure"
}

if ($prodIngressConfig -match "(?m)^\s*production_ingress_enabled:\s+true\s*$") {
    throw "Phase 4 production ingress implementation plan must not enable production ingress"
}

if ($drReadinessConfig -match "(?m)^\s*terraform_apply_allowed:\s+true\s*$") {
    throw "Phase 4 DR readiness must not allow Terraform apply"
}

if ($drReadinessConfig -match "(?m)^\s*executes_restore_drill:\s+true\s*$") {
    throw "Phase 4 DR readiness must not execute restore drills"
}

if ($drReadinessConfig -match "(?m)^\s*creates_restore_instance:\s+true\s*$") {
    throw "Phase 4 DR readiness must not create restore instances"
}

if ($drReadinessConfig -match "(?m)^\s*executes_production_recovery:\s+true\s*$") {
    throw "Phase 4 DR readiness must not execute production recovery"
}

if ($legalComplianceConfig -match "(?m)^\s*legal_advice_provided:\s+true\s*$") {
    throw "Phase 4 legal/compliance evidence must not provide legal advice"
}

if ($legalComplianceConfig -match "(?m)^\s*legal_classification_approved:\s+true\s*$") {
    throw "Phase 4 legal/compliance evidence must not approve legal classification"
}

if ($legalComplianceConfig -match "(?m)^\s*production_authorization_granted:\s+true\s*$") {
    throw "Phase 4 legal/compliance evidence must not grant production authorization"
}

$legalComplianceBlockedGateCount = ([regex]::Matches($legalComplianceConfig, "approval_status:\s+blocked")).Count
if ($legalComplianceBlockedGateCount -lt 13) {
    throw "Expected at least 13 blocked legal/compliance evidence gates, found $legalComplianceBlockedGateCount"
}

$phase4CompletedCount = ([regex]::Matches($phase4WrapupConfig, "phase4_[a-z0-9_]+_rc1:\s+true")).Count
if ($phase4CompletedCount -lt 7) {
    throw "Expected at least 7 completed Phase 4 release candidates, found $phase4CompletedCount"
}

$phase4BlockedGateCount = ([regex]::Matches($phase4WrapupConfig, ":\s+blocked")).Count
if ($phase4BlockedGateCount -lt 13) {
    throw "Expected at least 13 blocked Phase 4 wrap-up gates, found $phase4BlockedGateCount"
}

if ($phase4WrapupConfig -match "(?m)^\s*production_ready:\s+true\s*$") {
    throw "Phase 4 wrap-up must not mark production ready"
}

if ($phase4WrapupConfig -match "(?m)^\s*real_value_ready:\s+true\s*$") {
    throw "Phase 4 wrap-up must not mark real value ready"
}

if ($hsmKmsTerraform -match 'resource\s+"google_') {
    throw "phase4_hsm_kms_implementation_plan.tf must remain design-only and must not declare Google Cloud resources"
}

if ($prodIngressTerraform -match 'resource\s+"google_') {
    throw "phase4_prod_ingress_implementation_plan.tf must remain design-only and must not declare Google Cloud resources"
}

if ($drReadinessTerraform -match 'resource\s+"google_') {
    throw "phase4_dr_readiness.tf must remain design-only and must not declare Google Cloud resources"
}

if ($costConfig -match "(?m)^\s*fixed_live_prices_recorded:\s+true\s*$") {
    throw "Phase 4 cost model must not record fixed live prices"
}

$gateCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($gateCount -lt 13) {
    throw "Expected at least 13 readiness gates, found $gateCount"
}

[pscustomobject]@{
    phase = "phase-4-pre-production-readiness"
    release_candidate = "phase4-pre-production-readiness-rc1"
    status = "readiness-planning-started"
    track = "phase4-no-gke-preprod-readiness"
    readiness_gate_count = 13
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    gke_enabled = $false
    hsm_kms_signing_enabled = $false
    production_ingress_enabled = $false
    real_value_capability_enabled = $false
    phase5a_no_gke_available = $true
    phase5b_gke_deferred = $true
    cost_model_rc1 = $true
    security_review_scope_rc1 = $true
    hsm_kms_implementation_plan_rc1 = $true
    prod_ingress_implementation_plan_rc1 = $true
    dr_readiness_rc1 = $true
    legal_compliance_evidence_rc1 = $true
    wrapup_rc1 = $true
    next_phase = "phase5a-no-gke-validator-hardening"
    result = "ok"
}
