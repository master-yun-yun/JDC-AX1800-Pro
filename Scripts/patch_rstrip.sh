#!/bin/bash
# 补丁脚本：修复 OpenWrt rstrip.sh 对不应strip文件的处理

RSTDIR="$GITHUB_WORKSPACE/wrt/scripts"
RSTFILE="$RSTDIR/rstrip.sh"

if [ -f "$RSTFILE" ]; then
    cp "$RSTFILE" "$RSTFILE.bak"

    # 在第一个 strip 动作前插入类型检测
    # 注意：补丁只插入一次，避免多次插入
    grep -q 'filetype=' "$RSTFILE" || \
    sed -i '1a\
filetype=$(file "$1")\n\
if echo "$filetype" | grep -qE "shared object|executable"; then\n\
    echo "Skipping strip for $1 ($filetype)"\n\
    exit 0\n\
fi\n' "$RSTFILE"

    echo "patch_rstrip.sh: 已完成 rstrip.sh 补丁"
else
    echo "patch_rstrip.sh: 未找到 $RSTFILE"
    exit 1
fi