# Personal Cloud - GitHub Copilot Instructions

## Project Overview

Kubernetes manifests for personal cloud infrastructure managed via GitOps with ArgoCD. See README.md for setup and testing details.

## Repository Structure

- Service directories (`/<service-name>/`) use base/overlay pattern:
  - `base/`: Core manifests
  - `overlays/<environment>/`: Environment-specific patches
  - `turing-talos/`: Alternative overlay structure at top level
- `/apps/`: ArgoCD Application manifests (app-of-apps pattern)

## Coding Conventions

### Kustomize

- Use `kustomization.yaml` with apiVersion: `kustomize.config.k8s.io/v1beta1`
- Include environment labels in overlays:
  ```yaml
  labels:
  - includeSelectors: true
    pairs:
      environment: kind
  ```

### ArgoCD Applications

- Use `ServerSideApply=true` in syncOptions for applications with large manifests

### YAML

- 2-space indentation, no tabs
- Use `---` to separate documents

## Important Notes

- Never commit secrets directly
- Use `--server-side` flag when applying large Kubernetes manifests
- Use `git --no-pager` for git commands in scripts
