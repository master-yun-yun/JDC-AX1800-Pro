#!/bin/bash
# 修复samba4核心依赖

# 1. 确保libcrypt被包含
echo "CONFIG_PACKAGE_libcrypt=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_libcrypt-dev=y" >> ./wrt/.config

# 2. 修改samba4的Makefile
SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"
if [ -f "$SAMBA_MAKEFILE" ]; then
    echo "修复samba4 Makefile..."
    sed -i '/DEPENDS:=/ s/$/ +libcrypt/' "$SAMBA_MAKEFILE"
    sed -i 's/--without-libcrypt/--with-libcrypt/g' "$SAMBA_MAKEFILE"
    sed -i 's/\(PKG_BUILD_DEPENDS:=\)/\1 libcrypt/' "$SAMBA_MAKEFILE"
fi

# 3. 创建符号链接
mkdir -p ./wrt/staging_dir/target-*/usr/lib
ln -sf ../../../../lib/libc.so ./wrt/staging_dir/target-*/usr/lib/libcrypt.so.1 2>/dev/null

echo "samba4核心依赖修复完成"