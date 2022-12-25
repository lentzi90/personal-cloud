# Readme

1. Install cert-manager: `kubectl apply -k cert-manager/overlays/<overlay>`
2. Install argocd: `kubectl apply -k argocd/overlays/<overlay>`
3. Add all applications: `kubectl apply -k apps/overlays/<overlay>`

The `apps` folder contains argocd Applications including an "app-of-apps".

## Backup

Use `rsync` to download all data from the NFS share.

```bash
rsync --archive --compress --progress --delete lennart@nasse.lan:/share/Public/nextcloud ./
rsync --archive --compress --progress --delete lennart@nasse.lan:/share/Public/kubegres ./
```

Make btrfs snapshots of the data.
```bash
sudo btrfs subvolume snapshot -r . .snapshots/nasse-$(date +%Y-%m-%d)

# Check disk usage
btrfs filesystem du --human-readable --summarize .
btrfs filesystem df --human-readable .
```

## Testing with KinD

```bash
sudo kind create cluster --config=kind-config.yaml
sudo kind get kubeconfig > kubeconfig.yaml
export KUBECONFIG=kubeconfig.yaml

kubectl apply -k argocd/overlays/kind

## Note: These commands need manual input!
# Generate PGP key for encrypting secrets
gpg --full-generatekey
# Export key to a file
gpg --armor --export-secret-keys <id> > argocd-gpg-private-key.gpg

# Create a secret with the secret key to be used by argocd
kubectl -n argocd create secret generic argocd-gpg-private-key --from-file=argocd-gpg-private-key.gpg

# Login and check that it is working
password="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
argocd login --port-forward --port-forward-namespace argocd --username=admin --password="${password}"
argocd --port-forward --port-forward-namespace=argocd cluster list

# Add argocd, cert-manager and nginx-ingress to get a fully working argocd deployment
kubectl -n argocd apply -f apps/kind/argocd-app.yaml
kubectl -n argocd apply -f apps/kind/cert-manager-app.yaml
kubectl -n argocd apply -f apps/kind/ingress-nginx-app.yaml
```

At this point, we have a working ingress controller, argocd and cert-manager set up.
Add `127.0.0.1 argocd.local` to `/etc/hosts` and go to [argocd.local](https://argocd.local) to see the dashboard.
Log in as `admin` with the password you get from this commands:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
