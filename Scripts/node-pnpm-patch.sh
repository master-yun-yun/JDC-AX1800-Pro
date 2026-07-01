#!/bin/bash
# 修复 node-pnpm host 编译：自动定位 Makefile，跳过无 Makefile 的源码 make，并灵活安装 pnpm
set -e

# 自动查找所有可能的 node-pnpm Makefile（按优先级：feeds > package）
FILE=$(find . -path "*/node-pnpm/Makefile" -print -quit 2>/dev/null)

if [ -z "$FILE" ]; then
    echo "node-pnpm Makefile not found anywhere, skipping patch."
    exit 0
fi

echo "Patching node-pnpm Makefile at: $FILE"

# 1. 删除可能已存在的 Host/Compile 和 Host/Install 块（幂等）
sed -i '/^define Host\/Compile/,/^endef/d' "$FILE"
sed -i '/^define Host\/Install/,/^endef/d' "$FILE"

# 2. 生成真实的制表符
TAB=$(printf '\t')

# 3. 追加健壮的 Host/Compile 与 Host/Install 定义
{
    echo "define Host/Compile"
    echo "${TAB}@true  # 源码无 Makefile，跳过默认的 make 调用"
    echo "endef"
    echo ""
    echo "define Host/Install"
    echo "${TAB}\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist"
    echo "${TAB}\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/bin"
    echo "${TAB}# 按优先级查找 pnpm.cjs：dist/ → bin/ → 根目录"
    echo "${TAB}if [ -f \$(PKG_BUILD_DIR)/dist/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(PKG_BUILD_DIR)/dist/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\"
    echo "${TAB}${TAB}cp -a \$(PKG_BUILD_DIR)/dist/worker.js \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ 2>/dev/null || true ;\\"
    echo "${TAB}elif [ -f \$(PKG_BUILD_DIR)/bin/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(PKG_BUILD_DIR)/bin/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\"
    echo "${TAB}elif [ -f \$(PKG_BUILD_DIR)/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(PKG_BUILD_DIR)/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\"
    echo "${TAB}else \\"
    echo "${TAB}${TAB}echo \"ERROR: pnpm.cjs not found in any expected location\"; \\"
    echo "${TAB}${TAB}ls -la \$(PKG_BUILD_DIR)/ ;\\"
    echo "${TAB}${TAB}exit 1 ;\\"
    echo "${TAB}fi"
    echo "${TAB}# 创建调用 node 的 wrapper 脚本"
    echo "${TAB}printf '#!/bin/sh\\nexec \$(STAGING_DIR_HOSTPKG)/bin/node \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs \"\$\$@\"\\n' > \$(STAGING_DIR_HOSTPKG)/bin/pnpm"
    echo "${TAB}chmod +x \$(STAGING_DIR_HOSTPKG)/bin/pnpm"
    echo "endef"
} >> "$FILE"

echo "node-pnpm Makefile patched successfully."
