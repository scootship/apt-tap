#!/usr/bin/env bash
# Regenerates the `dists/` apt metadata tree from the committed `pool/` tree.
#
# The output of this script (./site) is never committed to git -- it is only
# ever published as a GitHub Pages build artifact, rebuilt fresh on every run.
# This keeps generated apt indices out of git history entirely, so multiple
# unrelated projects can push new .deb files into pool/ without ever fighting
# over a merge conflict in a generated index file.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SUITE="stable"
COMPONENT="main"
ARCHES=(amd64 arm64 armhf)
ORIGIN="scootship"
LABEL="scootship apt-tap"
DESCRIPTION="Shared apt repository for scootship org tools"

SITE_DIR="$REPO_ROOT/site"
DISTS_DIR="$SITE_DIR/dists/$SUITE"

rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR/pool"
if [ -d pool ]; then
  cp -r pool/. "$SITE_DIR/pool/"
fi

mkdir -p "$DISTS_DIR/$COMPONENT"
for arch in "${ARCHES[@]}"; do
  arch_dir="$DISTS_DIR/$COMPONENT/binary-$arch"
  mkdir -p "$arch_dir"
  # dpkg-scanpackages can exit non-zero on override-file warnings even when it
  # successfully produces a Packages listing (we pass no override file at
  # all), so log stderr but never treat it as fatal here.
  dpkg-scanpackages --arch "$arch" pool > "$arch_dir/Packages" 2> "$arch_dir/scan.log" || true
  cat "$arch_dir/scan.log" >&2
  rm -f "$arch_dir/scan.log"
  gzip -9c "$arch_dir/Packages" > "$arch_dir/Packages.gz"
done

RELEASE_FILE="$DISTS_DIR/Release"
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="$ORIGIN" \
  -o APT::FTPArchive::Release::Label="$LABEL" \
  -o APT::FTPArchive::Release::Suite="$SUITE" \
  -o APT::FTPArchive::Release::Codename="$SUITE" \
  -o APT::FTPArchive::Release::Architectures="${ARCHES[*]}" \
  -o APT::FTPArchive::Release::Components="$COMPONENT" \
  -o APT::FTPArchive::Release::Description="$DESCRIPTION" \
  release "$DISTS_DIR" > "$RELEASE_FILE"

if [ -n "${APT_TAP_GPG_PRIVATE_KEY:-}" ]; then
  echo "Signing Release with the imported GPG key..."
  GPG_OPTS=(--batch --yes --pinentry-mode loopback)
  if [ -n "${APT_TAP_GPG_PASSPHRASE:-}" ]; then
    GPG_OPTS+=(--passphrase "$APT_TAP_GPG_PASSPHRASE")
  fi
  gpg "${GPG_OPTS[@]}" --clearsign -o "$DISTS_DIR/InRelease" "$RELEASE_FILE"
  gpg "${GPG_OPTS[@]}" -abs -o "$DISTS_DIR/Release.gpg" "$RELEASE_FILE"

  KEY_ID="$(gpg --with-colons --list-secret-keys 2>/dev/null | awk -F: '/^sec:/ { print $5; exit }')"
  gpg --armor --export "$KEY_ID" > "$SITE_DIR/pubkey.gpg"
else
  echo "APT_TAP_GPG_PRIVATE_KEY is not set - publishing an UNSIGNED repository (bootstrap/test mode only)." >&2
fi

echo "Repository staged at $SITE_DIR:"
find "$SITE_DIR" -maxdepth 4 -type f | sort
