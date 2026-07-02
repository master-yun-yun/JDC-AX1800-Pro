#!/bin/bash
# 智能修复 node-pnpm Host/Install 中 pnpm.cjs → pnpm.mjs
# 仅在需要时执行替换，避免在上游已修复后造成反向错误

set -e

FILE="package/feeds/packages/node-pnpm/Makefile"
if [ ! -f "$FILE" ]; then
    echo "node-pnpm Makefile not found, skipping patch."
    exit 0
fi

# 提取 Host/Install 块（从 define Host/Install 到 endef）
HOST_INSTALL_BLOCK=$(sed -n '/^define Host\/Install/,/^endef/p' "$FILE")

# 检查是否包含 pnpm.cjs（且未被注释）
if echo "$HOST_INSTALL_BLOCK" | grep -q 'pnpm\.cjs'; then
    echo "Found pnpm.cjs in Host/Install, applying patch..."
    sed -i '/^define Host\/Install/,/^endef/ s/pnpm\.cjs/pnpm.mjs/g' "$FILE"
    echo "Patched: pnpm.cjs → pnpm.mjs"
else
    echo "No pnpm.cjs found in Host/Install, nothing to patch (likely already fixed upstream)."
fi
