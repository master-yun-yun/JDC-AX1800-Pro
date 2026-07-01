#!/bin/bash
# 完全重写 node-pnpm Makefile，彻底解决 "No makefile found" 错误
set -e

# 自动查找 node-pnpm 的 Makefile
FILE=$(find . -path "*/node-pnpm/Makefile" -print -quit 2>/dev/null)
if [ -z "$FILE" ]; then
    echo "node-pnpm Makefile not found, skipping patch."
    exit 0
fi

echo "Patching $FILE"
# 备份原文件以备不时之需
cp "$FILE" "$FILE.bak"

# 从原文件中提取 PKG_VERSION（例如 11.7.0）
PKG_VERSION=$(grep -oP 'PKG_VERSION:=\K[^ ]*' "$FILE" | head -1)
if [ -z "$PKG_VERSION" ]; then
    echo "Could not extract PKG_VERSION, defaulting to 11.7.0"
    PKG_VERSION="11.7.0"
fi

# 生成真实的制表符（Makefile 必须使用 TAB）
TAB=$(printf '\t')

# 生成全新的 Makefile
cat > "$FILE" <<'MAKEFILE_END'
include $(TOPDIR)/rules.mk

PKG_NAME:=node-pnpm
PKG_VERSION:=11.7.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://registry.npmjs.org/$(PKG_NAME)/-/$(PKG_NAME)-$(PKG_VERSION).tgz
PKG_HASH:=skip

define Host/Compile
	@echo "node-pnpm: Skipping source compile (npm package, no Makefile)"
	@true
endef

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/bin
	
	# 按优先级查找 pnpm.cjs
	if [ -f $(PKG_BUILD_DIR)/dist/pnpm.cjs ]; then \
		cp -a $(PKG_BUILD_DIR)/dist/* $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ ;\
	elif [ -f $(PKG_BUILD_DIR)/bin/pnpm.cjs ]; then \
		cp -a $(PKG_BUILD_DIR)/bin/pnpm.cjs $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\
	elif [ -f $(PKG_BUILD_DIR)/pnpm.cjs ]; then \
		cp -a $(PKG_BUILD_DIR)/pnpm.cjs $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\
	else \
		echo "ERROR: pnpm.cjs not found. Contents of $(PKG_BUILD_DIR):"; \
		ls -la $(PKG_BUILD_DIR)/ | head -30; \
		exit 1 ;\
	fi
	
	# 创建 Node.js wrapper 脚本，依赖系统 node（或 host 构建的 node）
	printf '#!/bin/sh\nexec node $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs "$$@"\n' \
		> $(STAGING_DIR_HOSTPKG)/bin/pnpm
	chmod +x $(STAGING_DIR_HOSTPKG)/bin/pnpm
endef

include $(INCLUDE_DIR)/host-build.mk
MAKEFILE_END

# 替换版本占位符
sed -i "s/PKG_VERSION:=11.7.0/PKG_VERSION:=$PKG_VERSION/" "$FILE"

echo "✓ node-pnpm Makefile rewritten successfully with version $PKG_VERSION."
echo "✓ Host/Compile: 跳过源码 make（npm 包无 Makefile）"
echo "✓ Host/Install: 查找 pnpm.cjs 并创建 node wrapper 脚本"
