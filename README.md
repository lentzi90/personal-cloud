# Readme

1. Install cert-manager: `kubectl apply -k cert-manager/overlays/<overlay>`
2. Install argocd: `kubectl apply -k argocd/overlays/<overlay>`
3. Add all applications: `kubectl apply -k apps/overlays/<overlay>`

The `apps` folder contains argocd Applications including an "app-of-apps".

## Backup

Use `rsync` to download all data from the NFS share.

```bash
rsync --archive --compress --progress --delete --rsync-path='sudo -u www-data rsync' lennart@bombur:/media/data/personal-cloud/nextcloud ./
rsync --archive --compress --progress --delete --rsync-path='sudo -u www-data rsync' lennart@bombur:/media/data/personal-cloud/minio ./
```

Make btrfs snapshots of the data.

```bash
sudo btrfs subvolume snapshot -r . .snapshots/nasse-$(date +%Y-%m-%d)

# Check disk usage
btrfs filesystem df --human-readable .
btrfs filesystem du --human-readable --summarize .
```

## Testing with KinD

```bash
sudo kind create cluster --config=kind-config.yaml
sudo kind get kubeconfig > kubeconfig.yaml
export KUBECONFIG=kubeconfig.yaml

kubectl apply -k argocd/overlays/kind

# Login and check that it is working
password="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
argocd login --port-forward --port-forward-namespace argocd --username=admin --password="${password}"
argocd --port-forward --port-forward-namespace=argocd cluster list

# Add argocd, cert-manager and nginx-ingress to get a fully working argocd deployment
kubectl -n argocd apply -f apps/kind/argocd-app.yaml
kubectl -n argocd apply -f apps/kind/cert-manager-app.yaml
kubectl -n argocd apply -f apps/kind/ingress-nginx-app.yaml
# Sync the ingress controller since it does not have auto sync enabled
argocd --port-forward --port-forward-namespace=argocd app sync ingress-nginx
```

At this point, we have a working ingress controller, argocd and cert-manager set up.
Add `127.0.0.1 argocd.local` to `/etc/hosts` and go to [argocd.local](https://argocd.local) to see the dashboard.
Log in as `admin` with the password you get from this commands:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Deploy external-secrets:

```bash
kubectl -n argocd apply -f apps/kind/external-secrets-app.yaml
kubectl -n external-secrets create secret generic bitwarden-access-token --from-literal=token=...
kubectl apply -f secret-store/test-secretstore.yaml
```

### Deploying nextcloud

First we need to set up cloudnative-pg that will be used to manage the database, and minio that will be used for backup of the database.

```bash
kubectl -n argocd apply -f apps/kind/minio-app.yaml
kubectl -n argocd apply -f apps/kind/cloudnative-pg-app.yaml
```

Now we can deploy nextcloud:

```bash
kubectl -n argocd apply -f apps/kind/nextcloud-app.yaml
argocd --port-forward --port-forward-namespace=argocd app sync nextcloud
```

Set up minio credentials:

```bash
minio_root_user="$(kubectl -n minio get secret minio-root-creds -o jsonpath="{.data.MINIO_ROOT_USER}" | base64 -d)"
minio_root_password="$(kubectl -n minio get secret minio-root-creds -o jsonpath="{.data.MINIO_ROOT_PASSWORD}" | base64 -d)"
minio_nextcloud_user="$(kubectl -n nextcloud get secret minio-creds -o jsonpath="{.data.USER}" | base64 -d)"
minio_nextcloud_password="$(kubectl -n nextcloud get secret minio-creds -o jsonpath="{.data.PASSWORD}" | base64 -d)"
kubectl -n minio exec -it deploy/minio -- mc alias set local http://localhost:9000 "${minio_root_user}" "${minio_root_password}"
kubectl -n minio exec -it deploy/minio -- mc admin user add local "${minio_nextcloud_user}" "${minio_nextcloud_password}"
kubectl -n minio exec -it deploy/minio -- mc admin policy attach local readwrite --user "${minio_nextcloud_user}"
```

Login at [nextcloud.local](https://nextcloud.local) as `admin` with the password

```bash
kubectl -n nextcloud get secret nextcloud-admin -o jsonpath="{.data.NEXTCLOUD_ADMIN_PASSWORD}" | base64 -d
```

### Deploying pi-hole

Start with MetalLB:

```bash
kubectl -n argocd apply -f apps/kind/metallb-app.yaml
argocd --port-forward --port-forward-namespace=argocd app sync metallb
```

Then deploy pi-hole:

```bash
kubectl -n argocd apply -f apps/kind/pi-hole-app.yaml
argocd --port-forward --port-forward-namespace=argocd app sync pi-hole
```

Find the IP and password:

```bash
pi_hole_ip="$(kubectl -n pi-hole get svc pi-hole -o jsonpath="{.status.loadBalancer.ingress[].ip}")"
pi_hole_password="$(kubectl -n pi-hole get secret pi-hole-env -o jsonpath="{.data.WEBPASSWORD}" | base64 -d)"
echo "Login at http://${pi_hole_ip}/admin with the password ${pi_hole_password}"
```

Test the nameserver like this:

```bash
host example.com "${pi_hole_ip}"
```
