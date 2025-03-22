#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# ====================== 增强型冲突清理 ======================
clean_conflict() {
  # luci-app-socat vs socat
  if [ -d "$GITHUB_WORKSPACE/wrt/package" ]; then
    find "$GITHUB_WORKSPACE/wrt/package" \
      -maxdepth 5 \
      -type f \( -name "socat.install" -o -name "luci-app-socat.install" \) \
      -exec sed -i '\|/usr/bin/socat|d; \|/etc/config/socat|d' {} \;
  fi

  # luci-app-openvpn-server vs openvpn-openssl/openvpn-easy-rsa
  if [ -d "$GITHUB_WORKSPACE/wrt/feeds/packages" ]; then
    find "$GITHUB_WORKSPACE/wrt/feeds/packages" \
      -maxdepth 5 \
      -type f \( -name "openvpn-openssl.install" -o -name "openvpn-easy-rsa.install" \) \
      -exec sed -i '\|/etc/config/openvpn|d; \|/etc/easy-rsa/vars|d; \|/etc/openvpn/server|d' {} \;
  fi

  # 强制刷新文件时间戳
  find "$GITHUB_WORKSPACE/wrt/package" -name "*.install" -exec touch {} +
}

# ====================== 运行时覆盖策略注入 ======================
inject_overwrite_policy() {
  OVERWRITE_CONF="$GITHUB_WORKSPACE/wrt/files/etc/opkg/overwrite.conf"
  mkdir -p "$(dirname "$OVERWRITE_CONF")"
  cat > "$OVERWRITE_CONF" << EOF
allow-overwrite /usr/bin/socat
allow-overwrite /etc/config/openvpn
allow-overwrite /etc/easy-rsa/vars
allow-overwrite /etc/openvpn/server/*
EOF
}

# ====================== 主执行逻辑 ======================
clean_conflict
inject_overwrite_policy

# ====================== 原有功能 ======================
# 预置HomeProxy数据
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
  cd $PKG_PATH && echo "homeproxy date updated!"
fi

# 修改argon主题
if [ -d *"luci-theme-argon"* ]; then
  cd ./luci-theme-argon/
  sed -i "/font-weight:/ { /important/! { /\/\*/! s/:.*/: var(--font-weight);/ } }" $(find . -name "*.css")
  sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon
  cd $PKG_PATH && echo "argon theme fixed!"
fi

# 修复qca-nss-drv启动顺序
NSS_DRV="$GITHUB_WORKSPACE/wrt/feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
  sed -i 's/START=.*/START=85/g' "$NSS_DRV"
  echo "qca-nss-drv fixed!"
fi

# 修复qca-nss-pbuf启动顺序
NSS_PBUF="$GITHUB_WORKSPACE/wrt/kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
  sed -i 's/START=.*/START=86/g' "$NSS_PBUF"
  echo "qca-nss-pbuf fixed!"
fi

# 移除Shadowsocks组件
PW_FILE=$(find "$GITHUB_WORKSPACE/wrt" -maxdepth 5 -type f -wholename "*/luci-app-passwall/Makefile")
if [ -f "$PW_FILE" ]; then
  sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' "$PW_FILE"
  sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' "$PW_FILE"
  sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' "$PW_FILE"
  echo "passwall fixed!"
fi

SP_FILE=$(find "$GITHUB_WORKSPACE/wrt" -maxdepth 5 -type f -wholename "*/luci-app-ssr-plus/Makefile")
if [ -f "$SP_FILE" ]; then
  sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' "$SP_FILE"
  sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' "$SP_FILE"
  sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' "$SP_FILE"
  echo "ssr-plus fixed!"
fi

# 修复TailScale冲突
if [ -d "$GITHUB_WORKSPACE/wrt/feeds/packages" ]; then
  TS_FILE=$(find "$GITHUB_WORKSPACE/wrt/feeds/packages" -maxdepth 5 -type f -wholename "*/tailscale/Makefile")
  if [ -f "$TS_FILE" ]; then
    sed -i '/\/files/d' "$TS_FILE"
    echo "tailscale fixed!"
  fi
fi

# 修复Coremark编译
if [ -d "$GITHUB_WORKSPACE/wrt/feeds/packages" ]; then
  CM_FILE=$(find "$GITHUB_WORKSPACE/wrt/feeds/packages" -maxdepth 5 -type f -wholename "*/coremark/Makefile")
  if [ -f "$CM_FILE" ]; then
    sed -i 's/mkdir/mkdir -p/g' "$CM_FILE"
    echo "coremark fixed!"
  fi
fi
