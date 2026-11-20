#!/bin/sh
# Install the enabled custom integrations into the persistent /config volume.
#
# Inputs:
#   /integrations/<domain>.env  Definition of each known integration, sourced
#                               as shell. Variables:
#                                 VERSION  Version to install, also used to
#                                          detect changes.
#                                 URL      Zip archive to download (may
#                                          reference VERSION).
#                                 KEEP     Optional space separated paths,
#                                          relative to the integration
#                                          directory, to keep across upgrades.
#   /integrations-enabled/enabled  Space separated list of integration domains
#                                  to install.
#
# The installed version is recorded in custom_components/<domain>/.version so
# an integration is only downloaded when its version changes. If a download
# fails but the integration is already installed, the old version is kept and
# the failure is only logged. The container fails if an enabled integration
# could not be installed at all.

DEFINITIONS=/integrations
ENABLED=/integrations-enabled/enabled
CUSTOM_COMPONENTS=/config/custom_components
WORK=/tmp/integrations

# Installing the tools only when something needs to be downloaded keeps
# restarts fast and independent of the Alpine mirrors.
ensure_tools() {
  if command -v curl >/dev/null && [ -x /usr/bin/unzip ]; then
    return 0
  fi
  apk add --no-cache curl unzip
}

# Print the directory in the extracted archive that holds the integration:
# either the archive root, or custom_components/<domain> in a repository
# archive.
find_integration() {
  root="$1"
  domain="$2"
  if [ -f "${root}/manifest.json" ]; then
    echo "${root}"
    return 0
  fi
  manifest="$(find "${root}" -path "*/custom_components/${domain}/manifest.json" | head -n 1)"
  if [ -n "${manifest}" ]; then
    dirname "${manifest}"
    return 0
  fi
  return 1
}

install_integration() {
  domain="$1"
  definition="${DEFINITIONS}/${domain}.env"
  if [ ! -f "${definition}" ]; then
    echo "No definition for ${domain}, expected ${definition}"
    return 1
  fi

  VERSION=""
  URL=""
  KEEP=""
  # shellcheck disable=SC1090
  . "${definition}"
  if [ -z "${VERSION}" ] || [ -z "${URL}" ]; then
    echo "${definition} must set VERSION and URL"
    return 1
  fi

  target="${CUSTOM_COMPONENTS}/${domain}"
  installed="$(cat "${target}/.version" 2>/dev/null)"
  if [ "${installed}" = "${VERSION}" ]; then
    echo "${domain} ${VERSION} is already installed"
    return 0
  fi
  echo "Installing ${domain} ${VERSION} (installed: ${installed:-none})"

  stage="${WORK}/${domain}"
  rm -rf "${stage}"
  mkdir -p "${stage}/archive" "${stage}/new"

  ensure_tools || return 1
  curl -fL --retry 3 --retry-delay 5 -o "${stage}/archive.zip" "${URL}" || return 1
  unzip -q -o "${stage}/archive.zip" -d "${stage}/archive" || return 1
  source_dir="$(find_integration "${stage}/archive" "${domain}")" || {
    echo "Could not find the ${domain} integration in ${URL}"
    return 1
  }
  cp -a "${source_dir}/." "${stage}/new/" || return 1

  for path in ${KEEP}; do
    if [ -e "${target}/${path}" ]; then
      mkdir -p "$(dirname "${stage}/new/${path}")"
      rm -rf "${stage:?}/new/${path}"
      cp -a "${target}/${path}" "${stage}/new/${path}" || return 1
    fi
  done
  echo "${VERSION}" > "${stage}/new/.version"

  # Only touch the installed copy once everything above has succeeded.
  rm -rf "${target}"
  mkdir -p "${target}"
  cp -a "${stage}/new/." "${target}/" || return 1
  rm -rf "${stage}"
}

mkdir -p "${CUSTOM_COMPONENTS}"
failed=""
for domain in $(cat "${ENABLED}"); do
  # Run in a subshell so variables from one definition cannot leak into the
  # next one.
  if ! (install_integration "${domain}"); then
    if [ -f "${CUSTOM_COMPONENTS}/${domain}/.version" ]; then
      echo "WARNING: failed to update ${domain}, keeping version $(cat "${CUSTOM_COMPONENTS}/${domain}/.version")"
    else
      echo "ERROR: failed to install ${domain}"
      failed="${failed} ${domain}"
    fi
  fi
done

if [ -n "${failed}" ]; then
  echo "Failed to install:${failed}"
  exit 1
fi
