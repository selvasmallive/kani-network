variable "phase3_key_management_design_enabled" {
  description = "Design-only guard for Phase 3 KMS/HSM key management planning. This must remain false in phase3-key-management-design-rc1."
  type        = bool
  default     = false

  validation {
    condition     = var.phase3_key_management_design_enabled == false
    error_message = "phase3-key-management-design-rc1 is design-only. Keep phase3_key_management_design_enabled=false until a later approved deployment slice."
  }
}

variable "phase3_key_management_primary_location" {
  description = "Future primary KMS/HSM location, documented for planning only. No key rings, keys, or HSM resources are created by this slice."
  type        = string
  default     = "northamerica-northeast1"
}

variable "phase3_key_management_crypto_profile" {
  description = "Future active crypto profile for managed signing, documented for planning only."
  type        = string
  default     = "hybrid-pqc-v1"
}

variable "phase3_key_management_dual_control_approvers" {
  description = "Future dual-control approver identities for key ceremonies. Used for design validation only in this slice."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for approver in var.phase3_key_management_dual_control_approvers :
      trimspace(approver) != ""
    ])
    error_message = "Dual-control approver identities must not be blank when provided."
  }
}

locals {
  phase3_key_management_key_purposes = {
    validator_block_signing = {
      custody_target        = "cloud_kms_or_hsm"
      dual_control_required = true
      rotation_cadence      = "90d"
      signing_boundary      = "validator_signing_service"
      audit_event           = "KEY_SIGN_VALIDATOR_BLOCK"
    }
    treasury_asset_authority = {
      custody_target        = "cloud_hsm"
      dual_control_required = true
      rotation_cadence      = "180d"
      signing_boundary      = "treasury_signing_service"
      audit_event           = "KEY_SIGN_TREASURY_AUTHORITY"
    }
    api_request_signing = {
      custody_target        = "cloud_kms"
      dual_control_required = false
      rotation_cadence      = "90d"
      signing_boundary      = "api_signing_service"
      audit_event           = "KEY_SIGN_API_REQUEST"
    }
    audit_log_signing = {
      custody_target        = "cloud_kms"
      dual_control_required = true
      rotation_cadence      = "180d"
      signing_boundary      = "audit_signing_service"
      audit_event           = "KEY_SIGN_AUDIT_EVENT"
    }
    iso20022_message_signing = {
      custody_target        = "cloud_kms_or_hsm"
      dual_control_required = true
      rotation_cadence      = "180d"
      signing_boundary      = "iso20022_signing_service"
      audit_event           = "KEY_SIGN_ISO20022_MESSAGE"
    }
  }

  phase3_key_management_design = {
    release_candidate             = "phase3-key-management-design-rc1"
    status                        = "design-only"
    enabled                       = var.phase3_key_management_design_enabled
    creates_paid_resources        = false
    creates_real_value_capability = false
    gke_enabled                   = false
    primary_location              = var.phase3_key_management_primary_location
    crypto_profile                = var.phase3_key_management_crypto_profile
    dual_control_approver_count   = length(var.phase3_key_management_dual_control_approvers)
    key_states                    = ["pending", "active", "retiring", "retired", "compromised", "revoked"]
    key_purposes                  = local.phase3_key_management_key_purposes

    signing_request_contract = [
      "key_purpose",
      "crypto_profile",
      "payload_hash",
      "caller_principal",
      "institution_id",
      "approval_reference",
      "idempotency_key"
    ]

    ceremony_gates = [
      "two_operator_key_creation_approval",
      "separate_key_activation_approval",
      "purpose_and_crypto_profile_recorded",
      "key_version_recorded_in_audit",
      "emergency_revocation_break_glass_path",
      "post_ceremony_evidence_attached"
    ]

    deferred = [
      "google_kms_key_ring",
      "google_kms_crypto_key",
      "google_kms_crypto_key_version",
      "cloud_hsm_key_generation",
      "validator_hsm_signing",
      "treasury_hsm_signing",
      "production_signing_service"
    ]
  }
}

output "phase3_key_management_design" {
  description = "Design-only Phase 3 KMS/HSM key management plan. This output creates no Google Cloud resources."
  value       = local.phase3_key_management_design
}
