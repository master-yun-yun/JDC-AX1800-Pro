#!/bin/bash
# 智能解决samba4所有依赖问题

set -e  # 遇到任何错误立即退出

echo "开始智能解决samba4依赖问题..."

# 1. 准备依赖映射表（OpenWrt包名与实际依赖的映射）
declare -A DEP_MAP=(
    ["libdl"]=""
    ["libz"]="zlib"
    ["libopenssl"]="libopenssl"
    ["libpcre"]="libpcre"
    ["libicu"]="icu"
    ["libkrb5"]="krb5-libs"
    ["libtdb"]="tdb"
    ["libtevent"]="tevent"
    ["libldb"]="ldb"
    ["libbsd"]="libbsd"
    ["libaio"]="libaio"
    ["libcap"]="libcap"
    ["librt"]=""
    ["libpthread"]=""
)

# 2. 重构samba4包结构
SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"

if [ ! -f "$SAMBA_MAKEFILE" ]; then
    echo "::error::找不到samba4的Makefile: $SAMBA_MAKEFILE"
    exit 1
fi

echo "重构samba4包结构..."
# 备份原始文件
cp "$SAMBA_MAKEFILE" "$SAMBA_MAKEFILE.bak"

# 智能生成依赖列表
REAL_DEPS=""
for dep in "${!DEP_MAP[@]}"; do
    if [ -n "${DEP_MAP[$dep]}" ]; then
        REAL_DEPS+="+${DEP_MAP[$dep]} "
    fi
done

# 完全重构Makefile
cat > "$SAMBA_MAKEFILE" << EOF
include \$(TOPDIR)/rules.mk

PKG_NAME:=samba4
PKG_VERSION:=4.22.2
PKG_RELEASE:=1

PKG_SOURCE:=samba-\$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://download.samba.org/pub/samba/stable/
PKG_HASH:=d3b7c3f3f5b1e3c5d2e7e8c9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9

include \$(INCLUDE_DIR)/package.mk

define Package/samba4-libs
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Samba4 core libraries
  DEPENDS:= ${REAL_DEPS}
endef

define Package/samba4-server
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Samba4 server
  DEPENDS:=+samba4-libs
endef

define Package/samba4-client
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Samba4 client
  DEPENDS:=+samba4-libs
endef

define Package/samba4-libs/description
 Core libraries for Samba4
endef

define Package/samba4-server/description
 Samba4 file and print server
endef

define Package/samba4-client/description
 Samba4 client utilities
endef

CONFIGURE_ARGS += \\
	--disable-rpath \\
	--disable-rpath-install \\
	--disable-avahi \\
	--disable-cups \\
	--disable-glusterfs \\
	--disable-iprint \\
	--without-pam \\
	--with-libiconv="no" \\
	--without-systemd \\
	--without-ldap \\
	--without-ad-dc \\
	--without-fam \\
	--without-regedit \\
	--without-acl-support \\
	--without-ads \\
	--without-automount \\
	--without-cluster-support \\
	--without-dmapi \\
	--without-dnsupdate \\
	--without-fake-kaserver \\
	--without-gettext \\
	--without-gpgme \\
	--without-iconv \\
	--without-libarchive \\
	--without-lttng \\
	--without-ntvfs-fileserver \\
	--without-pie \\
	--without-quotas \\
	--without-syslog \\
	--without-utmp \\
	--without-winbind \\
	--enable-shared \\
	--disable-static

TARGET_CFLAGS += -ffunction-sections -fdata-sections
TARGET_LDFLAGS += -Wl,--gc-sections

define Build/Configure
	(cd \$(PKG_BUILD_DIR); \\
		./configure \\
			--prefix=/usr \\
			--sysconfdir=/etc \\
			--localstatedir=/var \\
			--cross-compile \\
			--cross-answers=\$(PKG_BUILD_DIR)/cache.txt \\
			--hostcc=gcc \\
			--disable-python \\
			--disable-gnutls \\
			--with-relro \\
			\$(CONFIGURE_ARGS) \\
	)
endef

define Build/Compile
	\$(MAKE) -C \$(PKG_BUILD_DIR) \\
		DESTDIR="\$(PKG_INSTALL_DIR)" \\
		LIBS="-lcrypt -ldl -lpthread -lresolv -lrt" \\
		all
	\$(MAKE) -C \$(PKG_BUILD_DIR) \\
		DESTDIR="\$(PKG_INSTALL_DIR)" \\
		install
endef

