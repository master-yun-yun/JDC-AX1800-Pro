#!/usr/bin/env bash
set -euo pipefail

# fix-netfilter.sh
# Updated: use Python to patch netfilter.mk to avoid awk portability issues.
# Purpose: Workaround for Linux 6.18 file-clash between kmod-iptables and kmod-nf-ipt
# This script clears the FILES variable in package/kernel/linux/modules/netfilter.mk
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

TMPFILE="${MKFILE}.tmp"

# Use Python to perform a robust, portable edit: clear FILES:= block inside
# define KernelPackage/iptables ... endef
python3 - "$MKFILE" "$TMPFILE" <<'PY'
import sys,re
mkfile=sys.argv[1]
tmpfile=sys.argv[2]
with open(mkfile,'r',encoding='utf-8') as f:
    lines=f.readlines()
out=[]
inblock=False
i=0
while i<len(lines):
    line=lines[i]
    if line.startswith('define KernelPackage/iptables'):
        inblock=True
        out.append(line)
        i+=1
        continue
    if inblock and line.strip()=="endef":
        inblock=False
        out.append(line)
        i+=1
        continue
    if inblock and re.match(r'^[ \t]*FILES:=', line):
        # replace with empty FILES and skip continuation lines
        out.append('  FILES:=\n')
        i+=1
        # skip following lines that are continuations (ending with backslash) or indented entries
        while i<len(lines):
            nxt=lines[i]
            if nxt.rstrip().endswith('\\') or re.match(r'^[ \t]+', nxt):
                i+=1
                continue
            break
        continue
    out.append(line)
    i+=1
with open(tmpfile,'w',encoding='utf-8') as f:
    f.writelines(out)
PY

# If changes identical, exit idempotently
if cmp -s "$MKFILE" "$TMPFILE"; then
  echo "[fix-netfilter] No changes required in $MKFILE"
  rm -f "$TMPFILE"
  exit 0
fi

# Show a short diff for logs
echo "[fix-netfilter] Applying changes to $MKFILE (showing diff):"
diff -u "$MKFILE" "$TMPFILE" | sed -n '1,200p' || true

# Move into place
mv "$TMPFILE" "$MKFILE"
chmod --reference="${MKFILE}.bak" "$MKFILE" || true

echo "[fix-netfilter] Update complete. You may want to run: make package/kernel/linux/clean"

exit 0
