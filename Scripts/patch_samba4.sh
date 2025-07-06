#!/bin/bash
# 修复samba4依赖问题

SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"

if [ -f "$SAMBA_MAKEFILE" ]; then
    # 添加libcrypt依赖
    sed -i '/DEPENDS:=/ s/$/ +libcrypt/' "$SAMBA_MAKEFILE"
    
    # 确保链接到正确的库
    sed -i 's/--without-libcrypt/--with-libcrypt/g' "$SAMBA_MAKEFILE"
    
    echo "samba4 Makefile patched successfully"
else
    echo "Error: samba4 Makefile not found at $SAMBA_MAKEFILE"
    exit 1
fi