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
# 这个块会查找常见位置的 php8 Makefile（./php8/Makefile、../feeds/packages/lang/php8/Makefile 以及在 ../feeds 下查找）
# 对每个找到的 Makefile：备份 -> 检查是否已包含 $(INSTALL_DIR) $(1)/etc/php8 -> 若没有则在 install 区块 endef 前插入创建目录的命令
echo " "
echo "尝试修复 PHP8 目录缺失问题...（搜索 php8 Makefile）"

# 收集可能的 php8 Makefile 列表
PHP_MAKEFILES=""
[ -f "./php8/Makefile" ] && PHP_MAKEFILES="$PHP_MAKEFILES ./php8/Makefile"
[ -f "../feeds/packages/lang/php8/Makefile" ] && PHP_MAKEFILES="$PHP_MAKEFILES ../feeds/packages/lang/php8/Makefile"

# 在 ../feeds 下查找 php8/Makefile（深度限制为 5，避免遍历过深）
FOUND=$(find ../feeds -maxdepth 5 -type f -path "*/php8/Makefile" -print -quit 2>/dev/null)
if [ -n "$FOUND" ]; then
    PHP_MAKEFILES="$PHP_MAKEFILES $FOUND"
fi

# 如果没有找到任何 Makefile，则尝试再在仓库的其他位置查找一次
if [ -z "$PHP_MAKEFILES" ]; then
    FALLBACK=$(find . -maxdepth 6 -type f -path "*/php8/Makefile" -print -quit 2>/dev/null)
    [ -n "$FALLBACK" ] && PHP_MAKEFILES="$FALLBACK"
fi

if [ -z "$PHP_MAKEFILES" ]; then
    echo "未找到 php8 Makefile，跳过 PHP8 目录修复"
else
    for mk in $PHP_MAKEFILES; do
        [ -z "$mk" ] && continue
        if [ ! -f "$mk" ]; then
            echo "文件不存在，跳过：$mk"
            continue
        fi

        echo "处理 php8 Makefile: $mk"
        # 备份
        cp -a "$mk" "${mk}.bak" && echo "备份已保存为 ${mk}.bak"

        # 如果已存在创建 etc/php8 的命令，则跳过
        if grep -q '\\$(INSTALL_DIR)[[:space:]]*\\$(1)\\/etc\\/php8' "$mk" 2>/dev/null || grep -q '\$(INSTALL_DIR)[[:space:]]*$(1)/etc/php8' "$mk" 2>/dev/null || grep -q '\$(INSTALL_DIR)[[:space:]]*$(1)\/etc\/php8' "$mk" 2>/dev/null; then
            echo "PHP8 目录创建命令已存在于 $mk，跳过插入"
            continue
        fi

        # 使用 awk 在 define Package/php8/install ... endef 区块的 endef 前插入创建目录命令
        awk '
        BEGIN { in_install=0; inserted=0 }
        /define[[:space:]]+Package\/php8\/install/ { print; in_install=1; next }
        in_install && /^endef/ {
            if (!inserted) {
                print "\t$(INSTALL_DIR) $(1)/etc/php8"
                print "\t$(INSTALL_DIR) $(1)/usr/bin"
                inserted=1
            }
            print
            in_install=0
            next
        }
        { print }
        ' "$mk" > "${mk}.tmp" && mv "${mk}.tmp" "$mk" && echo "已插入 PHP8 目录创建命令到 $mk"
    done
    echo "PHP8 目录修复完成（已对找到的 Makefile 做处理，备份为 *.bak）"
fi

cd $PKG_PATH && echo "PHP8 目录修复完成!"
# -----------------2025.11.15--在 handles.sh 文件末尾添加以上代码-------------： #
