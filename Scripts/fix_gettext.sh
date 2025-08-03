#!/bin/bash
# fix_gettext.sh
# 修复 gettext 工具链版本冲突

set -e  # 出错时立即退出

echo "=== 开始修复 gettext 工具链版本冲突 ==="

# 安装必要依赖
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  bison flex libtool autoconf automake m4

# 设置环境变量（关键修复点）
export BISON_LOCALEDIR=/usr/share/bison
export PATH=/usr/local/bin:$PATH  # 优先使用本地编译的 gettext-0.20

# 验证版本匹配
GETTEXT_VERSION=$(gettext --version | grep -oP '([0-9]+\.){2}[0-9]+')
AUTOCONF_VERSION=$(autoconf --version | grep -oP '([0-9]+\.){2}[0-9]+')
AUTOMAKE_VERSION=$(automake --version | grep -oP '([0-9]+\.){2}[0-9]+')

echo "当前工具链版本："
echo "gettext: $GETTEXT_VERSION"
echo "autoconf: $AUTOCONF_VERSION"
echo "automake: $AUTOMAKE_VERSION"

# 强制清理缓存
cd $GITHUB_WORKSPACE/wrt
make clean
make dirclean

echo "=== gettext 工具链修复完成 ==="
