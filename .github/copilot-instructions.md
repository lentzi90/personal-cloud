# Personal Cloud - GitHub Copilot Instructions

## Project Overview

This repository contains Kubernetes manifests for a personal cloud infrastructure, managed using GitOps principles with ArgoCD. The project deploys various self-hosted applications including Nextcloud (OpenCloud), Jellyfin, Keycloak, Pi-hole, and more on Kubernetes clusters.

## Tech Stack

- **Container Orchestration**: Kubernetes
- **GitOps**: ArgoCD
- **Configuration Management**: Kustomize
- **Testing Framework**: Chainsaw (Kyverno)
- **CI/CD**: GitHub Actions
- **Local Development**: KinD (Kubernetes in Docker)
- **Certificate Management**: cert-manager with Let's Encrypt
- **Ingress**: Nginx Ingress Controller, Envoy Gateway
- **Database**: CloudNativePG (PostgreSQL)
- **Secret Management**: External Secrets Operator with Bitwarden
- **Load Balancing**: MetalLB

## Repository Structure

- `/apps/`: ArgoCD Application manifests (app-of-apps pattern)
- `/argocd/`: ArgoCD installation manifests
- `/cert-manager/`: Certificate manager configuration
- `/<service-name>/`: Individual service directories containing:
  - `base/`: Base Kustomize manifests
  - `overlays/`: Environment-specific overlays (e.g., `kind/` for local testing)
- `.github/workflows/`: GitHub Actions workflows
- `chainsaw-test.yaml`: End-to-end test definitions
- `kind-config.yaml`: KinD cluster configuration

## Coding Guidelines

### Kustomize Conventions

- Always use Kustomize for managing Kubernetes manifests
- Follow the base/overlay pattern:
  - `base/`: Contains the core manifests
  - `overlays/<environment>/`: Contains environment-specific patches (e.g., `kind/` for local testing)
  - Some services also have kustomization overlays in the `turing-talos/` top-level directory
- Use `kustomization.yaml` files with proper apiVersion: `kustomize.config.k8s.io/v1beta1`
- Include environment labels in overlays:
  ```yaml
  labels:
  - includeSelectors: true
    pairs:
      environment: kind
  ```

### ArgoCD Applications

- All ArgoCD Application manifests go in the `apps/` directory
- Use `ServerSideApply=true` in syncOptions for applications with large manifests
- Example:
  ```yaml
  syncPolicy:
    syncOptions:
    - ServerSideApply=true
  ```

### YAML Conventions

- Use 2-space indentation
- No tabs, spaces only
- Use `---` to separate multiple documents in a single file
- Keep manifests organized by resource type

### Testing

- Use Chainsaw for end-to-end tests
- Test files are defined in `chainsaw-test.yaml`
- Test scripts are located in `.github/scripts/`
- Always test locally with KinD before pushing changes
- Run tests with: `chainsaw test`

### Git and CI/CD

- All PRs must pass kustomize build validation
- All PRs must pass Chainsaw end-to-end tests in KinD
- Use `git --no-pager` for git commands in scripts to avoid pager issues

## Build and Test Instructions

### Local Development with KinD

1. Create KinD cluster:
   ```bash
   sudo kind create cluster --config=kind-config.yaml
   sudo kind get kubeconfig > kubeconfig.yaml
   export KUBECONFIG=kubeconfig.yaml
   ```

2. Install prerequisites:
   ```bash
   kubectl apply -k cert-manager/overlays/kind
   kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
   kubectl apply -k argocd/overlays/kind
   ```

3. Deploy applications:
   ```bash
   kubectl -n argocd apply -f apps/kind/apps-app.yaml
   ```

### Running Tests

Run the full test suite with Chainsaw:
```bash
export KUBECONFIG=kubeconfig.yaml
export BITWARDEN_ACCESS_TOKEN=<your-token>
chainsaw test
```

### Validating Kustomize Manifests

Build and validate without applying:
```bash
kubectl kustomize <path-to-overlay>
# or
kustomize build <path-to-overlay>
```

## Key Directories and Files

- `argocd/bases/upstream/`: Upstream ArgoCD manifests
- `apps/kind/`: ArgoCD Application manifests for KinD environment
- `.github/workflows/pipeline.yaml`: Main CI/CD pipeline
- `chainsaw-test.yaml`: E2E test definitions
- `README.md`: User-facing documentation

## Access and Credentials

### Local Development (KinD)

- **Local domains**: Add to `/etc/hosts`:
  ```
  127.0.0.1 argocd.local opencloud.local jellyfin.local keycloak.local
  ```
- **ArgoCD**: Username `admin`, get password with:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```
- **OpenCloud (Nextcloud)**: Default credentials `admin`/`admin` in KinD overlay

## Important Notes

- Never commit secrets directly to the repository
- Use External Secrets Operator with Bitwarden for secret management
- Use `--server-side` flag when applying large Kubernetes manifests
- Test changes locally with KinD before creating PRs
- Follow GitOps principles: all changes should go through Git
