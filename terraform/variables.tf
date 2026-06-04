variable "project_id" {
  type        = string
  description = "Target GCP project ID."
}

variable "region" {
  type        = string
  description = "Region for the regional resources."
  default     = "us-central1"
}

variable "image" {
  type        = string
  description = "Container image URL (Artifact Registry) for the Cloud Run service."
  # e.g. us-central1-docker.pkg.dev/PROJECT/secure-apps/secure-app:latest
}

variable "app_secret" {
  type        = string
  description = "Application secret stored in Secret Manager (e.g., a JWT signing key)."
  sensitive   = true
  default     = "change-me-via-tfvars-or-CI-secret"
}

variable "allow_public" {
  type        = bool
  description = "If true, grant allUsers the run.invoker role (public demo). Set false for an authenticated/internal service."
  default     = true
}
