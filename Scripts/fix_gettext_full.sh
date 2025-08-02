#!/usr/bin/env bash
set -e

echo ">>> 开始修复 gettext-full / gperf 等 host 构建失败..."

cd "$(dirname "$0")/../wrt"

# 1. 生成 .config
[ -f .config ] || make defconfig

# 2. 分步预编译 host 工具链（串行编译）
echo ">>> 预编译 host 工具链 ..."
make tools/install
make toolchain/install

# 3. 彻底清理残留文件
echo ">>> 清理残留缓存 ..."
rm -rf build_dir/hostpkg/* staging_dir/hostpkg/* tmp/*

# 4. 设置环境变量
export LIBINTL=1
export BISON_LOCALEDIR=/usr/share/locale
export PATH=/mnt/build_wrt/staging_dir/host/bin:$PATH

# 5. 分步编译 gettext-full/host
echo ">>> 编译 gettext-full ..."
make package/libs/gettext-full/host/clean
make package/libs/gettext-full/host/compile V=s && echo "gettext-full 编译成功" || { echo "gettext-full 编译失败"; exit 1; }

echo ">>> gettext-full host 修复完成！"
