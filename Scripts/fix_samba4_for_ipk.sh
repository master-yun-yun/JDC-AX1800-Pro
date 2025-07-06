#!/bin/bash
# 专门解决 ipk 模式下 samba4 编译问题

set -e

echo "修复 ipk 模式下的 samba4 问题..."

# 1. 修复包命名差异
RENAME_MAP=(
    "libpcre=>libpcre2"
    "libicu=>icu"
    "libkrb5=>krb5-libs"
    "libtdb=>tdb"
    "libtevent=>tevent"
    "libldb=>ldb"
)

for mapping in "${RENAME_MAP[@]}"; do
    old=${mapping%=>*}
    new=${mapping#*=>}
    
    # 在 Makefile 中修复依赖声明
    find ./wrt/ -name "Makefile" -exec sed -i "s/\b$old\b/$new/g" {} +
    
    # 在配置中启用正确的包
    if ! grep -q "CONFIG_PACKAGE_$new=y" ./wrt/.config; then
        echo "CONFIG_PACKAGE_$new=y" >> ./wrt/.config
        echo "已添加配置: CONFIG_PACKAGE_$new=y"
    fi
done

# 2. 创建必要的符号链接
echo "创建库符号链接..."
find ./wrt/staging_dir -type d -name "target-*" | while read target_dir; do
    echo "处理架构: $(basename $target_dir)"
    
    # 创建通用库链接
    for lib in dl pthread rt; do
        ln -sf "../../../../lib/libc.so" "$target_dir/usr/lib/lib$lib.so" 2>/dev/null || true
    done
    
    # 创建特定库链接
    ln -sf "libpcre2.so" "$target_dir/usr/lib/libpcre.so" 2>/dev/null || true
    ln -sf "libkrb5support.so.0" "$target_dir/usr/lib/libkrb5support.so" 2>/dev/null || true
done

# 3. 修复 samba4 的 Makefile
SAMBA_MAKEFILE="./wrt/feeds/packages/net/samba4/Makefile"
if [ -f "$SAMBA_MAKEFILE" ]; then
    echo "修复 samba4 Makefile..."
    
    # 修正依赖声明
    sed -i 's/DEPENDS:=.*/DEPENDS:= +zlib +libopenssl +pcre +icu +krb5-libs +talloc +tdb +tevent +ldb +libbsd +libaio +libcap/' "$SAMBA_MAKEFILE"
    
    # 添加缺失的构建依赖
    sed -i '/PKG_BUILD_DEPENDS:=/ s/$/ +zlib +libopenssl +pcre +icu/' "$SAMBA_MAKEFILE"
    
    # 修复主机工具依赖
    sed -i 's/samba4-libs\/host/samba4-libs/g' "$SAMBA_MAKEFILE"
fi

# 4. 添加 apk 风格的依赖解析（模拟 apk 行为）
echo "添加 apk 风格依赖解析..."
cat > ./wrt/scripts/ipk-deps-resolver << 'EOF'
#!/bin/sh
# 模拟 apk 的依赖解析行为

resolve_dep() {
    case "$1" in
        libdl) echo "libc" ;;
        libpthread) echo "libc" ;;
        librt) echo "libc" ;;
        libz) echo "zlib" ;;
        libpcre) echo "pcre" ;;
        libicu) echo "icu" ;;
        libkrb5) echo "krb5-libs" ;;
        libtdb) echo "tdb" ;;
        libtevent) echo "tevent" ;;
        libldb) echo "ldb" ;;
        *) echo "$1" ;;
    esac
}

for dep in "$@"; do
    resolved=$(resolve_dep "$dep")
    [ -n "$resolved" ] && echo "+$resolved"
done | sort -u | tr '\n' ' '
EOF

chmod +x ./wrt/scripts/ipk-deps-resolver

# 5. 修改 OpenWrt 构建系统使用我们的解析器
find ./wrt -name "mk.config" -exec sed -i 's|/usr/bin/find|/bin/bash|g' {} +
find ./wrt -name "package.mk" -exec sed -i 's|@(DEPENDS)|@(./scripts/ipk-deps-resolver $(DEPENDS))|g' {} +

# 6. 确保所有必要包已启用
REQUIRED_PKGS=(
    "zlib" "libopenssl" "pcre" "icu"
    "krb5-libs" "talloc" "tdb" "tevent"
    "ldb" "libbsd" "libaio" "libcap"
)

for pkg in "${REQUIRED_PKGS[@]}"; do
    config_name="CONFIG_PACKAGE_${pkg//-/_}=y"
    if ! grep -q "^$config_name" ./wrt/.config; then
        echo "$config_name" >> ./wrt/.config
        echo "已添加: $config_name"
    fi
done

echo "ipk 模式下的 samba4 修复完成"