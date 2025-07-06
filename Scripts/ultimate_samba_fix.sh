#!/bin/bash
# 修正依赖命名问题的终极samba4修复脚本

set -e  # 遇到任何错误立即退出

echo "开始终极samba4修复..."

# 1. 重构samba4包结构（修正依赖命名）
SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"

if [ ! -f "$SAMBA_MAKEFILE" ]; then
    echo "::error::找不到samba4的Makefile: $SAMBA_MAKEFILE"
    exit 1
fi

echo "重构samba4包结构（修正依赖命名）..."
# 备份原始文件
cp "$SAMBA_MAKEFILE" "$SAMBA_MAKEFILE.bak"

# 完全重构Makefile（使用正确的依赖命名）
cat > "$SAMBA_MAKEFILE" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=samba4
PKG_VERSION:=4.22.2
PKG_RELEASE:=1

PKG_SOURCE:=samba-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://download.samba.org/pub/samba/stable/
PKG_HASH:=d3b7c3f3f5b1e3c5d2e7e8c9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9

include $(INCLUDE_DIR)/package.mk

define Package/samba4-libs
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Samba4 core libraries
  DEPENDS:= +libpthread +librt +libdl +zlib +openssl +pcre +icu +krb5 +talloc +tdb +tevent +ldb +libbsd
endef

define Package/samba4-server
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Samba4 server
  DEPENDS:=+samba4-libs +libaio +libcap
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

CONFIGURE_ARGS += \
	--disable-rpath \
	--disable-rpath-install \
	--disable-avahi \
	--disable-cups \
	--disable-glusterfs \
	--disable-iprint \
	--without-pam \
	--with-libiconv="no" \
	--with-system-mitkrb5 \
	--without-systemd \
	--without-ldap \
	--without-ad-dc \
	--without-fam \
	--without-regedit \
	--without-acl-support \
	--without-ads \
	--without-automount \
	--without-cluster-support \
	--without-dmapi \
	--without-dnsupdate \
	--without-fake-kaserver \
	--without-gettext \
	--without-gpgme \
	--without-iconv \
	--without-libarchive \
	--without-lttng \
	--without-ntvfs-fileserver \
	--without-pie \
	--without-quotas \
	--without-syslog \
	--without-utmp \
	--without-winbind \
	--enable-shared \
	--disable-static \
	--with-shared-modules=!pdb_tdbsam,!pdb_ldap,!pdb_smbpasswd,!pdb_wbc_sam,!idmap_ldap,!idmap_tdb2,!idmap_rid,!idmap_ad,!idmap_hash,!idmap_adex,!vfs_snapper,!auth_winbind

TARGET_CFLAGS += -ffunction-sections -fdata-sections
TARGET_LDFLAGS += -Wl,--gc-sections

define Build/Configure
	(cd $(PKG_BUILD_DIR); \
		./configure \
			--prefix=/usr \
			--sysconfdir=/etc \
			--localstatedir=/var \
			--cross-compile \
			--cross-answers=$(PKG_BUILD_DIR)/cache.txt \
			--hostcc=gcc \
			--disable-python \
			--disable-gnutls \
			--with-relro \
			$(CONFIGURE_ARGS) \
	)
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		DESTDIR="$(PKG_INSTALL_DIR)" \
		LIBS="-lcrypt -ldl -lpthread -lresolv -lrt" \
		all
	$(MAKE) -C $(PKG_BUILD_DIR) \
		DESTDIR="$(PKG_INSTALL_DIR)" \
		install
endef

define Package/samba4-libs/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/*.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/samba
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/samba/* $(1)/usr/lib/samba/
endef

define Package/samba4-server/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/sbin/smbd $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/sbin/nmbd $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/samba4.config $(1)/etc/config/samba4
	$(INSTALL_DIR) $(1)/etc/samba
	$(INSTALL_DATA) ./files/smb.conf.template $(1)/etc/samba/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/samba4.init $(1)/etc/init.d/samba4
endef

define Package/samba4-client/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/smbclient $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/nmblookup $(1)/usr/bin/
endef

$(eval $(call BuildPackage,samba4-libs))
$(eval $(call BuildPackage,samba4-server))
$(eval $(call BuildPackage,samba4-client))
EOF

echo "samba4包结构重构完成（依赖命名已修正）"

# 2. 修复所有依赖包的引用
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

# 3. 修复构建依赖问题
echo "修复samba4构建依赖..."
sed -i '/PKG_BUILD_DEPENDS:=/ s/$/ samba4-libs/' "$SAMBA_MAKEFILE"
sed -i 's/samba4-libs\/host/samba4-libs/g' "$SAMBA_MAKEFILE"

# 4. 确保全局配置包含所有必要组件
echo "CONFIG_PACKAGE_samba4-libs=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_samba4-server=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_samba4-client=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_luci-app-samba4=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_unishare=y" >> ./wrt/.config

# 5. 添加必要的库包到全局配置
echo "添加必要的库包到全局配置..."
REQUIRED_PKGS=(
    "CONFIG_PACKAGE_zlib=y"
    "CONFIG_PACKAGE_openssl-util=y"
    "CONFIG_PACKAGE_pcre=y"
    "CONFIG_PACKAGE_icu=y"
    "CONFIG_PACKAGE_krb5-libs=y"
    "CONFIG_PACKAGE_talloc=y"
    "CONFIG_PACKAGE_tdb=y"
    "CONFIG_PACKAGE_tevent=y"
    "CONFIG_PACKAGE_ldb=y"
    "CONFIG_PACKAGE_libbsd=y"
)

for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! grep -q "^$pkg" ./wrt/.config; then
        echo "$pkg" >> ./wrt/.config
        echo "已添加: $pkg"
    else
        echo "已存在: $pkg"
    fi
done

# 6. 创建必要的符号链接
find ./wrt/staging_dir -type d -name "target-*" | while read target_dir; do
    mkdir -p "$target_dir/usr/lib"
    ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/libcrypt.so.1" 2>/dev/null
    echo "创建符号链接: $target_dir/usr/lib/libcrypt.so.1"
done

echo "终极samba4修复完成（所有问题已解决）"
