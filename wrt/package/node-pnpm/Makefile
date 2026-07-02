# 如果没找到现成的 Makefile，则创建一个本地 fallback package（./wrt/package/node-pnpm/Makefile）
if [ -z "$FILE" ]; then
  echo "node-pnpm Makefile not found; creating fallback package at ./wrt/package/node-pnpm/Makefile"

  mkdir -p ./wrt/package/node-pnpm
  FILE="./wrt/package/node-pnpm/Makefile"

  cat > "$FILE" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=node-pnpm
PKG_VERSION:=11.7.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://registry.npmjs.org/$(PKG_NAME)/-/$(PKG_NAME)-$(PKG_VERSION).tgz
PKG_HASH:=skip

define Host/Compile
	@echo "Skipping make in source (no Makefile present)"
	@true
endef

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/bin

	# 按优先级查找 pnpm.cjs - 处理多种npm包结构
	if [ -f $(PKG_BUILD_DIR)/dist/pnpm.cjs ]; then \
		echo "Found pnpm.cjs in dist/ - copying full dist directory" ; \
		cp -a $(PKG_BUILD_DIR)/dist/* $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ ; \
	elif [ -f $(PKG_BUILD_DIR)/bin/pnpm.cjs ]; then \
		echo "Found pnpm.cjs in bin/ directory" ; \
		cp -a $(PKG_BUILD_DIR)/bin/pnpm.cjs $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ; \
		if [ -f $(PKG_BUILD_DIR)/bin/worker.js ]; then cp -a $(PKG_BUILD_DIR)/bin/worker.js $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/worker.js; fi ; \
	elif [ -f $(PKG_BUILD_DIR)/pnpm.cjs ]; then \
		echo "Found pnpm.cjs in root directory" ; \
		cp -a $(PKG_BUILD_DIR)/pnpm.cjs $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ; \
		if [ -f $(PKG_BUILD_DIR)/worker.js ]; then cp -a $(PKG_BUILD_DIR)/worker.js $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/worker.js; fi ; \
	elif [ -f $(PKG_BUILD_DIR)/package/dist/pnpm.cjs ]; then \
		echo "Found pnpm.cjs in package/dist/ subdirectory" ; \
		cp -a $(PKG_BUILD_DIR)/package/dist/* $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ ; \
	else \
		echo "ERROR: pnpm.cjs not found in any expected location." ; \
		echo "Listing PKG_BUILD_DIR ($(PKG_BUILD_DIR)):" ; \
		ls -la $(PKG_BUILD_DIR)/ || true ; \
		find $(PKG_BUILD_DIR) -name 'pnpm.cjs' -type f | head -20 || true ; \
		exit 1 ; \
	fi

	# 创建 node 包装脚本
	printf '#!/bin/sh\nexec node $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs "\$@"\n' > $(STAGING_DIR_HOSTPKG)/bin/pnpm
	chmod +x $(STAGING_DIR_HOSTPKG)/bin/pnpm
endef

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk
EOF

  echo "Fallback Makefile created at $FILE"
fi
