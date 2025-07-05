#!/bin/bash
# 文件名：remove_werror.sh

# 遍历所有 Makefile 和 makefile，批量注释 -Werror 并加 -Wno-error
# 方案二：全局处理，但排除 feeds/nss_packages 目录
find ./wrt -type f \( -iname "Makefile" -o -iname "makefile" \) \
    ! -path "./wrt/feeds/nss_packages/*" | while read -r f; do
    echo "处理 $f"
    sed -i 's/\(\s\)-Werror/\1-Wno-error/g' "$f"
done

echo "remove_werror.sh: 已处理指定目录的 -Werror"
