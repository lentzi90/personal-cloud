# Nextcloud operations

## Backup and restore

See https://docs.nextcloud.com/server/stable/admin_manual/maintenance/backup.html

### Snippets

Exec into pod:

```bash
POD_NAME=$(kubectl -n nextcloud get pod -l app.kubernetes.io/component=nextcloud -o jsonpath="{.items[0].metadata.name}")
# Enable login shell for www-data user
kubectl -n nextcloud exec -it ${POD_NAME} -- chsh -s /bin/bash www-data
```

Add missing indices:

```bash
kubectl -n nextcloud exec -it ${POD_NAME} -- su www-data -c "php occ db:add-missing-indices"
```

Scan files:

```bash
kubectl -n nextcloud exec -it ${POD_NAME} -- su www-data -c "php occ files:scan --all"
```

Backup:

```bash
# Enable maintenance mode
kubectl -n nextcloud exec -it ${POD_NAME} -- su www-data -c "php occ maintenance:mode --on"

# Backup data and config
kubectl -n nextcloud exec ${POD_NAME} -- tar cf - /var/www/html | tar xf - -C nextcloud-backup

# Disable maintenance mode
kubectl -n nextcloud exec -it ${POD_NAME} -- su www-data -c "php occ maintenance:mode --off"

# Disable shell for www-data again (optional)
kubectl -n nextcloud exec -it ${POD_NAME} -- chsh -s /bin/nologin www-data
```

Restore:

```bash
# Scale down the nextcloud deployment to avoid mounting the volume twice
kubectl -n nextcloud scale deployment nextcloud --replicas=0

# Start a restore pod for handling the data migration
kubectl -n nextcloud apply -f restore-pod.yaml
# Copy the data to the volume
tar cf - nextcloud-backup/var/www/html | kubectl -n nextcloud exec -i restore -- tar xf - --strip-components 4 -C /var/www/html

# Correct the user and group
kubectl -n nextcloud exec -i restore -- chown --recursive www-data:www-data /var/www/html

# Remove restore pod and scale nextcloud back up
kubectl -n nextcloud delete -f restore-pod.yaml
kubectl -n nextcloud scale deployment nextcloud --replicas=1

# Disable maintenance mode
POD_NAME=$(kubectl -n nextcloud get pod -l app.kubernetes.io/name=nextcloud -o jsonpath="{.items[0].metadata.name}")
kubectl -n nextcloud exec -it ${POD_NAME} -- chsh -s /bin/bash www-data
kubectl -n nextcloud exec -it ${POD_NAME} -- su www-data -c "php occ maintenance:mode --off"

# Clean up, check that it is working before you do this!
kubectl -n nextcloud exec -i ${POD_NAME} -- rm /var/www/html/data/nextcloud.db.bak
```
