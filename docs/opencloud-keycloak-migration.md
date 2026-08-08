# Migrating the existing OpenCloud installation to Keycloak (turing-talos)

This describes how to move the running `opencloud.jern.fi` instance from the
built-in identity provider to Keycloak **without losing data and without
re-syncing anything**.

## Why this works without a re-install

OpenCloud stores files in per-user *personal spaces* that are keyed by the
OpenCloud **user ID**, not by the username. If a user ends up with a new user ID
after the migration, the old space is still on disk but invisible, and every
client would have to sync everything again.

The configuration in this repository therefore only disables the built-in
identity *provider* (`idp`) and keeps the built-in identity *manager* (`idm`)
running as the user directory:

```env
OC_EXCLUDE_RUN_SERVICES=idp
PROXY_USER_OIDC_CLAIM=preferred_username
PROXY_USER_CS3_CLAIM=username
```

On sign-in the proxy takes `preferred_username` from the Keycloak token and
looks the account up in `idm` by username. The existing account is found, keeps
its user ID, and the existing personal space is reused. Keycloak only replaces
the login screen.

The important consequence: **the Keycloak username must be exactly the same as
the existing OpenCloud username.** If it differs, `PROXY_AUTOPROVISION_ACCOUNTS`
creates a brand new account with a brand new (randomly generated) user ID and an
empty personal space. There is no way to pin the user ID of an autoprovisioned
account, the graph service rejects client supplied IDs.

## Before starting

1. **Back up the data**, as described in
   [turing-talos/README.md](../turing-talos/README.md#backup). OpenCloud's
   data is a single ext4 image (`/media/data/iscsi-luns/opencloud.img`)
   exported over iSCSI, sitting directly under the top-level btrfs subvolume
   (not inside the `personal-cloud` subvolume), so it needs its own snapshot
   of the top level:

   ```bash
   ssh bombur sudo btrfs subvolume snapshot -r /media/data \
     "/media/data/.snapshots/media-data-$(date +%Y-%m-%d)"
   ```

   This is crash-consistent (comparable to snapshotting a live VM disk; ext4's
   journal replay handles the rest) and safe to take while the LUN is actively
   mounted by the `opencloud` pod. Nested subvolumes such as `personal-cloud`
   and its own snapshots are not duplicated, they show up as empty
   placeholders; only plain files and directories, including
   `iscsi-luns/opencloud.img`, are actually captured.

2. **Note the current spaces.** Personal space IDs are the user IDs, so this is
   the list that must not grow during the migration:

   ```bash
   kubectl -n opencloud exec deploy/opencloud -- find /var/lib/opencloud/storage/users/users -maxdepth 1
   ```

3. **Note the usernames and groups.** Sign in to
   [opencloud.jern.fi](https://opencloud.jern.fi) as admin and write down, from
   *Admin Settings*, every username, its role, and every group that is used in
   shares. These have to be recreated in Keycloak with identical names.

4. Check that the Keycloak instance is healthy, since it becomes a hard
   dependency for logging in to OpenCloud:

   ```bash
   kubectl -n keycloak get keycloak,pods
   ```

## Step 1: import the realm (no impact on OpenCloud)

Merge the branch and let ArgoCD sync the `keycloak` application. This adds the
`openCloud` realm with its clients, roles, groups and client scopes. OpenCloud is
untouched at this point, so it is safe to stop here and verify.

```bash
kubectl -n keycloak get keycloakrealmimport opencloud-realm -o yaml
curl -s https://keycloak.jern.fi/realms/openCloud/.well-known/openid-configuration | jq .issuer
```

> The Keycloak operator runs the import with a Job. Depending on the operator
> version this can briefly restart the Keycloak pod, so expect a short outage of
> other Keycloak-backed logins, if any.

## Step 2: create the users in Keycloak

For every existing OpenCloud user, create a Keycloak user in the `openCloud`
realm with:

- **Username**: identical to the OpenCloud username (this is the critical part)
- Email, first name, last name filled in
- A password (not temporary, or the user gets a forced password change)
- Realm role `opencloudAdmin` for the admin, `opencloudUser` for regular users

If group shares are in use, create groups in Keycloak with the **same names** as
the OpenCloud groups and put the users in them. With
`PROXY_AUTOPROVISION_ACCOUNTS=true` the proxy synchronises group memberships
from the token on every sign-in and removes memberships that are not in the
`groups` claim, which would silently break group shares.

Do this *before* step 3. Nobody can sign in between disabling `idp` and having a
usable Keycloak account.

## Step 3: switch OpenCloud over

Sync the `opencloud` application. This changes the `opencloud-env` ConfigMap and
the deployment, and because the strategy is `Recreate` the pod is replaced.
Expect a couple of minutes of downtime.

```bash
kubectl -n opencloud rollout status deploy/opencloud
kubectl -n opencloud logs deploy/opencloud | grep -i oidc
```

## Step 4: verify

1. Open [opencloud.jern.fi](https://opencloud.jern.fi), which should now redirect
   to the Keycloak login page.
2. Sign in as the migrated admin. All files must be there immediately.
3. Confirm no new space was created:

   ```bash
   kubectl -n opencloud exec deploy/opencloud -- find /var/lib/opencloud/storage/users/users -maxdepth 1
   ```

   The list must be identical to the one from the preparation step. A new entry
   means the username did not match and a fresh account was provisioned.
4. Check that the admin still has admin rights (*Admin Settings* is visible). If
   not, the `opencloudAdmin` realm role is missing on the Keycloak user.
5. Check the discovery document that the clients use:

   ```bash
   curl -s https://opencloud.jern.fi/.well-known/openid-configuration | jq .issuer
   ```

   This must return the Keycloak issuer. It is served by the proxy because
   `PROXY_OIDC_REWRITE_WELLKNOWN=true`, the built-in `idp` that normally answers
   here is gone.
6. Re-authenticate the desktop and mobile clients. The old tokens are issued by
   the built-in idp and are no longer valid, so the account has to be
   re-connected in each client. Keep the existing local sync folder so the client
   can reconcile against it instead of downloading everything again, and verify
   that it settles before deleting anything.

### If something goes wrong

The rollback is cheap because `idm` never stopped being the user directory and
the local passwords are still valid:

1. Revert the `opencloud` application to the previous revision (ArgoCD history,
   or revert the merge commit).
2. The built-in `idp` comes back and `admin` can sign in with
   `IDM_ADMIN_PASSWORD` again.

No data is touched by the switch itself, only the login path changes. The
realm in Keycloak can stay, it is harmless while unused.

## Optional follow-up

Once this is stable, the remaining built-in `idm` could also be replaced, either
by an external LDAP that Keycloak federates, or by pointing Keycloak at the
built-in LDAP of `idm` on port 9235 and matching users by ID
(`PROXY_USER_CS3_CLAIM=userid`). That is how the upstream examples do it, but it
is a bigger change and not needed to get Keycloak logins working.
