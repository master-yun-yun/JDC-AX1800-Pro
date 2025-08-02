#!/usr/bin/env bash
set -e
echo ">>> 开始修复 gettext-full / gperf 等 host 构建失败..."

cd "$(dirname "$0")/../wrt"

# 1. 先生成 .config，避免 menuconfig
[ -f .config ] || make defconfig

# 2. 先完整跑一遍 host/compile，保证 libdeflate-gzip 等工具就绪
echo ">>> 预编译 host 工具链 ..."
make -j$(nproc) tools/install
make -j$(nproc) toolchain/install

# 3. 清理 gettext-full & gperf 的残留缓存
rm -rf \
  build_dir/hostpkg/gettext-* \
  build_dir/hostpkg/gperf-* \
  staging_dir/hostpkg/stamp/.gettext-full_installed \
  staging_dir/hostpkg/stamp/.gperf_installed || true

# 4. 编译 gettext-full/host
export BISON_LOCALEDIR=/usr/share/locale
make package/libs/gettext-full/host/{clean,compile} -j$(nproc) V=s

echo ">>> gettext-full host 修复完成！"
