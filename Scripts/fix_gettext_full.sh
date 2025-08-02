#!/usr/bin/env bash
#
# 手动修复 gettext-full host 构建失败
# 用法：直接执行即可，需位于 openwrt 根目录下运行
#

set -e

echo ">>> 开始修复 gettext-full host 构建失败..."

# 进入源码目录
cd "$(dirname "$0")/../wrt" || exit 1

# 清理旧的 host 构建缓存（可选，避免干扰）
rm -rf \
  build_dir/hostpkg/gettext-full-* \
  staging_dir/hostpkg/usr/lib/libintl* \
  staging_dir/hostpkg/usr/include/libintl.h || true

# 修复缺失的 BISON_LOCALEDIR 环境变量
export BISON_LOCALEDIR=/usr/share/locale

# 重新编译 host 阶段的 gettext-full
make package/libs/gettext-full/host/{clean,compile} -j1 V=s

echo ">>> gettext-full host 修复完成！"
