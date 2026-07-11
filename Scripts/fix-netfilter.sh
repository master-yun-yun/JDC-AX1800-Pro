#!/usr/bin/env bash
set -euo pipefail

MKFILE="${1:-package/kernel/linux/modules/netfilter.mk}"
TIMESTAMP=$(date +%s)

echo "[fix-netfilter] Target makefile: $MKFILE"

if [ ! -f "$MKFILE" ]; then
  echo "[fix-netfilter] File not found: $MKFILE - nothing to do." >&2
  exit 0
fi

# Backup the original file (only once)
if [ ! -f "${MKFILE}.bak" ]; then
  cp -p "$MKFILE" "${MKFILE}.bak"
  echo "[fix-netfilter] Created backup: ${MKFILE}.bak"
fi
cp -p "$MKFILE" "${MKFILE}.bak.$TIMESTAMP"

TMPFILE="${MKFILE}.tmp"

python3 - "$MKFILE" "$TMPFILE" <<'PY'
import sys, re

mkfile = sys.argv[1]
tmpfile = sys.argv[2]

with open(mkfile, 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
inblock = False
i = 0

while i < len(lines):
    line = lines[i]

    # 精确匹配 KernelPackage/iptables 定义开始
    if re.match(r'^define KernelPackage/iptables\b', line):
        inblock = True
        out.append(line)
        i += 1
        continue

    if inblock and line.strip() == "endef":
        inblock = False
        out.append(line)
        i += 1
        continue

    if inblock and re.match(r'^[ \t]*FILES:=', line):
        out.append('  FILES:=\n')
        i += 1
        # 只跳过以 \ 结尾的续行，以及包含 .ko 的缩进行
        while i < len(lines):
            nxt = lines[i]
            if nxt.rstrip().endswith('\\'):
                i += 1
                continue
            if re.match(r'^[ \t]+.*\.ko', nxt):
                i += 1
                continue
            break
        continue

    out.append(line)
    i += 1

with open(tmpfile, 'w', encoding='utf-8') as f:
    f.writelines(out)
PY

if cmp -s "$MKFILE" "$TMPFILE"; then
  echo "[fix-netfilter] No changes required in $MKFILE"
  rm -f "$TMPFILE" "${MKFILE}.bak.$TIMESTAMP"
  exit 0
fi

echo "[fix-netfilter] Applying changes to $MKFILE (showing diff):"
diff -u "$MKFILE" "$TMPFILE" | sed -n '1,200p' || true

mv "$TMPFILE" "$MKFILE"
chmod --reference="${MKFILE}.bak" "$MKFILE" || true

echo "[fix-netfilter] Update complete. You may want to run: make package/kernel/linux/clean"
exit 0
