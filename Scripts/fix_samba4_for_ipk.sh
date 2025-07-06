#!/bin/bash
# 精确依赖修复方案

set -e

echo "开始精确修复依赖关系..."

# 1. 精确修复所有依赖声明（避免双重替换）
fix_dependency() {
    local file=$1
    local target=$2
    local replacement=$3
    
    if [ -f "$file" ]; then
        echo "修复 $file: $target -> $replacement"
        # 使用精确边界匹配，避免嵌套替换
        sed -i "s/\b${target}\b/${replacement}/g" "$file"
    fi
}

# 2. 修复 samba4 相关依赖
find ./wrt/ -type f -name "Makefile" | while read makefile; do
    # 避免重复替换
    if grep -q "samba4-server" "$makefile" && ! grep -q "virtual-samba4-server" "$makefile"; then
        fix_dependency "$makefile" "samba4-server" "samba4-server"
    fi
    
    if grep -q "samba4-client" "$makefile" && ! grep -q "virtual-samba4-client" "$makefile"; then
        fix_dependency "$makefile" "samba4-client" "samba4-client"
    fi
done

# 3. 特别处理 unishare
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
  DEPENDS:=+samba4-server
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
fi

# 4. 确保所有必要包被包含
echo "确保所有必要包被包含..."
ESSENTIAL_CONFIGS=(
    "CONFIG_PACKAGE_samba4-libs=y"
    "CONFIG_PACKAGE_samba4-server=y"
    "CONFIG_PACKAGE_samba4-client=y"
    "CONFIG_PACKAGE_luci-app-samba4=y"
    "CONFIG_PACKAGE_unishare=y"
    "CONFIG_PACKAGE_zlib=y"
    "CONFIG_PACKAGE_libopenssl=y"
    "CONFIG_PACKAGE_libpcre=y"
    "CONFIG_PACKAGE_icu=y"
    "CONFIG_PACKAGE_krb5-libs=y"
    "CONFIG_PACKAGE_talloc=y"
    "CONFIG_PACKAGE_tdb=y"
    "CONFIG_PACKAGE_tevent=y"
    "CONFIG_PACKAGE_ldb=y"
    "CONFIG_PACKAGE_libbsd=y"
    "CONFIG_PACKAGE_libaio=y"
    "CONFIG_PACKAGE_libcap=y"
)

for config in "${ESSENTIAL_CONFIGS[@]}"; do
    if ! grep -q "^$config" ./wrt/.config; then
        echo "$config" >> ./wrt/.config
        echo "已添加配置: $config"
    fi
done

# 5. 创建必要的库链接
create_lib_links() {
    local target_dir=$1
    
    # 创建基本库链接
    for lib in dl pthread rt; do
        [ -e "$target_dir/usr/lib/lib$lib.so" ] || \
        ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/lib$lib.so" 2>/dev/null
    done
    
    # 创建特定库链接
    [ -e "$target_dir/usr/lib/libcrypt.so.1" ] || \
    ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/libcrypt.so.1" 2>/dev/null
    
    [ -e "$target_dir/usr/lib/libpcre.so" ] || \
    ln -sf "libpcre2.so" "$target_dir/usr/lib/libpcre.so" 2>/dev/null
    
    [ -e "$target_dir/usr/lib/libkrb5support.so" ] || \
    ln -sf "libkrb5support.so.0" "$target_dir/usr/lib/libkrb5support.so" 2>/dev/null
}

find ./wrt/staging_dir -type d -name "target-*" | while read target_dir; do
    echo "处理目标架构: $(basename "$target_dir")"
    create_lib_links "$target_dir"
done

# 6. 简化 samba4 的 Makefile
SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"
if [ -f "$SAMBA_MAKEFILE" ]; then
    echo "简化 samba4 Makefile..."
    
    # 备份原始文件
    cp "$SAMBA_MAKEFILE" "$SAMBA_MAKEFILE.bak"
    
    # 使用最小依赖集
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
  DEPENDS:=+zlib +libopenssl +libpcre +icu +krb5-libs +talloc +tdb +tevent +ldb +libbsd
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
	--disable-static

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
fi

echo "精确依赖修复完成"
