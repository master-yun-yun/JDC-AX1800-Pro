#!/bin/bash
# fix_gettext.sh
# 专为云编译环境设计的终极 gettext 工具链修复脚本
# 功能：下载、编译、安装 gettext-0.20.1，强制覆盖系统命令，解决动态库加载问题
# 特点：无需外部干预，兼容 GitHub Actions 等 CI/CD 环境，确保 quilt 等工具可正常编译
# 作者：Qwen
# 日期：2025年

set -euo pipefail  # 严格模式：出错退出、未定义变量退出、管道错误退出

echo "=== 开始修复 gettext 工具链版本冲突 ==="

# 设置变量
GETTEXT_VERSION="0.20.1"
GETTEXT_DIR="/tmp/gettext-${GETTEXT_VERSION}"
GETTEXT_URL="https://ftp.gnu.org/gnu/gettext/gettext-${GETTEXT_VERSION}.tar.gz"

# === 1. 安装编译依赖 ===
echo "=== 安装编译依赖 ==="
sudo apt-get update -y || true
sudo apt-get install -y --no-install-recommends \
  build-essential \
  flex \
  bison \
  libtool \
  autoconf \
  automake \
  m4 \
  libxml2-dev \
  libncurses5-dev \
  zlib1g-dev \
  wget \
  tar \
  sudo || true

# === 2. 下载并解压 gettext 源码 ===
echo "=== 下载并解压 gettext-${GETTEXT_VERSION} ==="
mkdir -p "$GETTEXT_DIR"
cd "$GETTEXT_DIR"

if [[ ! -f "gettext-${GETTEXT_VERSION}.tar.gz" ]]; then
  wget -q --show-progress "$GETTEXT_URL" -O "gettext-${GETTEXT_VERSION}.tar.gz" || \
    { echo "❌ 下载失败：$GETTEXT_URL"; exit 1; }
fi

tar -xf "gettext-${GETTEXT_VERSION}.tar.gz" || \
  { echo "❌ 解压失败"; exit 1; }

cd "gettext-${GETTEXT_VERSION}" || \
  { echo "❌ 进入目录失败：gettext-${GETTEXT_VERSION}"; exit 1; }

# === 3. 配置（启用共享库，关键！）===
echo "=== 配置 gettext ==="
./configure \
  --prefix=/usr/local \
  --enable-shared \
  --disable-static \
  --with-included-gettext \
  --with-included-glib \
  --with-included-libcroco \
  --with-included-libunistring \
  --disable-java \
  --disable-csharp \
  --without-git \
  --without-cvs \
  --without-xz \
  --disable-libasprintf \
  --disable-c++ \
  --disable-threads \
  --disable-openmp || \
  { echo "❌ 配置失败"; exit 1; }

# === 4. 编译并安装 ===
echo "=== 编译并安装 gettext ==="
make -j$(nproc) || { echo "❌ 编译失败"; exit 1; }
sudo make install || { echo "❌ 安装失败"; exit 1; }

# === 5. 强制覆盖系统命令（确保使用新版本）===
echo "=== 覆盖系统命令 ==="
sudo rm -f /usr/bin/gettext /usr/bin/xgettext /usr/bin/msgfmt /usr/bin/msgmerge
sudo ln -sf /usr/local/bin/gettext /usr/bin/gettext
sudo ln -sf /usr/local/bin/xgettext /usr/bin/xgettext
sudo ln -sf /usr/local/bin/msgfmt /usr/bin/msgfmt
sudo ln -sf /usr/local/bin/msgmerge /usr/bin/msgmerge

# === 6. 设置运行时环境变量 ===
export PATH="/usr/local/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
export LIBINTL="libintl.so.8"
export LIBINTL_LDFLAGS="-L/usr/local/lib -lintl"
export BISON_LOCALEDIR="/usr/share/bison"

# === 7. 刷新动态链接器缓存（关键）===
echo "=== 刷新动态链接器缓存 ==="
echo '/usr/local/lib' | sudo tee /etc/ld.so.conf.d/99-gettext.conf > /dev/null || true
sudo ldconfig || { echo "⚠️ ldconfig 警告，但通常不影响结果"; }

# === 8. 验证安装结果 ===
echo "=== 验证安装结果 ==="
if ! command -v gettext >/dev/null 2>&1; then
  echo "❌ gettext 命令不可用"
  exit 1
fi

if ! command -v msgmerge >/dev/null 2>&1; then
  echo "❌ msgmerge 命令不可用"
  exit 1
fi

echo "✅ gettext 版本: $(gettext --version | head -1)"
echo "✅ msgmerge 版本: $(msgmerge --version | head -1)"
echo "✅ 动态库路径: $(ls /usr/local/lib/libgettextsrc*.so* 2>/dev/null || echo '未找到')"

# === 9. 写入 GitHub 环境变量（确保后续步骤可用）===
echo "=== 写入环境变量到 GitHub 环境 ==="
echo "PATH=/usr/local/bin:$PATH" >> $GITHUB_ENV
echo "LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH" >> $GITHUB_ENV
echo "LIBINTL_LDFLAGS=-L/usr/local/lib -lintl" >> $GITHUB_ENV
echo "BISON_LOCALEDIR=/usr/share/bison" >> $GITHUB_ENV

# === 10. 清理 OpenWrt 缓存（防止旧环境干扰）===
echo "=== 清理 OpenWrt 构建缓存 ==="
cd "$GITHUB_WORKSPACE/wrt" 2>/dev/null || cd "$GITHUB_WORKSPACE/openwrt" 2>/dev/null || {
  echo "⚠️ 未找到 OpenWrt 目录，跳过清理"
  cd /tmp
}

make clean || true
make dirclean || true
rm -rf build_dir/ tmp/ staging_dir/ || true

# === 11. 强制导出环境变量到当前 shell ===
export PATH="/usr/local/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
export LIBINTL="libintl.so.8"
export LIBINTL_LDFLAGS="-L/usr/local/lib -lintl"
export BISON_LOCALEDIR="/usr/share/bison"

echo "=== ✅ gettext 工具链修复完成 ==="
echo "所有命令已就绪，环境变量已写入，可开始构建 OpenWrt 固件。"
