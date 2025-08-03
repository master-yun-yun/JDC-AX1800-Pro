#!/bin/bash
# fix_gettext.sh
# 强制覆盖 gettext 工具链版本（适用于云编译环境）

set -e  # 出错时立即退出
set -x  # 显示执行命令（便于调试）

echo "=== 开始修复 gettext 工具链版本冲突 ==="

# === 第一步：安装依赖 ===
sudo apt-get update || { echo "apt-get update 失败"; exit 1; }
sudo apt-get install -y --no-install-recommends \
  build-essential flex bison libtool autoconf automake m4 || { echo "安装依赖失败"; exit 1; }

# === 第二步：下载并编译 gettext-0.20.1 ===
GETTEXT_VERSION="0.20.1"
GETTEXT_DIR="/tmp/gettext-${GETTEXT_VERSION}"
GETTEXT_URL="https://ftp.gnu.org/gnu/gettext/gettext-${GETTEXT_VERSION}.tar.gz"

# 创建临时目录
mkdir -p "$GETTEXT_DIR" || { echo "创建目录失败: $GETTEXT_DIR"; exit 1; }
cd "$GETTEXT_DIR" || { echo "进入目录失败: $GETTEXT_DIR"; exit 1; }

# 下载源码
wget -q "$GETTEXT_URL" -O "gettext-${GETTEXT_VERSION}.tar.gz" || { echo "下载 gettext 源码失败"; exit 1; }

# 解压并编译
tar -xf "gettext-${GETTEXT_VERSION}.tar.gz" || { echo "解压失败"; exit 1; }
cd "gettext-${GETTEXT_VERSION}" || { echo "进入解压目录失败"; exit 1; }
./configure --prefix=/usr/local || { echo "配置失败"; exit 1; }
make -j$(nproc) || { echo "编译失败"; exit 1; }
sudo make install || { echo "安装失败"; exit 1; }

# === 第三步：强制覆盖系统路径 ===
# 删除旧版本
sudo rm -f /usr/bin/gettext /usr/bin/xgettext /usr/bin/msgfmt /usr/bin/msgmerge || { echo "删除旧版本失败"; exit 1; }

# 创建符号链接到新版本
sudo ln -sf /usr/local/bin/gettext /usr/bin/gettext || { echo "创建符号链接失败: gettext"; exit 1; }
sudo ln -sf /usr/local/bin/xgettext /usr/bin/xgettext || { echo "创建符号链接失败: xgettext"; exit 1; }
sudo ln -sf /usr/local/bin/msgfmt /usr/bin/msgfmt || { echo "创建符号链接失败: msgfmt"; exit 1; }
sudo ln -sf /usr/local/bin/msgmerge /usr/bin/msgmerge || { echo "创建符号链接失败: msgmerge"; exit 1; }

# === 第四步：设置环境变量 ===
export BISON_LOCALEDIR=/usr/share/bison
export PATH=/usr/local/bin:$PATH
export LIBINTL=libintl.so.8
export LIBINTL_LDFLAGS="-L/usr/local/lib"

# 验证版本匹配
GETTEXT_VERSION=$(gettext --version | grep -oP '([0-9]+\.){2}[0-9]+') || { echo "获取 gettext 版本失败"; exit 1; }
AUTOCONF_VERSION=$(autoconf --version | grep -oP '([0-9]+\.){2}[0-9]+') || { echo "获取 autoconf 版本失败"; exit 1; }
AUTOMAKE_VERSION=$(automake --version | grep -oP '([0-9]+\.){2}[0-9]+') || { echo "获取 automake 版本失败"; exit 1; }

echo "当前工具链版本："
echo "gettext: $GETTEXT_VERSION"
echo "autoconf: $AUTOCONF_VERSION"
echo "automake/XMLSchema
