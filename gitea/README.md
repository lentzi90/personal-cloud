# Gitea operations

## Backup and restore

See https://docs.gitea.io/en-us/backup-and-restore/

### Snippets

Backup:
```shell
POD_NAME=$(kubectl -n gitea get pod -l app.kubernetes.io/name=gitea -o jsonpath="{.items[0].metadata.name}")
# Create a backup dump in /tmp (you must use this folder or the command will fail)
kubectl -n gitea exec -it ${POD_NAME} -- su git -c "cd /tmp && gitea dump --file gitea-dump.zip"
# Copy dump to from container
kubectl -n gitea cp ${POD_NAME}:/tmp/gitea-dump.zip gitea-dump.zip
```

Restore:
```shell
unzip gitea-dump.zip
unzip gitea-repo-zip
kubectl -n gitea cp repositories ${POD_NAME}:/data/git/
kubectl -n gitea exec -it ${POD_NAME} -- chown --recursive git:git /data/git
cat gitea-db.sql | kubectl -n gitea exec -it ${POD_NAME} -- sqlite3 /data/gitea/gitea.db
```
