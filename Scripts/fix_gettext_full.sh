#!/usr/bin/env bash
set -e
echo ">>> 开始修复 gettext-full host 构建失败..."

cd "$(dirname "$0")/../wrt"

# 1. 立即生成 .config，避免后续误触发 menuconfig
if [ ! -f .config ]; then
    # 用 defconfig 代替 menuconfig
    make defconfig
fi

# 2. 清理旧的 host 构建缓存（可选）
rm -rf \
  build_dir/hostpkg/gettext-full-* \
  staging_dir/hostpkg/usr/lib/libintl* \
  staging_dir/hostpkg/usr/include/libintl.h || true

# 3. 设置 BISON_LOCALEDIR
export BISON_LOCALEDIR=/usr/share/locale

# 4. 只编译 gettext-full/host，不再触发 menuconfig
make package/libs/gettext-full/host/{clean,compile} -j1 V=s

echo ">>> gettext-full host 修复完成！"
