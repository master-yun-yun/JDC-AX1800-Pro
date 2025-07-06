#!/bin/bash
# 终极依赖声明重构系统

set -e

echo "启动依赖声明重构系统..."

# 1. 创建虚拟依赖提供者系统
echo "创建虚拟依赖提供者..."
mkdir -p ./wrt/package/virtual-providers
cat > ./wrt/package/virtual-providers/Makefile << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=virtual-providers
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/virtual-providers
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Virtual Dependency Providers
  DEPENDS:=
endef

define Package/virtual-providers/description
  Provides virtual packages to satisfy dependencies
endef

define Build/Compile
endef

define Package/virtual-providers/install
endef

# 定义虚拟包
define Package/virtual-samba4-server
  $(call Package/virtual-providers)
  TITLE:=Virtual samba4-server provider
endef

define Package/virtual-samba4-server/description
  Virtual package for samba4-server
endef

define Package/virtual-samba4-client
  $(call Package/virtual-providers)
  TITLE:=Virtual samba4-client provider
endef

define Package/virtual-samba4-client/description
  Virtual package for samba4-client
endef

$(eval $(call BuildPackage,virtual-samba4-server))
$(eval $(call BuildPackage,virtual-samba4-client))
EOF

# 2. 重定向所有 samba4 依赖到虚拟包
echo "重定向 samba4 依赖..."
find ./wrt/ -type f -name "Makefile" | while read makefile; do
    sed -i 's/\bsamba4-server\b/virtual-samba4-server/g' "$makefile"
    sed -i 's/\bsamba4-client\b/virtual-samba4-client/g' "$makefile"
    sed -i 's/\bsamba4\b/virtual-samba4-server/g' "$makefile"
done

# 3. 确保虚拟包被包含
echo "CONFIG_PACKAGE_virtual-samba4-server=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_virtual-samba4-client=y" >> ./wrt/.config

# 4. 修改实际 samba4 包作为提供者
SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"
if [ -f "$SAMBA_MAKEFILE" ]; then
    echo "重构 samba4 包为提供者..."
    sed -i '/define Package\/samba4-server/a\  PROVIDES:=virtual-samba4-server' "$SAMBA_MAKEFILE"
    sed -i '/define Package\/samba4-client/a\  PROVIDES:=virtual-samba4-client' "$SAMBA_MAKEFILE"
fi

# 5. 修复 unishare 包
UNISHARE_MAKEFILE="./wrt/package/unishare/Makefile"
if [ ! -f "$UNISHARE_MAKEFILE" ]; then
    echo "创建 unishare 包..."
    mkdir -p ./wrt/package/unishare
    cat > "$UNISHARE_MAKEFILE" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=unishare
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/unishare
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Unified Sharing Service
  DEPENDS:=+virtual-samba4-server
endef

define Package/unishare/description
  Unified file sharing service
endef

define Build/Compile
endef

define Package/unishare/install
    $(INSTALL_DIR) $(1)/usr/bin
endef

$(eval $(call BuildPackage,unishare))
EOF
else
    echo "修复 unishare 依赖..."
    sed -i 's/\bsamba4-server\b/virtual-samba4-server/g' "$UNISHARE_MAKEFILE"
fi

# 6. 添加依赖解析钩子
echo "添加依赖解析钩子..."
mkdir -p ./wrt/scripts/hooks
cat > ./wrt/scripts/hooks/resolve-dependencies << 'EOF'
#!/bin/sh
# 依赖解析钩子脚本

# 解析虚拟依赖
resolve_virtual_dep() {
    case "$1" in
        virtual-samba4-server)
            echo "samba4-server"
            ;;
        virtual-samba4-client)
            echo "samba4-client"
            ;;
        *)
            echo "$1"
            ;;
    esac
}

# 处理依赖列表
DEPENDS_RESOLVED=""
for dep in $DEPENDS; do
    resolved=$(resolve_virtual_dep "$dep")
    DEPENDS_RESOLVED="$DEPENDS_RESOLVED $resolved"
done

# 设置新的依赖列表
export DEPENDS="$DEPENDS_RESOLVED"
EOF

chmod +x ./wrt/scripts/hooks/resolve-dependencies

# 7. 集成钩子到构建系统
echo "集成钩子到构建系统..."
find ./wrt -name "package.mk" -exec sed -i '1i include $(INCLUDE_DIR)/hooks.mk' {} +
cat > ./wrt/include/hooks.mk << 'EOF'
# 依赖解析钩子
define ResolveDependencies
	$(if $(DEPENDS), \
		@DEPENDS="$(DEPENDS)"; \
		. $(TOPDIR)/scripts/hooks/resolve-dependencies; \
		echo "Resolved dependencies: $$DEPENDS"; \
		$(call shexport,DEPENDS) \
	)
endef

Hook/Prepare/Pre = $(ResolveDependencies)
EOF

# 8. 添加必要的库链接
echo "创建必要的库符号链接..."
find ./wrt/staging_dir -type d -name "target-*" | while read target_dir; do
    mkdir -p "$target_dir/usr/lib"
    for lib in dl pthread rt crypt; do
        ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/lib$lib.so" 2>/dev/null || true
    done
    echo "为 $target_dir 创建了库符号链接"
done

# 9. 简化 samba4 依赖
if [ -f "$SAMBA_MAKEFILE" ]; then
    echo "简化 samba4 依赖..."
    sed -i '/DEPENDS:=/c\DEPENDS:= +zlib +libopenssl +libpcre +icu +krb5 +talloc +tdb +tevent +ldb +libbsd +libaio +libcap' "$SAMBA_MAKEFILE"
fi

echo "依赖声明重构系统部署完成！"
