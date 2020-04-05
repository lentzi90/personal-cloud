# Readme

1. Install cert-manager: `kubectl apply -k cert-manager/overlays/<overlay>`
2. Install argocd: `kubectl apply -k argocd/overlays/<overlay>`
3. Add all applications: `kubectl apply -k apps/overlays/<overlay>`

The `apps` folder contains argocd Applications including an "app-of-apps".
