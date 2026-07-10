#!/usr/bin/env bash
set -euo pipefail

# fix-netfilter.sh
# Purpose: Workaround for Linux 6.18 file-clash between kmod-iptables and kmod-nf-ipt
# This script makes kmod-iptables stop packaging ip_tables.ko and x_tables.ko by
# clearing the FILES variable in package/kernel/linux/modules/netfilter.mk
# Usage: run from the root of the OpenWrt source tree (the workflow does `cd ./wrt/`).

MKFILE="${1:-package/kernel/linux/modules/netfilter.mk}"
TIMESTAMP=$(date +%s)

echo "[fix-netfilter] Target makefile: $MKFILE"

if [ ! -f "$MKFILE" ]; then
  echo "[fix-netfilter] File not found: $MKFILE - nothing to do." >&2
  exit 0
fi

# Backup the original file (only once)
BACKUP="${MKFILE}.bak.$TIMESTAMP"
if [ ! -f "${MKFILE}.bak" ]; then
  cp -p "$MKFILE" "${MKFILE}.bak"
  echo "[fix-netfilter] Created backup: ${MKFILE}.bak"
fi
cp -p "$MKFILE" "$BACKUP"

# Produce a modified version where the KernelPackage/iptables block has FILES: cleared
awk '
  BEGIN{in=0}
  /^define KernelPackage\/iptables/{in=1; print; next}
  /^endef/{if(in){in=0; print; next} print}
  { if(in && $0 ~ /^[[:space:]]*FILES:=/) { print "  FILES:=" } else print }
' "$MKFILE" > "${MKFILE}.tmp"

# If changes identical, exit idempotently
if cmp -s "$MKFILE" "${MKFILE}.tmp"; then
  echo "[fix-netfilter] No changes required in $MKFILE"
  rm -f "${MKFILE}.tmp"
  exit 0
fi

# Show a short diff for logs
echo "[fix-netfilter] Applying changes to $MKFILE (showing diff):"
diff -u "$MKFILE" "${MKFILE}.tmp" | sed -n '1,200p' || true

# Move into place
mv "${MKFILE}.tmp" "$MKFILE"
chmod --reference="${MKFILE}.bak" "$MKFILE" || true

echo "[fix-netfilter] Update complete. You may want to run: make package/kernel/linux/clean"

exit 0
