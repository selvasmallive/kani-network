$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE3_ENTERPRISE_PLAN.md",
    "PHASE3_INSTITUTION_MODEL.md",
    "PHASE3_COMPLIANCE_CASES.md",
    "PHASE3_CONSENSUS_INTERFACE.md",
    "PHASE3_BFT_PROTOTYPE.md",
    "PHASE3_PROD_EDGE_DESIGN.md",
    "PHASE3_KEY_MANAGEMENT_DESIGN.md",
    "PHASE3_REGULATORY_READINESS_GATE.md",
    "PHASE3_AUDIT_REPORTING_HARDENING.md",
    "PHASE3_OPERATIONAL_RUNBOOKS.md",
    "config/phase3-enterprise.yaml",
    "config/phase3-regulatory-readiness.yaml",
    "config/phase3-audit-reporting.yaml",
    "config/phase3-operational-runbooks.yaml",
    "scripts/phase3-validate.ps1",
    "scripts/phase3-regulatory-readiness-gate.ps1",
    "scripts/phase3-audit-reporting-hardening.ps1",
    "scripts/phase3-operational-runbooks.ps1",
    "infra/terraform/phase3_prod_edge_design.tf",
    "infra/terraform/phase3_key_management_design.tf",
    "PHASE2_OBSERVATION_REPORT.md",
    "openapi/kani-api.v1.json",
    "migrations/0002_phase3_institutions.sql",
    "migrations/0009_phase3_compliance_cases.sql"
)

$missing = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 3 files: $($missing -join ', ')"
}

$plan = Get-Content "PHASE3_ENTERPRISE_PLAN.md" -Raw
foreach ($expected in @(
    "Status: implementation started",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Consensus Evolution",
    "Institution Onboarding",
    "Compliance Workflow",
    "Production Ingress And mTLS",
    "Key Management And Crypto Agility",
    "Regulatory And Legal Readiness",
    "Data, Audit, And Reporting",
    "Operational Readiness And Runbooks",
    "phase3-institution-model-rc1",
    "phase3-compliance-cases-rc1",
    "phase3-consensus-interface-rc1",
    "phase3-bft-prototype-rc1",
    "phase3-prod-edge-design-rc1",
    "phase3-key-management-design-rc1",
    "phase3-regulatory-readiness-gate-rc1",
    "phase3-audit-reporting-hardening-rc1",
    "phase3-operational-runbooks-rc1",
    "No GKE, production ingress, HSM, or real-value resources are created",
    "PHASE3_INSTITUTION_MODEL.md",
    "PHASE3_COMPLIANCE_CASES.md",
    "PHASE3_CONSENSUS_INTERFACE.md",
    "PHASE3_BFT_PROTOTYPE.md",
    "PHASE3_PROD_EDGE_DESIGN.md",
    "PHASE3_KEY_MANAGEMENT_DESIGN.md",
    "PHASE3_REGULATORY_READINESS_GATE.md",
    "PHASE3_AUDIT_REPORTING_HARDENING.md",
    "PHASE3_OPERATIONAL_RUNBOOKS.md"
)) {
    if ($plan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 plan content in PHASE3_ENTERPRISE_PLAN.md: $expected"
    }
}

$institutionModel = Get-Content "PHASE3_INSTITUTION_MODEL.md" -Raw
foreach ($expected in @(
    "Status: implementation slice ready",
    "phase3-institution-model-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "KANI_TREASURY",
    "CORP_A",
    "CORP_B",
    "GET  /v1/admin/institutions",
    "POST /v1/admin/institutions",
    "POST /v1/admin/institutions/{id}/credentials",
    "POST /v1/admin/institutions/{id}/suspend",
    "POST /v1/admin/institutions/{id}/limits",
    "Suspended or otherwise non-approved institutions cannot operate accounts"
)) {
    if ($institutionModel -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution model content in PHASE3_INSTITUTION_MODEL.md: $expected"
    }
}

