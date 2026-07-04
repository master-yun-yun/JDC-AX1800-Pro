#!/usr/bin/env bash
set -euo pipefail
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# Scripts/iptable.sh
# Purpose: ensure nft is selected, avoid kmod iptables/nft runtime file collisions
# - make sure .config prefers nft (kmod-nf-ipt / kmod-nft-compat) and disables kmod-iptables
# - detect packages that provide ip_tables/x_tables kernel modules and add CONFLICTS:=kmod-iptables
# - be idempotent and safe to run multiple times in CI

REPO_ROOT="$(pwd)"
# If running from workflow, move into wrt dir if exists
if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -d "$GITHUB_WORKSPACE/wrt" ]; then
  cd "$GITHUB_WORKSPACE/wrt" || exit 0
else
  # assume current working directory is repository root containing ./package and ./feeds
  cd "$REPO_ROOT" || true
fi

log() { printf "[%s] %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

log "Starting iptable.sh: ensure nft selected and add CONFLICTS to conflicting packages"

# Ensure .config exists (some CI flows place config earlier)
if [ ! -f .config ]; then
  log "Warning: .config not found in $(pwd); creating empty .config"
  touch .config
fi

# --- 1) Ensure nft selection in .config (idempotent) ---
log "Updating .config to prefer nft and disable kmod-iptables"
# Remove any previous entries to avoid duplicates
sed -i '/^CONFIG_PACKAGE_kmod-iptables=/d' .config || true
sed -i '/^CONFIG_PACKAGE_kmod-nf-ipt=/d' .config || true
sed -i '/^CONFIG_PACKAGE_kmod-nft-compat=/d' .config || true
sed -i '/^CONFIG_PACKAGE_kmod-nft=/d' .config || true

# Append desired choices at the end (idempotent because we removed earlier lines)
cat >> .config <<'CONFIG_EOF'

# Ensure nft selected: disable iptables, enable nft compat
CONFIG_PACKAGE_kmod-iptables=n
CONFIG_PACKAGE_kmod-nf-ipt=y
CONFIG_PACKAGE_kmod-nft-compat=y
CONFIG_PACKAGE_kmod-nft=y
CONFIG_EOF

log ".config updated"

# --- 2) Short-term mitigation for known Kconfig recursive dependency (mihomo packages)
# This prevents defconfig from failing in CI; keep nft preference intact
if grep -q "^CONFIG_PACKAGE_mihomo-alpha=" .config 2>/dev/null || grep -q "^CONFIG_PACKAGE_mihomo-meta=" .config 2>/dev/null; then
  log "Applying short-term mihomo alpha/meta preference to avoid recursive Kconfig dependency"
  sed -i '/^CONFIG_PACKAGE_mihomo-alpha=/d' .config || true
  sed -i '/^CONFIG_PACKAGE_mihomo-meta=/d' .config || true
  cat >> .config <<'MIHOMO_EOF'

# Prevent recursive dependency: prefer mihomo-meta (temporary CI workaround)
CONFIG_PACKAGE_mihomo-alpha=n
CONFIG_PACKAGE_mihomo-meta=y
MIHOMO_EOF
  log "mihomo preference applied"
fi

# --- 3) Helper to insert CONFLICTS into Makefile after 'define Package/<name>' ---
_insert_conflicts() {
  local file="$1"
  local conflict_with="$2"
  if [ ! -f "$file" ]; then
    return 1
  fi
  # already contains CONFLICTS?
  if grep -q "^  CONFLICTS:=" "$file" 2>/dev/null; then
    return 0
  fi
  # Insert conflicts line immediately after define Package/<something>
  awk -v c="  CONFLICTS:=$conflict_with" '1; /define Package\// && !x { print c; x=1 }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  log "Patched CONFLICTS in $file"
}

# --- 4) Targeted patch: common nft compatibility package names ---
log "Patching known nft-related package Makefiles to CONFLICT with kmod-iptables (if present)"
known_pkgs=("kmod-nft-compat" "kmod-nf-ipt" "kmod-nft" "kmod-nftables" "kmod-nf-ipt6")
for name in "${known_pkgs[@]}"; do
  while IFS= read -r f; do
    _insert_conflicts "$f" "kmod-iptables" || true
  done < <(grep -R --files-with-match "define Package/$name" ./package ./feeds 2>/dev/null || true)
done

# --- 5) Heuristic patch: find files that reference ip_tables.ko / x_tables.ko and patch their package Makefile ---
log "Scanning package/ and feeds/ for explicit references to ip_tables/x_tables to patch their package Makefile"
modules=("ip_tables.ko" "x_tables.ko" "ip_tables" "x_tables")
for mod in "${modules[@]}"; do
  while IFS= read -r f; do
    # Resolve to a Makefile in the same or parent directory
    dir=$(dirname "$f")
    pkgfile=""
    search_dir="$dir"
    while [ "$search_dir" != "." ] && [ "$search_dir" != "/" ]; do
      if [ -f "$search_dir/Makefile" ]; then
        pkgfile="$search_dir/Makefile"
        break
      fi
      search_dir=$(dirname "$search_dir")
    done
    if [ -n "$pkgfile" ]; then
      # Only patch if it seems to be a kernel module package (kmod-*)
      if grep -q "define Package/kmod-" "$pkgfile" 2>/dev/null || grep -q "kmod-" "$pkgfile" 2>/dev/null; then
        _insert_conflicts "$pkgfile" "kmod-iptables" || true
      fi
    fi
  done < <(grep -R --line-number --binary-files=without-match "$mod" ./package ./feeds 2>/dev/null | cut -d: -f1 || true)
done

# --- 6) Symmetric: add conflicts into kmod-iptables Makefile to mention nft packages ---
log "Adding reciprocal CONFLICTS into kmod-iptables Makefiles to make intent explicit"
while IFS= read -r f; do
  if [ -f "$f" ] && ! grep -q "kmod-nf-ipt\|kmod-nft-compat\|kmod-nft" "$f" 2>/dev/null; then
    awk '1; /define Package\/kmod-iptables/ && !x { print "  CONFLICTS:=kmod-nf-ipt kmod-nft-compat kmod-nft"; x=1 }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    log "Patched reciprocal CONFLICTS in $f"
  fi
done < <(grep -R --files-with-match "define Package/kmod-iptables" ./package ./feeds 2>/dev/null || true)

# --- 7) Diagnostics: list occurrences and patched files for CI logs ---
log "Diagnostics: occurrences of ip_tables/x_tables"
grep -R --line-number --binary-files=without-match "ip_tables\.ko\|x_tables\.ko" ./package ./feeds 2>/dev/null || true

log "Diagnostics: Makefiles that now contain CONFLICTS"
grep -R --line-number "^  CONFLICTS:=" ./package ./feeds 2>/dev/null || true

# --- 8) regenerate defconfig and clean (best-effort) ---
log "Running make defconfig && make clean (best-effort)"
make defconfig -j"$(nproc)" && make clean -j"$(nproc)" || true

log "iptable.sh finished"
