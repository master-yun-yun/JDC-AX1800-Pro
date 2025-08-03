#!/bin/bash
# fix_gettext.sh
# 专为云编译环境设计的 gettext 工具链修复脚本
# 解决：版本冲突、符号链接、动态库加载失败等问题
# 所有操作均在脚本内完成，无需后台权限或外部配置

set -e  # 出错立即退出
set -x  # 显示执行命令（便于调试）

echo "=== 开始修复 gettext 工具链版本冲突 ==="

# === 1. 安装编译依赖 ===
sudo apt-get update -y || true
sudo apt-get install -y --no-install-recommends \
  build-essential flex bison libtool autoconf automake m4 \
  libxml2-dev libncurses5-dev zlib1g-dev || true

# === 2. 下载并编译 gettext-0.20.1 ===
GETTEXT_VERSION="0.20.1"
GETTEXT_DIR="/tmp/gettext-${GETTEXT_VERSION}"
GETTEXT_URL="https://ftp.gnu.org/gnu/gettext/gettext-${GETTEXT_VERSION}.tar.gz"

mkdir -p "$GETTEXT_DIR"
cd "$GETTEXT_DIR"

# 下载
wget -q "$GETTEXT_URL" -O "gettext.tar.gz" || { echo "下载失败"; exit 1; }
tar -xf "gettext.tar.gz"
cd "gettext-${GETTEXT_VERSION}"

# 配置（关键：启用 shared library）
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
  --without-xz || { echo "配置失败"; exit 1; }

# 编译并安装
make -j$(nproc) || { echo "编译失败"; exit 1; }
sudo make install || { echo "安装失败"; exit 1; }

# === 3. 强制覆盖系统命令（确保使用新版本）===
sudo rm -f /usr/bin/gettext /usr/bin/xgettext /usr/bin/msgfmt /usr/bin/msgmerge
sudo ln -sf /usr/local/bin/gettext /usr/bin/gettext
sudo ln -sf /usr/local/bin/xgettext /usr/bin/xgettext
sudo ln -sf /usr/local/bin/msgfmt /usr/bin/msgfmt
sudo ln -sf /usr/local/bin/msgmerge /usr/bin/msgmerge

# === 4. 设置运行时环境变量（关键：解决 .so 加载问题）===
export PATH="/usr/local/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
export LIBINTL="libintl.so.8"
export LIBINTL_LDFLAGS="-L/usr/local/lib -lintl"
export BISON_LOCALEDIR="/usr/share/bison"

# === 5. 强制刷新动态链接器缓存（关键步骤）===
# 在云环境中，/etc/ld.so.conf 可能只读，因此直接写入缓存目录
echo '/usr/local/lib' | sudo tee /etc/ld.so.conf.d/99-gettext.conf > /dev/null || true
sudo ldconfig || true

# === 6. 验证安装结果 ===
echo "=== 验证 gettext 安装结果 ==="
which gettext
gettext --version || { echo "gettext 命令无法执行"; exit 1; }

echo "检查动态库："
ls -l /usr/local/lib/libgettextsrc*.so* || true

echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "LIBINTL_LDFLAGS: $LIBINTL_LDFLAGS"

# 测试 msgmerge 是否能运行
echo "测试 msgmerge..."
msgmerge --version || { echo "msgmerge 无法运行，请检查动态库"; exit 1; }

# === 7. 清理 OpenWrt 缓存（防止旧工具链残留）===
cd "$GITHUB_WORKSPACE/wrt" || { echo "进入 OpenWrt 目录失败"; exit 1; }
make clean || true
make dirclean || true
rm -rf build_dir/ tmp/ dl/ || true

echo "=== gettext 工具链修复完成 ==="
