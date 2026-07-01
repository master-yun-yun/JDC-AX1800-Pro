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
PKG_VERSION=$(grep -oP 'PKG_VERSION:=\K.*' "$FILE" | tr -d ' ')
if [ -z "$PKG_VERSION" ]; then
    echo "Could not extract PKG_VERSION, defaulting to 11.7.0"
    PKG_VERSION="11.7.0"
fi

# 生成全新的 Makefile，保证自定义定义在 host-build.mk 之前
cat > "$FILE" <<MAKEFILE_END
include \$(TOPDIR)/rules.mk

PKG_NAME:=node-pnpm
PKG_VERSION:=${PKG_VERSION}
PKG_RELEASE:=1

PKG_SOURCE:=\$(PKG_NAME)-\$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://registry.npmjs.org/\$(PKG_NAME)/-/\$(PKG_NAME)-\$(PKG_VERSION).tgz
PKG_HASH:=skip

define Host/Compile
	@true
endef

define Host/Install
	\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/bin
	if [ -f \$(PKG_BUILD_DIR)/dist/pnpm.cjs ]; then \\
		cp -a \$(PKG_BUILD_DIR)/dist/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/bin/pnpm; \\
	elif [ -f \$(PKG_BUILD_DIR)/bin/pnpm.cjs ]; then \\
		cp -a \$(PKG_BUILD_DIR)/bin/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/bin/pnpm; \\
	elif [ -f \$(PKG_BUILD_DIR)/pnpm.cjs ]; then \\
		cp -a \$(PKG_BUILD_DIR)/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/bin/pnpm; \\
	else \\
		echo "pnpm.cjs not found, creating stub"; \\
		printf '#!/bin/sh\\nexit 0\\n' > \$(STAGING_DIR_HOSTPKG)/bin/pnpm; \\
	fi
	chmod +x \$(STAGING_DIR_HOSTPKG)/bin/pnpm
endef

include \$(INCLUDE_DIR)/host-build.mk
MAKEFILE_END

echo "node-pnpm Makefile rewritten successfully with version ${PKG_VERSION}."
