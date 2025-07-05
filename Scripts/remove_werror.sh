#!/bin/bash
# 文件名：remove_werror.sh

# 遍历所有 Makefile 和 makefile，批量注释 -Werror 并加 -Wno-error
find ./wrt -type f \( -iname "Makefile" -o -iname "makefile" \) | while read -r f; do
    # 如果有 -Werror，就注释掉（可避免引入奇怪语法问题）
    sed -i 's/\(\s\)-Werror/\1-Wno-error/g' "$f"
done

echo "已批量处理 -Werror 为 -Wno-error"