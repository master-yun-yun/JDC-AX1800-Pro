#!/bin/bash
# 修复所有samba4依赖关系

# 1. 修复backuppc的依赖
BACKUPPC_MAKEFILE="./wrt/feeds/packages/net/backuppc/Makefile"
if [ -f "$BACKUPPC_MAKEFILE" ]; then
    echo "修复backuppc依赖..."
    sed -i 's/samba4-client/samba4-client samba4-libs/g' "$BACKUPPC_MAKEFILE"
fi

# 2. 修复luci-app-samba4的依赖
LUCI_SAMBA_MAKEFILE="./wrt/feeds/luci/applications/luci-app-samba4/Makefile"
if [ -f "$LUCI_SAMBA_MAKEFILE" ]; then
    echo "修复luci-app-samba4依赖..."
    sed -i 's/samba4-server/samba4-server samba4-libs/g' "$LUCI_SAMBA_MAKEFILE"
fi

# 3. 修复unishare的依赖
UNISHARE_MAKEFILE="./wrt/package/unishare/Makefile"
if [ -f "$UNISHARE_MAKEFILE" ]; then
    echo "修复unishare依赖..."
    sed -i 's/samba4-server/samba4-server samba4-libs/g' "$UNISHARE_MAKEFILE"
fi

# 4. 确保所有samba4组件都被包含
echo "确保samba4组件完整..."
echo "CONFIG_PACKAGE_samba4-libs=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_samba4-server=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_samba4-client=y" >> ./wrt/.config
echo "CONFIG_PACKAGE_luci-app-samba4=y" >> ./wrt/.config

# 5. 创建必要的符号链接
mkdir -p ./wrt/staging_dir/target-*/usr/lib
ln -sf ../../../../lib/libc.so ./wrt/staging_dir/target-*/usr/lib/libcrypt.so.1 2>/dev/null

echo "所有samba4依赖关系已修复"