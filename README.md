# GCP Secure Infrastructure (Terraform + Cloud Run)

Infrastructure-as-code that deploys a hardened service to **Google Cloud Run**
with real cloud-security controls, plus **IaC security scanning** (tfsec +
checkov) wired into CI. The point isn't the app — it's deploying it *securely*
and proving the infrastructure is sound *before* it ships.

| Area | What's shown |
|------|--------------|
| **Terraform / IaC** | Modular GCP resources, variables, outputs, targeted apply |
| **GCP** | Cloud Run v2, Artifact Registry, Secret Manager, IAM, service enablement |
| **Cloud security** | least-privilege runtime SA, resource-scoped secret access, secrets out of the image, opt-in public access |
| **DevSecOps** | `tfsec` + `checkov` + `terraform validate` gate every change in GitHub Actions |

## Security controls

- **Least-privilege identity** — the service runs as a dedicated service account
  with **no** project-level roles, not the default compute SA (which is project
  Editor). It can read exactly one secret and nothing else.
- **Secrets in Secret Manager** — the app secret is stored in Secret Manager and
  injected at runtime via `value_source`; it never lands in the image, the
  Terraform state output, or an env file. The runtime SA gets
  `secretAccessor` **scoped to that one secret**.
- **Artifact Registry** (not deprecated Container Registry) for images.
- **Opt-in public access** — `allow_public` gates the `allUsers` invoker binding;
  flip it to `false` for an authenticated/internal-only service in one line.

## Architecture

```
        Cloud Build ──build──▶ Artifact Registry ──image──▶ Cloud Run (v2)
                                                              │ runs as
                                                              ▼
                                              least-privilege service account
                                                              │ secretAccessor (1 secret)
                                                              ▼
                                                        Secret Manager
```

## Deploy (this is the GCP deploy)

Prereqs: an authenticated `gcloud`, Terraform, and a **billing-enabled** project.

```bash
./deploy.sh YOUR_PROJECT_ID us-central1
```

It enables the APIs, creates the Artifact Registry repo, builds + pushes the
image with Cloud Build, then `terraform apply`s the SA, secret, Cloud Run service
and IAM — and prints the public HTTPS URL. Verify:

```bash
curl https://YOUR-SERVICE-URL/health     # {"status":"ok"}
curl https://YOUR-SERVICE-URL/secretz     # {"jwt_secret_loaded": true}  (secret never echoed)
```

Tear down: `cd terraform && terraform destroy`.

## Scan the IaC locally

```bash
docker run --rm -v "$PWD/terraform":/src aquasec/tfsec /src
docker run --rm -v "$PWD/terraform":/tf bridgecrew/checkov -d /tf
```

CI runs the same checks (`.github/workflows/iac-scan.yml`) on every push/PR.

## Threat model notes

The demo exposes the service publicly (`allow_public=true`, `INGRESS_TRAFFIC_ALL`)
so you can curl it. The two intentional findings that implies are documented with
inline `checkov:skip` justifications. To productionize: set `allow_public=false`,
set ingress to `INTERNAL_AND_CLOUD_LOAD_BALANCING`, and front it with an external
HTTPS load balancer + Cloud Armor (WAF). Everything else (least-priv SA, scoped
secret access, no plaintext secrets) is already production-shaped.

## Layout

```
app/                  tiny hardened Flask service (security headers, /health, /secretz)
terraform/            versions, variables, main (SA + secret + Cloud Run + IAM), outputs
deploy.sh             build image + targeted apply + full apply
.github/workflows/    terraform validate + tfsec + checkov gate
```
