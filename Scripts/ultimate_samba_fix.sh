#!/bin/bash
# 使用 samba36 替代 samba4 的终极解决方案

set -e  # 遇到任何错误立即退出

echo "开始应用终极samba解决方案：使用samba36替代samba4..."

# 1. 从配置中移除samba4相关包
echo "从配置中移除samba4相关包..."
sed -i '/CONFIG_PACKAGE_samba4/d' ./wrt/.config
sed -i '/CONFIG_PACKAGE_luci-app-samba4/d' ./wrt/.config

# 2. 添加samba36到配置
echo "添加samba36到全局配置..."
echo "CONFIG_PACKAGE_samba36-server=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_luci-app-samba=y" >> ./wrt/.config

# 3. 修改所有依赖samba4的包指向samba36
echo "修改所有依赖samba4的包指向samba36..."
find ./wrt/ -type f -name "Makefile" | while read makefile; do
    # 修复依赖引用
    sed -i 's/\bsamba4-server\b/samba36-server/g' "$makefile"
    sed -i 's/\bsamba4-client\b/samba36-client/g' "$makefile"
    sed -i 's/\bsamba4\b/samba36-server/g' "$makefile"
    
    # 特殊处理unishare
    if [[ "$makefile" == *"unishare"* ]]; then
        echo "为unishare添加samba36依赖..."
        sed -i '/DEPENDS:=/ s/$/ +samba36-server/' "$makefile"
    fi
done

# 4. 确保samba36源可用
echo "确保samba36源可用..."
if ! grep -q "samba36" ./wrt/feeds.conf.default; then
    echo "添加samba36源..."
    echo "src-git packages https://git.openwrt.org/feed/packages.git" >> ./wrt/feeds.conf.default
fi

# 5. 更新feeds
echo "更新feeds以包含samba36..."
cd ./wrt/
./scripts/feeds update packages
./scripts/feeds install samba36-server
cd ..

# 6. 添加必要的符号链接
echo "创建必要的符号链接..."
find ./wrt/staging_dir -type d -name "target-*" | while read target_dir; do
    mkdir -p "$target_dir/usr/lib"
    ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/libcrypt.so.1" 2>/dev/null || true
    echo "创建符号链接: $target_dir/usr/lib/libcrypt.so.1"
done

# 7. 添加unishare的简化实现（如果需要）
UNISHARE_DIR="./wrt/package/unishare"
if [ ! -d "$UNISHARE_DIR" ]; then
    echo "创建简化的unishare包..."
    mkdir -p "$UNISHARE_DIR"
    cat > "$UNISHARE_DIR/Makefile" <<EOF
include \$(TOPDIR)/rules.mk

PKG_NAME:=unishare
PKG_VERSION:=1.0
PKG_RELEASE:=1

include \$(INCLUDE_DIR)/package.mk

define Package/unishare
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Unified Sharing Service
  DEPENDS:=+samba36-server
endef

define Package/unishare/description
 Simplified unified file sharing service
endef

define Build/Compile
endef

define Package/unishare/install
	\$(INSTALL_DIR) \$(1)/usr/bin
endef

\$(eval \$(call BuildPackage,unishare))
EOF
fi

echo "终极samba解决方案应用完成：已使用samba36替代samba4"
