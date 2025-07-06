#!/bin/bash
# 修复samba4的libcrypt依赖问题

# 1. 确保libcrypt被包含在构建中
echo "CONFIG_PACKAGE_libcrypt=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_libcrypt-dev=y" >> ./wrt/.config

# 2. 修改samba4的Makefile添加依赖
SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"

if [ -f "$SAMBA_MAKEFILE" ]; then
    echo "修复samba4 Makefile..."
    
    # 添加libcrypt依赖
    sed -i '/DEPENDS:=/ s/$/ +libcrypt/' "$SAMBA_MAKEFILE"
    
    # 确保链接到正确的库
    sed -i 's/--without-libcrypt/--with-libcrypt/g' "$SAMBA_MAKEFILE"
    
    # 添加缺少的库路径
    sed -i 's/\(PKG_BUILD_DEPENDS:=\)/\1 libcrypt/' "$SAMBA_MAKEFILE"
    
    echo "samba4 Makefile修复完成"
else
    echo "警告：未找到samba4 Makefile，跳过修复"
fi

# 3. 创建必要的符号链接
mkdir -p ./wrt/staging_dir/target-aarch64_cortex-a53_musl/usr/lib
ln -sf ../../../../lib/libc.so ./wrt/staging_dir/target-aarch64_cortex-a53_musl/usr/lib/libcrypt.so.1

echo "samba4依赖修复完成"