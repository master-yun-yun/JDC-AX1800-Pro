#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " "

	cd ./luci-theme-argon/

	sed -i "/font-weight:/ { /important/! { /\/\*/! s/:.*/: var(--font-weight);/ } }" $(find ./luci-theme-argon -type f -iname "*.css")
	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "

	sed -i 's/fs-ntfs/fs-ntfs3/g' $DM_FILE
    sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman has been fixed!"
fi

# -----------------2025.11.15--在 handles.sh 文件末尾添加以下代码-------------： #

# 修复 PHP8 目录缺失问题（防止编译失败）
if [ -d "php8" ] || [ -f "../feeds/packages/lang/php8/Makefile" ]; then
    echo " "
    echo "修复 PHP8 目录缺失问题..."
    
    # 查找 php8 Makefile 的位置
    PHP_MAKEFILE=""
    if [ -f "php8/Makefile" ]; then
        PHP_MAKEFILE="php8/Makefile"
    elif [ -f "../feeds/packages/lang/php8/Makefile" ]; then
        PHP_MAKEFILE="../feeds/packages/lang/php8/Makefile"
    else
        # 尝试通过 find 查找
        PHP_MAKEFILE=$(find ../feeds/packages/ -name "php8" -type d 2>/dev/null | head -1)/Makefile
        if [ ! -f "$PHP_MAKEFILE" ]; then
            PHP_MAKEFILE=$(find . -name "php8" -type d 2>/dev/null | head -1)/Makefile
        fi
    fi
    
    if [ -f "$PHP_MAKEFILE" ]; then
        echo "找到 php8 Makefile: $PHP_MAKEFILE"
        
        # 备份原文件
        cp "$PHP_MAKEFILE" "${PHP_MAKEFILE}.bak"
        
        # 检查是否已经存在目录创建命令
        if ! grep -q "\$(INSTALL_DIR).*\/etc\/php8" "$PHP_MAKEFILE"; then
            # 在 install 部分添加目录创建命令
            sed -i '/define Package\/php8\/install/,/endef/{
                /define Package\/php8\/install/a\
\t$(INSTALL_DIR) $(1)/etc/php8\n\t$(INSTALL_DIR) $(1)/usr/bin
            }' "$PHP_MAKEFILE"
            echo "已添加 PHP8 目录创建命令"
        else
            echo "PHP8 目录创建命令已存在"
        fi
    else
        echo "未找到 php8 Makefile，跳过修复"
    fi
    
    cd $PKG_PATH && echo "PHP8 目录修复完成!"
fi
# -----------------2025.11.15--在 handles.sh 文件末尾添加以上代码-------------： #
