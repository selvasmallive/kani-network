variable "phase3_prod_edge_design_enabled" {
  description = "Design-only guard for Phase 3 production edge planning. This must remain false in phase3-prod-edge-design-rc1."
  type        = bool
  default     = false

  validation {
    condition     = var.phase3_prod_edge_design_enabled == false
    error_message = "phase3-prod-edge-design-rc1 is design-only. Keep phase3_prod_edge_design_enabled=false until a later approved deployment slice."
  }
}

variable "phase3_prod_edge_custom_domain" {
  description = "Future production edge domain, documented for planning only. No DNS, certificate, or load balancer resources are created by this slice."
  type        = string
  default     = ""
}

variable "phase3_prod_edge_admin_oidc_issuer" {
  description = "Future admin OIDC issuer, documented for planning only."
  type        = string
  default     = ""
}

variable "phase3_prod_edge_allowed_institution_certificate_fingerprints" {
  description = "Future institution mTLS certificate fingerprints keyed by institution id. Used for design validation only in this slice."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for fingerprint in values(var.phase3_prod_edge_allowed_institution_certificate_fingerprints) :
      trimspace(fingerprint) != ""
    ])
    error_message = "Institution certificate fingerprints must not be blank when provided."
  }
}

locals {
  phase3_prod_edge_design = {
    release_candidate             = "phase3-prod-edge-design-rc1"
    status                        = "design-only"
    enabled                       = var.phase3_prod_edge_design_enabled
    creates_paid_resources        = false
    creates_real_value_capability = false
    gke_enabled                   = false
    cloud_run_ingress_target      = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    custom_domain                 = var.phase3_prod_edge_custom_domain
    admin_oidc_issuer             = var.phase3_prod_edge_admin_oidc_issuer
    institution_certificate_count = length(var.phase3_prod_edge_allowed_institution_certificate_fingerprints)
    forbidden_invokers            = ["allUsers", "allAuthenticatedUsers"]

    target_components = [
      "global_external_https_load_balancer",
      "serverless_neg_to_kani_api",
      "certificate_manager_tls_certificate",
      "certificate_manager_trust_config",
      "institution_mtls",
      "cloud_armor_waf",
      "cloud_armor_rate_limiting",
      "private_cloud_run_ingress",
      "admin_oidc",
      "private_api_to_database_path"
    ]

    implementation_sequence = [
      "create_separate_deployment_slice",
      "estimate_paid_resources_before_apply",
      "switch_cloud_run_ingress_to_internal_load_balancer",
      "attach_serverless_neg_or_api_gateway_backend",
      "attach_certificate_manager_tls_certificate",
      "attach_institution_mtls_trust_config",
      "attach_cloud_armor_waf_and_rate_limits",
      "wire_admin_oidc_authorization",
      "run_security_smoke_tests",
      "complete_penetration_test_before_real_value"
    ]

    deferred = [
      "google_compute_global_address",
      "google_compute_region_network_endpoint_group",
      "google_compute_backend_service",
      "google_compute_url_map",
      "google_compute_target_https_proxy",
      "google_compute_global_forwarding_rule",
      "google_compute_security_policy",
      "google_certificate_manager_certificate",
      "google_certificate_manager_trust_config",
      "production_dns_changes"
    ]
  }
}

output "phase3_prod_edge_design" {
  description = "Design-only Phase 3 production edge plan. This output creates no Google Cloud resources."
  value       = local.phase3_prod_edge_design
}
