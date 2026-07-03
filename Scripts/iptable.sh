#!/usr/bin/env bash
set -e
# SPDX-License-Identifier: MIT
# Patch script to ensure nft selected and avoid kmod iptables/nft file collisions.
# Places: Scripts/iptable.sh

# Ensure we're operating on the wrt working directory
if [ -n "$GITHUB_WORKSPACE" ] && [ -d "$GITHUB_WORKSPACE/wrt" ]; then
  cd "$GITHUB_WORKSPACE/wrt"
fi

# Ensure nft is selected: disable kmod-iptables and enable nft compatibility modules
sed -i '/^CONFIG_PACKAGE_kmod-iptables=/d' .config || true
sed -i '/^CONFIG_PACKAGE_kmod-nf-ipt=/d' .config || true
sed -i '/^CONFIG_PACKAGE_kmod-nft-compat=/d' .config || true
printf '\n# Ensure nft selected: disable iptables, enable nft compat\nCONFIG_PACKAGE_kmod-iptables=n\nCONFIG_PACKAGE_kmod-nf-ipt=y\nCONFIG_PACKAGE_kmod-nft-compat=y\n' >> .config

# 防止 mihomo alpha/meta 的递归依赖导致 defconfig 失败（短期回退）
sed -i '/^CONFIG_PACKAGE_mihomo-alpha=/d' .config || true
sed -i '/^CONFIG_PACKAGE_mihomo-meta=/d' .config || true
printf '\n# Prevent recursive dependency: prefer mihomo-meta\nCONFIG_PACKAGE_mihomo-alpha=n\nCONFIG_PACKAGE_mihomo-meta=y\n' >> .config

# Patch package Makefiles in ./package and ./feeds to add CONFLICTS to nft compatibility packages
# This prevents opkg from installing both kmod-iptables and nft-compat packages that ship the same files

# Helper to patch a file by inserting CONFLICTS after the package definition line
_patch_conflicts() {
  local file="$1"
  local pkgname="$2"
  if [ ! -f "$file" ]; then
    return 0
  fi
  if grep -q "^  CONFLICTS:=" "$file" 2>/dev/null; then
    return 0
  fi
  awk -v pkg="$pkgname" '1; /define Package\/'"$pkgname"'/ && !x { print "  CONFLICTS:=kmod-iptables"; x=1 }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Find and patch Makefiles that define the nft compatibility packages
for f in $(grep -R --files-with-match "Package/kmod-nft-compat" ./package ./feeds 2>/dev/null || true); do
  _patch_conflicts "$f" "kmod-nft-compat"
done

for f in $(grep -R --files-with-match "Package/kmod-nf-ipt" ./package ./feeds 2>/dev/null || true); do
  _patch_conflicts "$f" "kmod-nf-ipt"
done

# Also handle possible upstream naming variants (safety)
for f in $(grep -R --files-with-match "Package/kmod-nft" ./package ./feeds 2>/dev/null || true); do
  if [[ "$f" == *"kmod-nft"* ]]; then
    _patch_conflicts "$f" "kmod-nft"
  fi
done

# Run defconfig and clean to ensure configuration is regenerated
make defconfig -j$(nproc) && make clean -j$(nproc) || true
