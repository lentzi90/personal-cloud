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