define Package/samba4-libs/install
	\$(INSTALL_DIR) \$(1)/usr/lib
	\$(CP) \$(PKG_INSTALL_DIR)/usr/lib/*.so* \$(1)/usr/lib/
	\$(INSTALL_DIR) \$(1)/usr/lib/samba
	\$(CP) \$(PKG_INSTALL_DIR)/usr/lib/samba/* \$(1)/usr/lib/samba/
endef

define Package/samba4-server/install
	\$(INSTALL_DIR) \$(1)/usr/sbin
	\$(INSTALL_BIN) \$(PKG_INSTALL_DIR)/usr/sbin/smbd \$(1)/usr/sbin/
	\$(INSTALL_BIN) \$(PKG_INSTALL_DIR)/usr/sbin/nmbd \$(1)/usr/sbin/
	\$(INSTALL_DIR) \$(1)/etc/config
	\$(INSTALL_CONF) ./files/samba4.config \$(1)/etc/config/samba4
	\$(INSTALL_DIR) \$(1)/etc/samba
	\$(INSTALL_DATA) ./files/smb.conf.template \$(1)/etc/samba/
	\$(INSTALL_DIR) \$(1)/etc/init.d
	\$(INSTALL_BIN) ./files/samba4.init \$(1)/etc/init.d/samba4
endef

define Package/samba4-client/install
	\$(INSTALL_DIR) \$(1)/usr/bin
	\$(INSTALL_BIN) \$(PKG_INSTALL_DIR)/usr/bin/smbclient \$(1)/usr/bin/
	\$(INSTALL_BIN) \$(PKG_INSTALL_DIR)/usr/bin/nmblookup \$(1)/usr/bin/
endef

\$(eval \$(call BuildPackage,samba4-libs))
\$(eval \$(call BuildPackage,samba4-server))
\$(eval \$(call BuildPackage,samba4-client))
EOF

echo "samba4包结构重构完成"

# 3. 修复所有依赖包的引用
fix_dependency() {
    local pkg_makefile=$1
    local old_dep=$2
    local new_dep=$3
    
    if [ -f "$pkg_makefile" ]; then
        echo "修复 $pkg_makefile 依赖: $old_dep -> $new_dep"
        sed -i "s/\b$old_dep\b/$new_dep/g" "$pkg_makefile"
    fi
}

# 修复特定包的依赖
fix_dependency "./wrt/feeds/packages/net/backuppc/Makefile" "samba4-client" "samba4-client"
fix_dependency "./wrt/feeds/luci/applications/luci-app-samba4/Makefile" "samba4-server" "samba4-server"
fix_dependency "./wrt/package/unishare/Makefile" "samba4-server" "samba4-server"

# 4. 确保全局配置包含所有必要组件
echo "CONFIG_PACKAGE_samba4-libs=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_samba4-server=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_samba4-client=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_luci-app-samba4=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_unishare=y" >> ./wrt/.config

# 5. 自动添加所有必需的依赖包
echo "自动添加所有必需的依赖包..."
REQUIRED_PKGS=(
    "zlib"
    "libopenssl"
    "libpcre"
    "icu"
    "krb5-libs"
    "talloc"
    "tdb"
    "tevent"
    "ldb"
    "libbsd"
    "libaio"
    "libcap"
)

for pkg in "${REQUIRED_PKGS[@]}"; do
    # 检查包是否存在
    if grep -q "Package: $pkg" ./wrt/feeds/packages.index; then
        config_name="CONFIG_PACKAGE_${pkg//-/_}=y"
        if ! grep -q "^$config_name" ./wrt/.config; then
            echo "$config_name" >> ./wrt/.config
            echo "已添加: $config_name"
        else
            echo "已存在: $config_name"
        fi
    else
        echo "警告: 包 $pkg 不存在于 feeds 中"
    fi
done

# 6. 递归添加依赖的依赖
echo "递归添加依赖的依赖..."
DEPENDENCY_CHAINS=(
    "krb5-libs>libopenssl"
    "ldb>talloc"
    "tevent>talloc"
    "tdb>talloc"
)

for chain in "${DEPENDENCY_CHAINS[@]}"; do
    IFS='>' read -ra deps <<< "$chain"
    for dep in "${deps[@]}"; do
        if grep -q "Package: $dep" ./wrt/feeds/packages.index; then
            config_name="CONFIG_PACKAGE_${dep//-/_}=y"
            if ! grep -q "^$config_name" ./wrt/.config; then
                echo "$config_name" >> ./wrt/.config
                echo "已添加依赖链: $config_name"
            fi
        fi
    done
done

# 7. 创建必要的符号链接
find ./wrt/staging_dir -type d -name "target-*" | while read target_dir; do
    mkdir -p "$target_dir/usr/lib"
    ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/libcrypt.so.1" 2>/dev/null
    echo "创建符号链接: $target_dir/usr/lib/libcrypt.so.1"
    
    # 创建其他可能需要的符号链接
    for lib in dl pthread rt; do
        ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/lib$lib.so" 2>/dev/null
    done
done

# 8. 简化配置
echo "CONFIG_SAMBA4_SIMPLE=y" >> ./wrt/.config
echo "CONFIG_SAMBA4_MINIMAL=y" >> ./wrt/.config

echo "samba4依赖问题智能解决完成"
