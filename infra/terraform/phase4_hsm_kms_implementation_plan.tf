variable "phase4_hsm_kms_implementation_enabled" {
  description = "Design-only guard for Phase 4 HSM/KMS implementation planning. This must remain false in phase4-hsm-kms-implementation-plan-rc1."
  type        = bool
  default     = false

  validation {
    condition     = var.phase4_hsm_kms_implementation_enabled == false
    error_message = "phase4-hsm-kms-implementation-plan-rc1 is design-only. Keep phase4_hsm_kms_implementation_enabled=false until a later approved apply slice."
  }
}

variable "phase4_hsm_kms_primary_location" {
  description = "Future primary KMS/HSM location, documented for planning only. No key rings, keys, HSM resources, or signing services are created by this slice."
  type        = string
  default     = "northamerica-northeast1"
}

variable "phase4_hsm_kms_crypto_profile" {
  description = "Future active crypto profile for managed signing, documented for planning only."
  type        = string
  default     = "hybrid-pqc-v1"
}

locals {
  phase4_hsm_kms_signing_purposes = {
    validator_block_signing = {
      custody_target        = "cloud_kms_or_hsm"
      dual_control_required = true
      rotation_cadence      = "90d"
      audit_event           = "KEY_SIGN_VALIDATOR_BLOCK"
    }
    treasury_asset_authority = {
      custody_target        = "cloud_hsm"
      dual_control_required = true
      rotation_cadence      = "180d"
      audit_event           = "KEY_SIGN_TREASURY_AUTHORITY"
    }
    api_request_signing = {
      custody_target        = "cloud_kms"
      dual_control_required = false
      rotation_cadence      = "90d"
      audit_event           = "KEY_SIGN_API_REQUEST"
    }
    audit_log_signing = {
      custody_target        = "cloud_kms_or_hsm"
      dual_control_required = true
      rotation_cadence      = "180d"
      audit_event           = "KEY_SIGN_AUDIT_EVENT"
    }
    iso20022_message_signing = {
      custody_target        = "cloud_kms_or_hsm"
      dual_control_required = true
      rotation_cadence      = "180d"
      audit_event           = "KEY_SIGN_ISO20022_MESSAGE"
    }
  }

  phase4_hsm_kms_implementation_plan = {
    release_candidate              = "phase4-hsm-kms-implementation-plan-rc1"
    status                         = "design-only"
    enabled                        = var.phase4_hsm_kms_implementation_enabled
    creates_paid_resources         = false
    changes_google_cloud_resources = false
    creates_real_value_capability  = false
    production_signing_enabled     = false
    primary_location               = var.phase4_hsm_kms_primary_location
    crypto_profile                 = var.phase4_hsm_kms_crypto_profile
    signing_purposes               = local.phase4_hsm_kms_signing_purposes

    implementation_stages = [
      "stage_0_design_only",
      "stage_1_local_signing_adapter",
      "stage_2_kms_mock_adapter",
      "stage_3_sandbox_kms_apply_candidate",
      "stage_4_sandbox_kms_pilot",
      "stage_5_hsm_candidate",
      "stage_6_production_candidate"
    ]

    required_gates_before_apply = [
      "cost_estimate_reviewed_and_approved",
      "security_architecture_review_completed",
      "terraform_plan_reviewed",
      "dual_control_approvers_assigned",
      "key_ceremony_runbook_approved",
      "break_glass_revocation_path_approved",
      "signing_service_threat_model_reviewed",
      "audit_event_schema_approved",
      "backup_recovery_and_ledger_replay_impact_reviewed",
      "regulatory_readiness_non_override_confirmed"
    ]

    deferred_resources = [
      "google_kms_key_ring",
      "google_kms_crypto_key",
      "google_kms_crypto_key_iam_binding",
      "cloud_hsm_key_generation",
      "production_signing_service"
    ]
  }
}

output "phase4_hsm_kms_implementation_plan" {
  description = "Design-only Phase 4 HSM/KMS implementation plan. This output creates no Google Cloud resources."
  value       = local.phase4_hsm_kms_implementation_plan
}
