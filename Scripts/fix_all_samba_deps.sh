#!/bin/bash
# 全面修复所有samba4依赖关系

echo "开始修复所有samba4依赖关系..."

# 1. 修复所有包的依赖声明
find ./wrt/ -type f -name "Makefile" | while read makefile; do
    # 修复samba4-client依赖
    sed -i 's/\bsamba4-client\b/samba4-libs/g' "$makefile"
    
    # 修复samba4-server依赖
    sed -i 's/\bsamba4-server\b/samba4-libs/g' "$makefile"
    
    # 修复samba4依赖
    sed -i 's/\bsamba4\b/samba4-libs/g' "$makefile"
done

# 2. 确保全局配置包含所有必要组件
CONFIG_LINES=(
    "CONFIG_PACKAGE_samba4-libs=y"
    "CONFIG_PACKAGE_samba4-server=y"
    "CONFIG_PACKAGE_samba4-client=y"
    "CONFIG_PACKAGE_luci-app-samba4=y"
)

for line in "${CONFIG_LINES[@]}"; do
    if ! grep -q "^$line" ./wrt/.config; then
        echo "$line" >> ./wrt/.config
        echo "已添加配置: $line"
    fi
done

# 3. 创建必要的符号链接
find ./wrt/staging_dir -type d -name "target-*" | while read target_dir; do
    mkdir -p "$target_dir/usr/lib"
    ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/libcrypt.so.1" 2>/dev/null
    echo "创建符号链接: $target_dir/usr/lib/libcrypt.so.1"
done

echo "所有samba4依赖关系修复完成"