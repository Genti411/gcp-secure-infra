output "service_url" {
  description = "Public HTTPS URL of the Cloud Run service."
  value       = google_cloud_run_v2_service.svc.uri
}

output "runtime_service_account" {
  description = "The least-privilege service account the service runs as."
  value       = google_service_account.run_sa.email
}

output "artifact_registry_repo" {
  description = "Artifact Registry repo to push the image to."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}
