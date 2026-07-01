#!/bin/bash
# 修复 node-pnpm host 构建：跳过无 Makefile 的源码 make，灵活适配上游文件布局变化
set -e

FILE="package/feeds/packages/node-pnpm/Makefile"
if [ ! -f "$FILE" ]; then
    echo "node-pnpm Makefile not found, skipping patch."
    exit 0
fi

# 1. 移除已有的 Host/Compile 和 Host/Install（幂等）
sed -i '/^define Host\/Compile/,/^endef/d' "$FILE"
sed -i '/^define Host\/Install/,/^endef/d' "$FILE"

# 2. 生成真实的制表符
TAB=$(printf '\t')

# 3. 逐行写入健壮的编译与安装定义，保证每一行命令前均为硬 Tab
{
    echo "define Host/Compile"
    echo "${TAB}true  # 源码无 Makefile，跳过默认 make 调用"
    echo "endef"
    echo ""
    echo "define Host/Install"
    echo "${TAB}\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist"
    echo "${TAB}\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/bin"
    echo "${TAB}# 优先查找 dist/、bin/、根目录的 pnpm.cjs"
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
    echo "${TAB}# 创建 pnpm wrapper 脚本，调用 node 执行"
    echo "${TAB}printf '#!/bin/sh\\nexec \$(STAGING_DIR_HOSTPKG)/bin/node \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs \"\$\$@\"\\n' > \$(STAGING_DIR_HOSTPKG)/bin/pnpm"
    echo "${TAB}chmod +x \$(STAGING_DIR_HOSTPKG)/bin/pnpm"
    echo "endef"
} >> "$FILE"

echo "node-pnpm Makefile patched (no-make Host/Compile + flexible Host/Install)."
