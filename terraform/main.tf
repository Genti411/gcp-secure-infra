# Secure Cloud Run deployment.
#
# Security design:
#   - the service runs as a DEDICATED least-privilege service account, not the
#     default compute SA (which has broad project Editor by default),
#   - the app secret lives in Secret Manager and is injected at runtime; the SA
#     is granted accessor on ONLY that one secret,
#   - the container image comes from Artifact Registry (not deprecated GCR),
#   - public invocation is opt-in via a variable (default on for the demo;
#     flip allow_public=false for an authenticated/internal service).

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "repo" {
  # checkov:skip=CKV_GCP_84:Default Google-managed encryption at rest is used; CMEK/CSEK is an enterprise option out of scope for this demo.
  location      = var.region
  repository_id = "secure-apps"
  format        = "DOCKER"
  description   = "Container images for the secure Cloud Run service"
  depends_on    = [google_project_service.apis]
}

# Dedicated runtime identity with no project-level roles.
resource "google_service_account" "run_sa" {
  account_id   = "secure-cloudrun-sa"
  display_name = "Least-privilege Cloud Run runtime SA"
}

resource "google_secret_manager_secret" "app_secret" {
  secret_id = "app-jwt-secret"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "app_secret_v1" {
  secret      = google_secret_manager_secret.app_secret.id
  secret_data = var.app_secret
}

# Grant the runtime SA accessor on ONLY this secret (resource-scoped IAM).
resource "google_secret_manager_secret_iam_member" "run_sa_access" {
  secret_id = google_secret_manager_secret.app_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_cloud_run_v2_service" "svc" {
  name     = "secure-app"
  location = var.region

  # Public demo ingress. For an internal service set this to
  # INTERNAL_AND_CLOUD_LOAD_BALANCING and front it with an external LB + WAF.
  ingress = "INGRESS_TRAFFIC_ALL" # checkov:skip=CKV_GCP_103:public demo, see README threat model

  template {
    service_account = google_service_account.run_sa.email

    containers {
      image = var.image
      ports {
        container_port = 8080
      }
      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.app_secret.secret_id
            version = "latest"
          }
        }
      }
      resources {
        limits = {
          cpu    = "1"
          # Cloud Run requires >= 512Mi when CPU is always-allocated.
          memory = "512Mi"
        }
      }
    }

    scaling {
      max_instance_count = 3
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.run_sa_access]
}

# Opt-in public access. allUsers is intentional for the demo; gated behind a
# variable so the default-secure path (authenticated only) is one flag away.
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count    = var.allow_public ? 1 : 0
  name     = google_cloud_run_v2_service.svc.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
