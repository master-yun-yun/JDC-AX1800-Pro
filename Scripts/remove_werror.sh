#!/bin/bash
# 增强版：全面处理所有-Werror变体 # 文件名：remove_werror.sh

find ./wrt -type f \( -iname "Makefile" -o -iname "makefile" \) \
    ! -path "./wrt/feeds/nss_packages/*" | while read -r f; do
    echo "处理 $f"
    
    # 处理所有-Werror变体（包括带=的）
    sed -i -E '
        # 替换CFLAGS中的-Werror
        s/(\bCFLAGS\s*[+:]=[^$]*)-Werror([^$]*)/\1-Wno-error\2/g;
        
        # 替换编译选项中的-Werror（带或不带=）
        s/-Werror([ =][^ ]*)?/-Wno-error\1/g;
        
        # 处理特殊变量赋值
        s/(\bEXTRA_CFLAGS\b\s*[+:]=[^$]*)-Werror/\1-Wno-error/g;
    ' "$f"
done

echo "remove_werror.sh: 已全面处理编译警告选项"
