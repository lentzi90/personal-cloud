# AGENTS.md

## Repository Overview

This is a personal Kubernetes homelab infrastructure repository using **GitOps** with **ArgoCD** and **Kustomize**. It deploys various applications to a Kubernetes cluster (Talos-based "Turing Pi" cluster or local KinD for testing).

## Project Structure

- Each application has its own directory (e.g., `argocd/`, `cert-manager/`, `jellyfin/`)
- Applications follow a **base/overlays** pattern with Kustomize:
  - `<app>/base/` - Base configuration
  - `<app>/overlays/<environment>/` - Environment-specific overlays (e.g., `kind`, cloud)
- `apps/kind/` - ArgoCD Application manifests for the KinD environment

## Key Technologies

- **Kustomize** for configuration management
- **ArgoCD** for GitOps deployment
- **cert-manager** for TLS certificates
- **external-secrets** with Bitwarden for secrets management
- **Chainsaw** (Kyverno) for integration testing

## Development Workflow

1. Make changes to Kustomize manifests
2. Validate with `kustomize build <path>` (the CI runs this automatically)
3. Test locally with KinD: `kind create cluster --config=kind-config.yaml`
4. CI runs Chainsaw tests on PRs to validate the full deployment

## CI/CD Pipeline

The GitHub Actions pipeline (`.github/workflows/pipeline.yaml`) runs on PRs:
1. Runs `kustomize build` on all overlays to validate syntax
2. Creates a KinD cluster and deploys using Chainsaw tests

## Adding or Modifying Applications

- Follow existing patterns: create `base/` and `overlays/` directories
- Add an ArgoCD Application manifest in `apps/kind/` for testing
- Ensure the overlay is added to the CI build paths in `.github/workflows/pipeline.yaml`
- Use Kustomize components in `<app>/components/` for reusable patches

## Renovate

Dependency updates are managed by Renovate (`renovate.json`). Custom regex managers handle upstream resources referenced in kustomization files.

## Notes

When providing commands or examples, follow the style used in the README.md and the rest of the repository for consistency.