$complianceCases = Get-Content "PHASE3_COMPLIANCE_CASES.md" -Raw
foreach ($expected in @(
    "Status: implementation slice ready",
    "phase3-compliance-cases-rc1",
    "TransactionStatus::HELD",
    "ComplianceCase",
    "GET  /v1/compliance/cases",
    "POST /v1/compliance/cases/{id}/approve",
    "POST /v1/compliance/cases/{id}/reject",
    "keeps the transaction out of the validator pending queue"
)) {
    if ($complianceCases -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 compliance cases content in PHASE3_COMPLIANCE_CASES.md: $expected"
    }
}

$consensusInterface = Get-Content "PHASE3_CONSENSUS_INTERFACE.md" -Raw
foreach ($expected in @(
    "Status: implementation slice ready",
    "phase3-consensus-interface-rc1",
    "ConsensusEngine",
    "ConsensusEngineConfig",
    "ConfiguredConsensusEngine",
    "PoAConsensus",
    "ConsensusProposal",
    "ConsensusVote",
    "QuorumCertificate",
    "FinalityProof",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($consensusInterface -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 consensus interface content in PHASE3_CONSENSUS_INTERFACE.md: $expected"
    }
}

$bftPrototype = Get-Content "PHASE3_BFT_PROTOTYPE.md" -Raw
foreach ($expected in @(
    "Status: implementation slice ready",
    "phase3-bft-prototype-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "BftConsensus",
    "sandbox-bft-prototype",
    "ConsensusEngineConfig::sandbox_bft_prototype",
    "ConsensusProposal",
    "ConsensusVote",
    "PREVOTE",
    "PRECOMMIT",
    "QuorumCertificate",
    "FinalityProof",
    "strict greater-than-two-thirds finality",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($bftPrototype -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 BFT prototype content in PHASE3_BFT_PROTOTYPE.md: $expected"
    }
}

$prodEdgeDesign = Get-Content "PHASE3_PROD_EDGE_DESIGN.md" -Raw
foreach ($expected in @(
    "Status: design slice ready",
    "phase3-prod-edge-design-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "does not create paid edge resources",
    "infra/terraform/phase3_prod_edge_design.tf",
    "phase3_prod_edge_design_enabled",
    "External HTTPS load balancer or API Gateway",
    "Certificate Manager TLS certificate",
    "mTLS trust config",
    "Cloud Armor WAF",
    "private Cloud Run ingress mode",
    "allUsers",
    "allAuthenticatedUsers",
    "Cloud Run invoker grant",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($prodEdgeDesign -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 production edge design content in PHASE3_PROD_EDGE_DESIGN.md: $expected"
    }
}

$keyManagementDesign = Get-Content "PHASE3_KEY_MANAGEMENT_DESIGN.md" -Raw
foreach ($expected in @(
    "Status: design slice ready",
    "phase3-key-management-design-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "does not create KMS, HSM, or signing-service resources",
    "infra/terraform/phase3_key_management_design.tf",
    "phase3_key_management_design_enabled",
    "validator_block_signing",
    "treasury_asset_authority",
    "api_request_signing",
    "audit_log_signing",
    "iso20022_message_signing",
    "Private keys must not leave managed custody",
    "signing-service boundary",
    "pending",
    "compromised",
    "dual-control",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($keyManagementDesign -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 key management design content in PHASE3_KEY_MANAGEMENT_DESIGN.md: $expected"
    }
}

$regulatoryGate = Get-Content "PHASE3_REGULATORY_READINESS_GATE.md" -Raw
foreach ($expected in @(
    "Status: gate slice ready",
    "phase3-regulatory-readiness-gate-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "This is not legal advice",
    "production_go_live_allowed = false",
    "real_value_capability_allowed = false",
    "config/phase3-regulatory-readiness.yaml",
    "phase3-regulatory-readiness-gate.ps1",
    "legal_classification",
    "registration_analysis",
    "aml_kyc_program",
    "sanctions_process",
    "privacy_data_retention",
    "institution_agreements",
    "custody_safeguarding",
    "incident_response",
    "security_penetration_test",
    "production_go_live_approval",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($regulatoryGate -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 regulatory readiness gate content in PHASE3_REGULATORY_READINESS_GATE.md: $expected"
    }
}

$auditReportingHardening = Get-Content "PHASE3_AUDIT_REPORTING_HARDENING.md" -Raw
foreach ($expected in @(
    "Status: hardening slice ready",
    "phase3-audit-reporting-hardening-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "does not create paid resources",
    "settlement summary by asset, institution, block height, and settlement day",
    "immutable event identifiers and hash-chain readiness",
    "metadata_hash",
    "previous_event_hash",
    "event_hash",
    "Daily reconciliation must be reproducible",
    "Retention Matrix",
    "Export Controls",
    "admin authorization",
    "secrets and API keys",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($auditReportingHardening -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 audit/reporting hardening content in PHASE3_AUDIT_REPORTING_HARDENING.md: $expected"
    }
}

$operationalRunbooks = Get-Content "PHASE3_OPERATIONAL_RUNBOOKS.md" -Raw
foreach ($expected in @(
    "Status: operational slice ready",
    "phase3-operational-runbooks-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "technical_operator",
    "settlement_operator",
    "compliance_reviewer",
    "security_operator",
    "audit_reviewer",
    "release_approver",
    "Daily Operating Runbook",
    "Validator Operations",
    "Cloud Run Job plus Cloud Scheduler",
    "GKE validator operations remain deferred",
    "Incident Response",
    "SEV1",
    "Release And Rollback Runbook",
    "Backup And Restore Runbook",
    "Credential And Secret Rotation Runbook",
    "Audit Evidence Pack",
    "No Google Cloud resources are created",
    "No production or real-value operations are enabled",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($operationalRunbooks -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 operational runbook content in PHASE3_OPERATIONAL_RUNBOOKS.md: $expected"
    }
}

$config = Get-Content "config/phase3-enterprise.yaml" -Raw
foreach ($expected in @(
    "phase: phase-3-enterprise",
    "inherits_from: phase2-lean-no-gke",
    "real_value: false",
    "production_value_movement_allowed: false",
    "consensus:",
    "target: BFT",
    "institution_onboarding:",
    "InstitutionCredential",
    "compliance:",
    "target_profile: enterprise-policy-versioned",
    "ingress:",
    "institution_mtls",
    "allUsers",
    "key_management:",
    "dual_control_key_ceremony",
    "regulatory_readiness:",
    "requires_external_review: true",
    "creates_paid_resources: false",
    "creates_real_value_capability: false",
    "phase3_institution_model_rc1:",
    "migrations/0002_phase3_institutions.sql",
    "suspended_institutions_cannot_operate_accounts",
    "phase3_compliance_cases_rc1:",
    "migrations/0009_phase3_compliance_cases.sql",
    "held_payments_are_not_validator_pending",
    "approved_cases_release_payment_to_pending",
    "rejected_cases_mark_payment_rejected",
    "phase3_consensus_interface_rc1:",
    "default_engine: phase1-poa",
    "ConsensusEngine trait",
    "production finality claims",
    "phase3_bft_prototype_rc1:",
    "sandbox_engine: sandbox-bft-prototype",
    "BftConsensus sandbox prototype",
    "ConsensusEngineConfig::sandbox_bft_prototype",
    "strict greater-than-two-thirds quorum tests",
    "bft_enabled_by_default: false",
    "validator peer networking",
    "phase3_prod_edge_design_rc1:",
    "status: design_ready",
    "terraform_design_file: infra/terraform/phase3_prod_edge_design.tf",
    "guard_variable: phase3_prod_edge_design_enabled",
    "guard_default: false",
    "declares_google_cloud_resources: false",
    "global_external_https_load_balancer_or_api_gateway",
    "certificate_manager_trust_config",
    "cloud_armor_waf",
    "private_cloud_run_ingress",
    "admin_oidc",
    "load_balancer_apply",
    "phase3_key_management_design_rc1:",
    "status: design_ready",
    "terraform_design_file: infra/terraform/phase3_key_management_design.tf",
    "guard_variable: phase3_key_management_design_enabled",
    "guard_default: false",
    "declares_google_cloud_resources: false",
    "crypto_profile: hybrid-pqc-v1",
    "validator_block_signing",
    "treasury_asset_authority",
    "audit_log_signing",
    "canonical_signing_request",
    "two_operator_key_creation_approval",
    "emergency_revocation_break_glass_path",
    "kms_key_ring_apply",
    "phase3_regulatory_readiness_gate_rc1:",
    "status: gate_ready",
    "gate_status: blocked",
    "gate_config: config/phase3-regulatory-readiness.yaml",
    "gate_script: scripts/phase3-regulatory-readiness-gate.ps1",
    "production_go_live_allowed: false",
    "real_value_capability_allowed: false",
    "external_customer_access_allowed: false",
    "fiat_deposit_or_redemption_allowed: false",
    "custody_for_others_allowed: false",
    "trading_allowed: false",
    "signed_approval_record",
    "legal_determinations",
    "phase3_audit_reporting_hardening_rc1:",
    "status: hardening_ready",
    "hardening_config: config/phase3-audit-reporting.yaml",
    "hardening_script: scripts/phase3-audit-reporting-hardening.ps1",
    "production_reporting_enabled: false",
    "external_report_delivery_enabled: false",
    "real_value_reporting_ready: false",
    "audit_event_export",
    "metadata_hash",
    "previous_event_hash",
    "event_hash",
    "reconciliation_sources:",
    "finalized_blocks",
    "issued_supply",
    "admin_authorization_required",
    "privacy_legal_review_required",
    "production_hash_chain_enforcement",
    "legal_approved_retention_periods",
    "phase3_operational_runbooks_rc1:",
    "status: operational_runbooks_ready",
    "runbook_config: config/phase3-operational-runbooks.yaml",
    "runbook_script: scripts/phase3-operational-runbooks.ps1",
    "production_operations_enabled: false",
    "changes_google_cloud_resources: false",
    "cloud_run_job_scheduler_no_gke",
    "required_finality_votes: 2",
    "gke_deferred: true",
    "daily_operations",
    "validator_operations",
    "incident_response",
    "release_rollback",
    "backup_restore",
    "credential_rotation",
    "audit_evidence_pack",
    "gke_multi_node_validator_runbooks",
    "real_value_incident_response"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 config content in config/phase3-enterprise.yaml: $expected"
    }
}

$readme = Get-Content "README.md" -Raw
foreach ($expected in @(
    "PHASE3_ENTERPRISE_PLAN.md",
    "PHASE3_INSTITUTION_MODEL.md",
    "PHASE3_COMPLIANCE_CASES.md",
    "PHASE3_CONSENSUS_INTERFACE.md",
    "PHASE3_BFT_PROTOTYPE.md",
    "PHASE3_PROD_EDGE_DESIGN.md",
    "PHASE3_KEY_MANAGEMENT_DESIGN.md",
    "PHASE3_REGULATORY_READINESS_GATE.md",
    "PHASE3_AUDIT_REPORTING_HARDENING.md",
    "PHASE3_OPERATIONAL_RUNBOOKS.md",
    "phase3-validate.ps1",
    "POST /v1/admin/institutions",
    "POST /v1/admin/institutions/{id}/suspend",
    "GET  /v1/compliance/cases",
    "POST /v1/compliance/cases/{id}/approve",
    "ConsensusEngine",
    "BftConsensus",
    "ConsensusEngineConfig::sandbox_bft_prototype",
    "phase3_prod_edge_design.tf",
    "phase3_prod_edge_design_enabled",
    "phase3_key_management_design.tf",
    "phase3_key_management_design_enabled",
    "phase3-regulatory-readiness-gate.ps1",
    "phase3-audit-reporting-hardening.ps1",
    "phase3-operational-runbooks.ps1",
    "Cloud Run Job plus Cloud Scheduler no-GKE topology"
)) {
    if ($readme -notmatch [regex]::Escape($expected)) {
        throw "Expected README.md Phase 3 content: $expected"
    }
}

$auditReportingConfig = Get-Content "config/phase3-audit-reporting.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase3-audit-reporting-hardening-rc1",
    "status: hardening_ready",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "creates_real_value_capability: false",
    "external_report_delivery_enabled: false",
    "production_reporting_enabled: false",
    "export_requires_admin_authorization: true",
    "settlement_summary:",
    "compliance_decisions:",
    "validator_finality:",
    "reconciliation:",
    "immutable_audit_contract:",
    "hash_chain_enforced: false",
    "signing_enforced: false",
    "event_id",
    "metadata_hash",
    "previous_event_hash",
    "event_hash",
    "retention_matrix:",
    "requires_legal_privacy_approval",
    "export_controls:",
    "secrets_redacted: true",
    "privacy_legal_review_required: true",
    "production_reporting_ready: false",
    "real_value_reporting_ready: false"
)) {
    if ($auditReportingConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 audit/reporting hardening config content: $expected"
    }
}

$auditReportingScript = Get-Content "scripts/phase3-audit-reporting-hardening.ps1" -Raw
foreach ($expected in @(
    "phase3-audit-reporting-hardening-rc1",
    "Production reporting must remain disabled",
    "External report delivery must remain disabled",
    "Real-value reporting must remain disabled",
    "immutable_audit_field_count",
    "production_reporting_enabled = `$false",
    "external_report_delivery_enabled = `$false",
    "real_value_reporting_ready = `$false"
)) {
    if ($auditReportingScript -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 audit/reporting hardening script content: $expected"
    }
}

$operationalRunbookConfig = Get-Content "config/phase3-operational-runbooks.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase3-operational-runbooks-rc1",
    "status: operational_runbooks_ready",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "production_operations_enabled: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "enables_gke_validator_operations: false",
    "technical_operator",
    "settlement_operator",
    "compliance_reviewer",
    "security_operator",
    "audit_reviewer",
    "release_approver",
    "daily_operations:",
    "validator_operations:",
    "cloud_run_job_scheduler_no_gke",
    "required_finality_votes: 2",
    "gke_deferred: true",
    "incident_response:",
    "SEV1",
    "release_rollback:",
    "cargo_clippy_workspace_deny_warnings",
    "backup_restore:",
    "restore_to_separate_target",
    "credential_rotation:",
    "confirm_no_secrets_in_logs_or_audit_exports",
    "audit_evidence_pack:",
    "no_google_cloud_resources_created: true",
    "no_production_operations_enabled: true",
    "no_real_value_operations_enabled: true"
)) {
    if ($operationalRunbookConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 operational runbook config content: $expected"
    }
}

$operationalRunbookScript = Get-Content "scripts/phase3-operational-runbooks.ps1" -Raw
foreach ($expected in @(
    "phase3-operational-runbooks-rc1",
    "Production operations must remain disabled",
    "Operational runbooks must not create paid resources",
    "Operational runbooks must not change Google Cloud resources",
    "GKE validator operations must remain deferred",
    "operator_role_count = 6",
    "runbook_count = 7",
    "production_operations_enabled = `$false"
)) {
    if ($operationalRunbookScript -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 operational runbook script content: $expected"
    }
}

$prodEdgeTerraform = Get-Content "infra/terraform/phase3_prod_edge_design.tf" -Raw
foreach ($expected in @(
    'variable "phase3_prod_edge_design_enabled"',
    "default     = false",
    "phase3-prod-edge-design-rc1",
    "creates_paid_resources        = false",
    "creates_real_value_capability = false",
    "global_external_https_load_balancer",
    "certificate_manager_trust_config",
    "institution_mtls",
    "cloud_armor_waf",
    "private_cloud_run_ingress",
    "admin_oidc",
    "forbidden_invokers",
    'output "phase3_prod_edge_design"'
)) {
    if ($prodEdgeTerraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 production edge Terraform design content: $expected"
    }
}

if ($prodEdgeTerraform -match 'resource\s+"google_') {
    throw "phase3_prod_edge_design.tf must remain design-only and must not declare Google Cloud resources in this slice"
}

$keyManagementTerraform = Get-Content "infra/terraform/phase3_key_management_design.tf" -Raw
foreach ($expected in @(
    'variable "phase3_key_management_design_enabled"',
    "default     = false",
    "phase3-key-management-design-rc1",
    "creates_paid_resources        = false",
    "creates_real_value_capability = false",
    "validator_block_signing",
    "treasury_asset_authority",
    "api_request_signing",
    "audit_log_signing",
    "iso20022_message_signing",
    "key_states",
    "signing_request_contract",
    "ceremony_gates",
    "two_operator_key_creation_approval",
    "google_kms_key_ring",
    "cloud_hsm_key_generation",
    'output "phase3_key_management_design"'
)) {
    if ($keyManagementTerraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 key management Terraform design content: $expected"
    }
}

if ($keyManagementTerraform -match 'resource\s+"google_') {
    throw "phase3_key_management_design.tf must remain design-only and must not declare Google Cloud resources in this slice"
}

$regulatoryGateConfig = Get-Content "config/phase3-regulatory-readiness.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase3-regulatory-readiness-gate-rc1",
    "status: blocked",
    "legal_advice: false",
    "requires_external_review: true",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "production_go_live_allowed: false",
    "real_value_capability_allowed: false",
    "external_customer_access_allowed: false",
    "fiat_deposit_or_redemption_allowed: false",
    "custody_for_others_allowed: false",
    "trading_allowed: false",
    "legal_classification:",
    "registration_analysis:",
    "aml_kyc_program:",
    "sanctions_process:",
    "privacy_data_retention:",
    "institution_agreements:",
    "custody_safeguarding:",
    "incident_response:",
    "security_penetration_test:",
    "production_go_live_approval:",
    "gate_status: blocked",
    "production_ready: false",
    "real_value_ready: false"
)) {
    if ($regulatoryGateConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 regulatory readiness gate config content: $expected"
    }
}

$regulatoryGateScript = Get-Content "scripts/phase3-regulatory-readiness-gate.ps1" -Raw
foreach ($expected in @(
    "phase3-regulatory-readiness-gate-rc1",
    "Production go-live must remain blocked",
    "Real-value capability must remain blocked",
    "required_gate_count",
    "production_go_live_allowed = `$false",
    "real_value_capability_allowed = `$false"
)) {
    if ($regulatoryGateScript -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 regulatory readiness gate script content: $expected"
    }
}

$observation = Get-Content "PHASE2_OBSERVATION_REPORT.md" -Raw
if ($observation -notmatch "Move into Phase 3 planning" -or $observation -notmatch "BFT consensus design boundary") {
    throw "Expected Phase 2 observation report to point to Phase 3 planning"
}

$types = Get-Content "crates/kani-types/src/lib.rs" -Raw
foreach ($expected in @(
    "pub struct Institution",
    "pub struct InstitutionCredential",
    "pub struct InstitutionLimit",
    "pub struct OnboardingCase",
    "pub struct ComplianceCase",
    "pub struct ComplianceCaseOpen",
    "pub enum ComplianceCaseStatus",
    "pub enum InstitutionStatus",
    "pub enum InstitutionCredentialStatus",
    "Held",
    "pub struct ConsensusProposal",
    "pub struct ConsensusVote",
    "pub struct QuorumCertificate",
    "pub struct FinalityProof",
    "pub struct ValidatorSet"
)) {
    if ($types -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution type in kani-types: $expected"
    }
}

$consensus = Get-Content "crates/kani-consensus/src/lib.rs" -Raw
foreach ($expected in @(
    "pub trait ConsensusEngine",
    "pub enum ConsensusAlgorithm",
    "pub struct ConsensusEngineConfig",
    "pub enum ConfiguredConsensusEngine",
    "impl ConsensusEngine for PoAConsensus",
    "pub struct BftConsensus",
    "impl ConsensusEngine for BftConsensus",
    "pub struct BftFinalityPrototype",
    "SANDBOX_BFT_ENGINE_ID",
    "sandbox_bft_prototype",
    "simulate_finality_proof",
    "verify_quorum_certificate",
    "verify_finality_proof",
    "phase1_default_validators",
    "UnsupportedEngine"
)) {
    if ($consensus -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 consensus interface support in kani-consensus: $expected"
    }
}

$ledger = Get-Content "crates/kani-ledger/src/lib.rs" -Raw
foreach ($expected in @(
    "UnknownInstitution",
    "upsert_institution",
    "institution_credentials",
    "institution_limits",
    "load_institution_credentials",
    "load_institution_limits",
    "hold_payment_for_review",
    "approve_compliance_case",
    "reject_compliance_case",
    "compliance_cases"
)) {
    if ($ledger -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution storage support in kani-ledger: $expected"
    }
}

$node = Get-Content "crates/kani-node/src/lib.rs" -Raw
foreach ($expected in @(
    "pub async fn institutions",
    "pub async fn upsert_institution",
    "pub async fn suspend_institution",
    "pub async fn institution_credentials",
    "pub async fn institution_limits",
    "pub async fn hold_payment_for_review",
    "pub async fn compliance_cases",
    "pub async fn approve_compliance_case",
    "pub async fn reject_compliance_case"
)) {
    if ($node -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution node support in kani-node: $expected"
    }
}

$nodeConsensusExpected = @(
    "ConfiguredConsensusEngine",
    "ConsensusEngineConfig::phase1_poa",
    "pub fn consensus(&self) -> &dyn ConsensusEngine",
    "consensus: &dyn ConsensusEngine",
    "sandbox_default_keeps_phase1_poa_consensus_engine"
)
foreach ($expected in $nodeConsensusExpected) {
    if ($node -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 consensus interface node support in kani-node: $expected"
    }
}

$api = Get-Content "crates/kani-api/src/lib.rs" -Raw
foreach ($expected in @(
    '"/v1/admin/institutions"',
    '"/v1/admin/institutions/:id/credentials"',
    '"/v1/admin/institutions/:id/suspend"',
    '"/v1/admin/institutions/:id/limits"',
    '"/v1/compliance/cases"',
    '"/v1/compliance/cases/:id/approve"',
    '"/v1/compliance/cases/:id/reject"',
    "InstitutionProfileResponse",
    "ComplianceCaseResponse",
    "ensure_institution_can_operate",
    "suspended_institution_cannot_authorize_account_control",
    "payment_submission_opens_compliance_case_for_manual_review"
)) {
    if ($api -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution API support in kani-api: $expected"
    }
}

$openapi = Get-Content "openapi/kani-api.v1.json" -Raw
foreach ($expected in @(
    '"/v1/compliance/cases"',
    '"/v1/compliance/cases/{id}/approve"',
    '"/v1/compliance/cases/{id}/reject"',
    '"ComplianceCase"',
    '"ComplianceCaseResponse"',
    '"PaginatedComplianceCaseResponse"',
    '"HELD"'
)) {
    if ($openapi -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 compliance OpenAPI content: $expected"
    }
}

$migration = Get-Content "migrations/0002_phase3_institutions.sql" -Raw
foreach ($expected in @(
    "CREATE TABLE IF NOT EXISTS institutions",
    "CREATE TABLE IF NOT EXISTS institution_credentials",
    "CREATE TABLE IF NOT EXISTS institution_limits"
)) {
    if ($migration -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution migration content: $expected"
    }
}

$complianceMigration = Get-Content "migrations/0009_phase3_compliance_cases.sql" -Raw
foreach ($expected in @(
    "CREATE TABLE IF NOT EXISTS compliance_cases",
    "'HELD'",
    "idx_compliance_cases_status"
)) {
    if ($complianceMigration -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 compliance migration content: $expected"
    }
}

[pscustomobject]@{
    phase = "phase-3-enterprise"
    status = "implementation-started"
    required_file_count = $requiredFiles.Count
    sandbox_boundary_checked = $true
    consensus_planning = $true
    institution_onboarding_planning = $true
    compliance_workflow_planning = $true
    ingress_mtls_planning = $true
    key_management_planning = $true
    regulatory_readiness_planning = $true
    paid_resources_created = $false
    real_value_capability_created = $false
    gke_enabled = $false
    institution_model_rc1 = $true
    compliance_cases_rc1 = $true
    consensus_interface_rc1 = $true
    bft_prototype_rc1 = $true
    prod_edge_design_rc1 = $true
    key_management_design_rc1 = $true
    regulatory_readiness_gate_rc1 = $true
    audit_reporting_hardening_rc1 = $true
    operational_runbooks_rc1 = $true
    result = "ok"
}
