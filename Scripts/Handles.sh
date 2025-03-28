#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# -------------------------- 新增冲突预处理逻辑 --------------------------
# 删除固件构建目录中已存在的冲突文件（关键修改）
echo "删除预存在的冲突文件..."
# OpenVPN配置文件冲突
OPENVPN_CONF_PATH="$GITHUB_WORKSPACE/wrt/package/base-files/files/etc/config/openvpn"
[ -f "$OPENVPN_CONF_PATH" ] && rm -vf "$OPENVPN_CONF_PATH" && echo "已删除冲突文件: $OPENVPN_CONF_PATH"

# Easy-RSA文件冲突
EASY_RSA_VARS_PATH="$GITHUB_WORKSPACE/wrt/package/base-files/files/etc/easy-rsa/vars"
[ -f "$EASY_RSA_VARS_PATH" ] && rm -vf "$EASY_RSA_VARS_PATH" && echo "已删除冲突文件: $EASY_RSA_VARS_PATH"

# Socat配置文件冲突
SOCAT_CONF_PATH="$GITHUB_WORKSPACE/wrt/package/base-files/files/etc/config/socat"
[ -f "$SOCAT_CONF_PATH" ] && rm -vf "$SOCAT_CONF_PATH" && echo "已删除冲突文件: $SOCAT_CONF_PATH"
SOCAT_INIT_PATH="$GITHUB_WORKSPACE/wrt/package/base-files/files/etc/init.d/socat"
[ -f "$SOCAT_INIT_PATH" ] && rm -vf "$SOCAT_INIT_PATH" && echo "已删除冲突文件: $SOCAT_INIT_PATH"
# -------------------------- 新增结束 --------------------------

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
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
	cd ./luci-theme-argon/

	sed -i "/font-weight:/ { /important/! { /\/\*/! s/:.*/: var(--font-weight);/ } }" $(find ./luci-theme-argon -type f -iname "*.css")
	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#移除Shadowsocks组件
PW_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile")
if [ -f "$PW_FILE" ]; then
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' $PW_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' $PW_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $PW_FILE

	cd $PKG_PATH && echo "passwall has been fixed!"
fi

SP_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-ssr-plus/Makefile")
if [ -f "$SP_FILE" ]; then
	sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' $SP_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' $SP_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $SP_FILE

	cd $PKG_PATH && echo "ssr-plus has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Coremark编译失败
CM_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/coremark/Makefile")
if [ -f "$CM_FILE" ]; then
	sed -i 's/mkdir/mkdir -p/g' $CM_FILE

	cd $PKG_PATH && echo "coremark has been fixed!"
fi

# -------------------------- 新增冲突处理逻辑 --------------------------
# 处理文件冲突：在安装包前备份可能冲突的文件
echo "处理文件冲突..."
# OpenVPN相关冲突
if [ -f /etc/config/openvpn ]; then
  mv /etc/config/openvpn /etc/config/openvpn.bak && echo "已备份/etc/config/openvpn"
fi
if [ -f /etc/easy-rsa/vars ]; then
  mv /etc/easy-rsa/vars /etc/easy-rsa/vars.bak && echo "已备份/etc/easy-rsa/vars"
fi

# Socat相关冲突
if [ -f /etc/config/socat ]; then
  mv /etc/config/socat /etc/config/socat.bak && echo "已备份/etc/config/socat"
fi
if [ -f /etc/init.d/socat ]; then
  mv /etc/init.d/socat /etc/init.d/socat.bak && echo "已备份/etc/init.d/socat"
fi
# -------------------------- 新增结束 --------------------------
