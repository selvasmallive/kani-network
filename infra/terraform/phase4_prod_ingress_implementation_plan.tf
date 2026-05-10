variable "phase4_prod_ingress_implementation_enabled" {
  description = "Design-only guard for Phase 4 production ingress implementation planning. This must remain false in phase4-prod-ingress-implementation-plan-rc1."
  type        = bool
  default     = false

  validation {
    condition     = var.phase4_prod_ingress_implementation_enabled == false
    error_message = "phase4-prod-ingress-implementation-plan-rc1 is design-only. Keep phase4_prod_ingress_implementation_enabled=false until a later approved apply slice."
  }
}

variable "phase4_prod_ingress_custom_domain" {
  description = "Future production ingress custom domain, documented for planning only. No DNS, certificate, load balancer, API Gateway, or Cloud Run ingress resources are created by this slice."
  type        = string
  default     = ""
}

variable "phase4_prod_ingress_edge_option" {
  description = "Future edge option decision. Allowed planning values are undecided, external_https_load_balancer, or api_gateway."
  type        = string
  default     = "undecided"

  validation {
    condition = contains([
      "undecided",
      "external_https_load_balancer",
      "api_gateway"
    ], var.phase4_prod_ingress_edge_option)
    error_message = "phase4_prod_ingress_edge_option must be undecided, external_https_load_balancer, or api_gateway."
  }
}

variable "phase4_prod_ingress_admin_oidc_issuer" {
  description = "Future admin OIDC issuer, documented for planning only."
  type        = string
  default     = ""
}

variable "phase4_prod_ingress_allowed_institution_certificate_fingerprints" {
  description = "Future institution mTLS certificate fingerprints keyed by institution id. Used for design validation only in this slice."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for fingerprint in values(var.phase4_prod_ingress_allowed_institution_certificate_fingerprints) :
      trimspace(fingerprint) != ""
    ])
    error_message = "Institution certificate fingerprints must not be blank when provided."
  }
}

locals {
  phase4_prod_ingress_request_paths = {
    institution_api_path = {
      authentication_boundary = "mtls_plus_institution_api_authorization"
      public_edge_candidate   = true
      enabled_now             = false
    }
    admin_api_path = {
      authentication_boundary = "oidc_plus_operator_authorization"
      public_edge_candidate   = true
      enabled_now             = false
    }
    validator_internal_path = {
      authentication_boundary = "internal_service_identity"
      public_edge_candidate   = false
      enabled_now             = false
    }
    health_path = {
      authentication_boundary = "minimal_public_or_edge_health_check"
      public_edge_candidate   = true
      sensitive_data_allowed  = false
      enabled_now             = false
    }
  }

  phase4_prod_ingress_implementation_plan = {
    release_candidate              = "phase4-prod-ingress-implementation-plan-rc1"
    status                         = "design-only"
    enabled                        = var.phase4_prod_ingress_implementation_enabled
    active_runtime_baseline        = "phase2-lean-no-gke"
    creates_paid_resources         = false
    changes_google_cloud_resources = false
    creates_real_value_capability  = false
    public_endpoint_exposure       = false
    production_ingress_enabled     = false
    edge_option                    = var.phase4_prod_ingress_edge_option
    custom_domain                  = var.phase4_prod_ingress_custom_domain
    admin_oidc_issuer              = var.phase4_prod_ingress_admin_oidc_issuer
    institution_certificate_count  = length(var.phase4_prod_ingress_allowed_institution_certificate_fingerprints)
    forbidden_principals           = ["allUsers", "allAuthenticatedUsers"]
    request_paths                  = local.phase4_prod_ingress_request_paths

    target_components = [
      "external_https_load_balancer_or_api_gateway_decision",
      "serverless_neg_to_cloud_run_api",
      "certificate_manager_tls_certificate",
      "certificate_manager_trust_config",
      "private_ca_or_institution_trust_bundle",
      "institution_mtls",
      "cloud_armor_waf",
      "cloud_armor_rate_limits",
      "admin_oidc",
      "private_cloud_run_ingress",
      "private_api_to_database_path",
      "managed_dns_record",
      "reserved_static_ip",
      "request_and_security_logging"
    ]

    implementation_stages = [
      "stage_0_design_only",
      "stage_1_domain_and_cert_design",
      "stage_2_waf_policy_design",
      "stage_3_mtls_trust_design",
      "stage_4_sandbox_edge_apply_candidate",
      "stage_5_preprod_edge_pilot",
      "stage_6_production_candidate"
    ]

    required_gates_before_apply = [
      "cost_estimate_reviewed_and_approved",
      "security_architecture_review_completed",
      "terraform_plan_reviewed",
      "dns_owner_approval_recorded",
      "certificate_and_trust_config_owner_assigned",
      "cloud_run_ingress_rollback_plan_approved",
      "cloud_armor_policy_reviewed",
      "admin_oidc_review_completed",
      "smoke_and_security_test_plan_approved",
      "penetration_test_scope_approved",
      "logging_retention_and_incident_response_review_completed",
      "regulatory_readiness_non_override_confirmed"
    ]

    deferred_resources = [
      "google_compute_global_address",
      "google_compute_region_network_endpoint_group",
      "google_compute_backend_service",
      "google_compute_url_map",
      "google_compute_target_https_proxy",
      "google_compute_global_forwarding_rule",
      "google_compute_security_policy",
      "google_certificate_manager_certificate",
      "google_certificate_manager_trust_config",
      "google_api_gateway_api",
      "google_api_gateway_gateway",
      "google_dns_record_set",
      "cloud_run_ingress_update"
    ]
  }
}

output "phase4_prod_ingress_implementation_plan" {
  description = "Design-only Phase 4 production ingress implementation plan. This output creates no Google Cloud resources."
  value       = local.phase4_prod_ingress_implementation_plan
}
