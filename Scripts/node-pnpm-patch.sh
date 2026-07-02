#!/bin/bash
# 修复 node-pnpm Host/Install 中 pnpm.cjs → pnpm.mjs 的问题
# 参考：https://github.com/immortalwrt/packages/issues/1939

set -e

FILE="package/feeds/packages/node-pnpm/Makefile"
if [ ! -f "$FILE" ]; then
    echo "node-pnpm Makefile not found, skipping patch."
    exit 0
fi

# 只在 Host/Install 块内替换 pnpm.cjs 为 pnpm.mjs
# 范围：从 "define Host/Install" 到 "endef"
sed -i '/^define Host\/Install/,/^endef/ s/pnpm\.cjs/pnpm.mjs/g' "$FILE"

echo "node-pnpm Makefile patched: pnpm.cjs → pnpm.mjs in Host/Install"
