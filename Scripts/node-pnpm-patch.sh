#!/bin/bash
# 修复 node-pnpm host 构建：添加 Host/Compile 和 Host/Install 步骤
# 解决 "No rule to make target 'install'" 错误
set -e

FILE="package/feeds/packages/node-pnpm/Makefile"
if [ ! -f "$FILE" ]; then
    echo "node-pnpm Makefile not found, skipping patch."
    exit 0
fi

# 云编译环境可能没有 npm，临时安装（不影响 OpenWrt 自带的 host node）
if ! command -v npm &> /dev/null; then
    echo "Installing nodejs and npm for CI environment..."
    sudo apt-get update -qq && sudo apt-get install -y -qq nodejs npm
fi

# 删除可能已存在的旧 Host/Compile 和 Host/Install 块（幂等）
sed -i '/^define Host\/Compile/,/^endef/d' "$FILE"
sed -i '/^define Host\/Install/,/^endef/d' "$FILE"

# 追加健壮的编译安装逻辑
cat >> "$FILE" <<'MAKEFILE_BLOCK'

define Host/Compile
	cd $(PKG_BUILD_DIR) && npm install --production --no-audit --no-fund --ignore-scripts
endef

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/bin
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm
	cp -a $(PKG_BUILD_DIR)/node_modules/. $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/
	PNPM_ENTRY=""; \
	if [ -f $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/bin/pnpm.cjs ]; then \
		PNPM_ENTRY="bin/pnpm.cjs"; \
	elif [ -f $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ]; then \
		PNPM_ENTRY="dist/pnpm.cjs"; \
	elif [ -f $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/pnpm.cjs ]; then \
		PNPM_ENTRY="pnpm.cjs"; \
	else \
		echo "ERROR: cannot find pnpm entry file"; \
		ls -la $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/; \
		exit 1; \
	fi; \
	printf '#!/bin/sh\nexec $(STAGING_DIR_HOSTPKG)/bin/node $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/%s "$$@"\n' "$$PNPM_ENTRY" > $(STAGING_DIR_HOSTPKG)/bin/pnpm; \
	chmod +x $(STAGING_DIR_HOSTPKG)/bin/pnpm
endef
MAKEFILE_BLOCK

echo "node-pnpm Makefile patched with Host/Compile and Host/Install."
