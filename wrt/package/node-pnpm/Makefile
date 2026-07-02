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

	# 按优先级查找 pnpm 文件（支持 .cjs/.mjs/.js）并复制到 dist
	PNPM_FILE=""
	if [ -d "$(PKG_BUILD_DIR)/dist" ] && ls "$(PKG_BUILD_DIR)/dist/pnpm.*" >/dev/null 2>&1; then \
		echo "Found pnpm in dist/ - copying full dist directory"; \
		cp -a "$(PKG_BUILD_DIR)/dist"/* "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/"; \
		PNPM_FILE=$(shell ls "$(PKG_BUILD_DIR)/dist/pnpm.*" 2>/dev/null | head -n1); \
	elif ls "$(PKG_BUILD_DIR)/bin/pnpm.*" >/dev/null 2>&1; then \
		echo "Found pnpm in bin/ - copying"; \
		cp -a "$(PKG_BUILD_DIR)/bin/pnpm.*" "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/" 2>/dev/null || true; \
		PNPM_FILE=$(shell ls "$(PKG_BUILD_DIR)/bin/pnpm.*" 2>/dev/null | head -n1); \
	elif ls "$(PKG_BUILD_DIR)/pnpm.*" >/dev/null 2>&1; then \
		echo "Found pnpm in root - copying"; \
		cp -a "$(PKG_BUILD_DIR)/pnpm.*" "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/" 2>/dev/null || true; \
		PNPM_FILE=$(shell ls "$(PKG_BUILD_DIR)/pnpm.*" 2>/dev/null | head -n1); \
	elif [ -d "$(PKG_BUILD_DIR)/package/dist" ] && ls "$(PKG_BUILD_DIR)/package/dist/pnpm.*" >/dev/null 2>&1; then \
		echo "Found pnpm in package/dist - copying"; \
		cp -a "$(PKG_BUILD_DIR)/package/dist"/* "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/"; \
		PNPM_FILE=$(shell ls "$(PKG_BUILD_DIR)/package/dist/pnpm.*" 2>/dev/null | head -n1); \
	fi; \

	# Fallback: try to detect any pnpm.* file in build dir
	if [ -z "$$PNPM_FILE" ]; then \
		PNPM_FILE=$(find "$(PKG_BUILD_DIR)" -type f -name 'pnpm.*' 2>/dev/null | head -n1 || true); \
	fi; \

	if [ -z "$$PNPM_FILE" ]; then \
		echo "ERROR: pnpm.* not found in any expected location."; \
		echo "Listing PKG_BUILD_DIR ($(PKG_BUILD_DIR)):"; ls -la "$(PKG_BUILD_DIR)"/ || true; \
		echo "Searching for pnpm.* in build directory:"; find "$(PKG_BUILD_DIR)" -name 'pnpm.*' -type f | head -20 || true; \
		exit 1; \
	fi; \

	PNPM_BASENAME=$$(basename "$$PNPM_FILE"); \
	echo "Detected pnpm file: $$PNPM_FILE (basename $$PNPM_BASENAME)"; \
	# Ensure it's present in dist (in case we copied from bin/root into dist above)
	if [ ! -f "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/$$PNPM_BASENAME" ]; then \
		cp -a "$$PNPM_FILE" "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/" || true; \
	fi; \
	# Also copy worker.js if present anywhere
	WORKER_FILE=$$(find "$(PKG_BUILD_DIR)" -type f -name 'worker.js' 2>/dev/null | head -n1 || true); \
	if [ -n "$$WORKER_FILE" ]; then \
		cp -a "$$WORKER_FILE" "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/" || true; \
	fi; \

	# 创建 node 包装脚本，指向检测到的 pnpm 文件
	printf '#!/bin/sh\nexec node "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/$$PNPM_BASENAME" "$$@"\n' > "$(STAGING_DIR_HOSTPKG)/bin/pnpm"; \
	chmod +x "$(STAGING_DIR_HOSTPKG)/bin/pnpm"; \

endef

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk
