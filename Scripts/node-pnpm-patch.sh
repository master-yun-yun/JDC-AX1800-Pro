#!/bin/bash
# 终极防呆 node-pnpm Makefile 重写脚本
set -e

FILE=$(find . -maxdepth 4 -path "*/node-pnpm/Makefile" -print -quit 2>/dev/null)
if [ -z "$FILE" ]; then
    echo "node-pnpm Makefile not found, skipping patch."
    exit 0
fi

echo "Found Makefile: $FILE"
PKG_VERSION=$(grep -oP 'PKG_VERSION:=\K\S+' "$FILE" | head -1)
if [ -z "$PKG_VERSION" ]; then
    echo "Warning: PKG_VERSION not found, defaulting to 11.7.0"
    PKG_VERSION="11.7.0"
fi

cp "$FILE" "$FILE.bak"
TAB=$(printf '\t')
> "$FILE"

printf '%s\n' "include \$(TOPDIR)/rules.mk" >> "$FILE"
printf '%s\n' "" >> "$FILE"
printf '%s\n' "PKG_NAME:=node-pnpm" >> "$FILE"
printf '%s\n' "PKG_VERSION:=${PKG_VERSION}" >> "$FILE"
printf '%s\n' "PKG_RELEASE:=1" >> "$FILE"
printf '%s\n' "" >> "$FILE"
printf '%s\n' "PKG_SOURCE:=\$(PKG_NAME)-\$(PKG_VERSION).tar.gz" >> "$FILE"
printf '%s\n' "PKG_SOURCE_URL:=https://registry.npmjs.org/\$(PKG_NAME)/-/\$(PKG_NAME)-\$(PKG_VERSION).tgz" >> "$FILE"
printf '%s\n' "PKG_HASH:=skip" >> "$FILE"
printf '%s\n' "" >> "$FILE"
printf '%s\n' "define Host/Compile" >> "$FILE"
printf '%s\n' "${TAB}@echo \"Skipping make in source (no Makefile present)\"" >> "$FILE"
printf '%s\n' "${TAB}@true" >> "$FILE"
printf '%s\n' "endef" >> "$FILE"
printf '%s\n' "" >> "$FILE"
printf '%s\n' "define Host/Install" >> "$FILE"
printf '%s\n' "${TAB}\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist" >> "$FILE"
printf '%s\n' "${TAB}\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/bin" >> "$FILE"
printf '%s\n' "${TAB}# 按优先级查找 pnpm.cjs" >> "$FILE"
printf '%s\n' "${TAB}if [ -f \$(PKG_BUILD_DIR)/dist/pnpm.cjs ]; then \\" >> "$FILE"
printf '%s\n' "${TAB}${TAB}cp -a \$(PKG_BUILD_DIR)/dist/* \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ ;\\" >> "$FILE"
printf '%s\n' "${TAB}elif [ -f \$(PKG_BUILD_DIR)/bin/pnpm.cjs ]; then \\" >> "$FILE"
printf '%s\n' "${TAB}${TAB}cp -a \$(PKG_BUILD_DIR)/bin/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\" >> "$FILE"
printf '%s\n' "${TAB}elif [ -f \$(PKG_BUILD_DIR)/pnpm.cjs ]; then \\" >> "$FILE"
printf '%s\n' "${TAB}${TAB}cp -a \$(PKG_BUILD_DIR)/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\" >> "$FILE"
printf '%s\n' "${TAB}else \\" >> "$FILE"
printf '%s\n' "${TAB}${TAB}echo \"ERROR: pnpm.cjs not found. Listing \$(PKG_BUILD_DIR):\" ;\\" >> "$FILE"
printf '%s\n' "${TAB}${TAB}ls -la \$(PKG_BUILD_DIR)/ ;\\" >> "$FILE"
printf '%s\n' "${TAB}${TAB}exit 1 ;\\" >> "$FILE"
printf '%s\n' "${TAB}fi" >> "$FILE"
printf '%s\n' "${TAB}# 创建 node 包装脚本" >> "$FILE"
printf '%s\n' "${TAB}printf '#!/bin/sh\\nexec node \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs \"\$\$@\"\\n' > \$(STAGING_DIR_HOSTPKG)/bin/pnpm" >> "$FILE"
printf '%s\n' "${TAB}chmod +x \$(STAGING_DIR_HOSTPKG)/bin/pnpm" >> "$FILE"
printf '%s\n' "endef" >> "$FILE"
printf '%s\n' "" >> "$FILE"

# 🔽 新增的两行（关键修复）
printf '%s\n' "include \$(INCLUDE_DIR)/package.mk" >> "$FILE"
printf '%s\n' "include \$(INCLUDE_DIR)/host-build.mk" >> "$FILE"

echo "✓ New Makefile written with version ${PKG_VERSION}"
echo "  Now includes package.mk before host-build.mk (fixes missing host target)"
