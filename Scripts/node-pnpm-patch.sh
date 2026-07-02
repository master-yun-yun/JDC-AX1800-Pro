#!/bin/bash
# 修复 node-pnpm Host/Install，智能适配 pnpm.cjs / pnpm.mjs 及不同路径

set -e

FILE="package/feeds/packages/node-pnpm/Makefile"
if [ ! -f "$FILE" ]; then
    echo "node-pnpm Makefile not found, skipping patch."
    exit 0
fi

# 删除原有 Host/Install 块
sed -i '/^define Host\/Install/,/^endef/d' "$FILE"

TAB=$(printf '\t')

{
    echo "define Host/Install"
    echo "${TAB}\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist"
    # 优先查找 .mjs，其次 .cjs
    echo "${TAB}if [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/pnpm.mjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/pnpm.mjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ ;\\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/worker.js \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ 2>/dev/null || true ;\\"
    echo "${TAB}elif [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ ;\\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/worker.js \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ 2>/dev/null || true ;\\"
    echo "${TAB}elif [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/bin/pnpm.mjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/bin/pnpm.mjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.mjs ;\\"
    echo "${TAB}elif [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/bin/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/bin/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\"
    echo "${TAB}elif [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/pnpm.mjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/pnpm.mjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.mjs ;\\"
    echo "${TAB}elif [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\"
    echo "${TAB}else \\"
    echo "${TAB}${TAB}echo \"ERROR: pnpm build artifacts not found\"; \\"
    echo "${TAB}${TAB}ls -la \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/ ;\\"
    echo "${TAB}${TAB}exit 1 ;\\"
    echo "${TAB}fi"
    echo "endef"
} >> "$FILE"

echo "node-pnpm Makefile patched with flexible install logic (supports .mjs / .cjs)."
