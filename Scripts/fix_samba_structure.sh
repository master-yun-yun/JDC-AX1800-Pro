#!/bin/bash
# 全面修复samba4包结构和依赖关系

# 1. 修复samba4自身的包结构
SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"
if [ -f "$SAMBA_MAKEFILE" ]; then
    echo "修复samba4包结构..."
    
    # 确保所有子包都启用
    sed -i 's/\(define BuildPackage\/samba4-libs\)/define Package\/samba4-server\n  $(call Package\/samba4-libs)\n  TITLE:=Samba4 server\n  DEPENDS:=+samba4-libs\nendef\n\n\1/' "$SAMBA_MAKEFILE"
    
    # 添加server包安装命令
    sed -i '/define Package\/samba4-libs\/install/,$!b; a \
define Package\/samba4-server\/install \\\
\t$(INSTALL_DIR) $$(1)/usr/sbin \\\
\t$(INSTALL_BIN) $$(PKG_INSTALL_DIR)/usr/sbin/smbd $$(1)/usr/sbin/ \\\
\t$(INSTALL_BIN) $$(PKG_INSTALL_DIR)/usr/sbin/nmbd $$(1)/usr/sbin/ \\\
\t$(INSTALL_DIR) $$(1)/etc/config \\\
\t$(INSTALL_CONF) ./files/samba4.config $$(1)/etc/config/samba4 \\\
\t$(INSTALL_DIR) $$(1)/etc/samba \\\
\t$(INSTALL_DATA) ./files/smb.conf.template $$(1)/etc/samba/ \\\
\t$(INSTALL_DIR) $$(1)/etc/init.d \\\
\t$(INSTALL_BIN) ./files/samba4.init $$(1)/etc/init.d/samba4
' "$SAMBA_MAKEFILE"
    
    # 添加client包定义
    sed -i '/define Package\/samba4-server\/install/,$!b; a \
define Package\/samba4-client \\\
\t$(call Package\/samba4-libs) \\\
\tTITLE:=Samba4 client \\\
\tDEPENDS:=+samba4-libs \\\
endef \\\
\\\
define Package\/samba4-client\/install \\\
\t$(INSTALL_DIR) $$(1)/usr/sbin \\\
\t$(INSTALL_BIN) $$(PKG_INSTALL_DIR)/usr/sbin/smbclient $$(1)/usr/sbin/ \\\
\t$(INSTALL_DIR) $$(1)/usr/bin \\\
\t$(INSTALL_BIN) $$(PKG_INSTALL_DIR)/usr/bin/* $$(1)/usr/bin/ \\\
endef
' "$SAMBA_MAKEFILE"
    
    # 确保所有包都被构建
    sed -i '/BuildPackage\/samba4-libs/ a \
$(eval $(call BuildPackage,samba4-server)) \
$(eval $(call BuildPackage,samba4-client))
' "$SAMBA_MAKEFILE"
fi

# 2. 修复依赖包的引用
fix_dependency() {
    local pkg_makefile=$1
    local old_dep=$2
    local new_dep=$3
    
    if [ -f "$pkg_makefile" ]; then
        echo "修复 $pkg_makefile 依赖: $old_dep -> $new_dep"
        sed -i "s/$old_dep/$new_dep/g" "$pkg_makefile"
    fi
}

# 修复特定包的依赖
fix_dependency "./wrt/feeds/packages/net/backuppc/Makefile" "samba4-client" "samba4-client"
fix_dependency "./wrt/feeds/luci/applications/luci-app-samba4/Makefile" "samba4-server" "samba4-server"
fix_dependency "./wrt/package/unishare/Makefile" "samba4-server" "samba4-server"

# 3. 确保全局配置包含所有组件
echo "CONFIG_PACKAGE_samba4-libs=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_samba4-server=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_samba4-client=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_luci-app-samba4=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_unishare=y" >> ./wrt/.config

# 4. 创建必要的符号链接
find ./wrt/staging_dir -type d -name "target-*" | while read target_dir; do
    mkdir -p "$target_dir/usr/lib"
    ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/libcrypt.so.1" 2>/dev/null
done

echo "samba4包结构和依赖关系全面修复完成"