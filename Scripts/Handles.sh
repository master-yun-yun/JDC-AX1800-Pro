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

# 调整cgroup启动顺序 （使用变量方式）--- 2025.07.02-----#
echo "查找cgroupfs-mount启动脚本..."
CGROUP_INIT=$(find ./package/feeds/packages/ -path "*/cgroupfs-mount/files/cgroupfs-mount.init" 2>/dev/null | head -1)
if [ -n "$CGROUP_INIT" ]; then
    echo "找到启动脚本: $CGROUP_INIT"
    if grep -q "START=" "$CGROUP_INIT"; then
        sed -i 's/START=.*/START=10/g' "$CGROUP_INIT"
        echo "cgroupfs-mount启动顺序已调整为10"
    else
        echo "::warning::启动脚本中没有START设置，添加新设置"
        sed -i '1iSTART=10' "$CGROUP_INIT"
    fi
    chmod +x "$CGROUP_INIT"
else
    echo "::warning::未找到cgroupfs-mount启动脚本"
fi

# cgroup兜底挂载
RC_LOCAL=./files/etc/rc.local
if [ ! -f "$RC_LOCAL" ]; then
    mkdir -p ./files/etc
    cat << 'EOF' > "$RC_LOCAL"
#!/bin/sh -e
# openwrt cgroup 挂载兜底
if ! mount | grep -q cgroup; then
  mkdir -p /sys/fs/cgroup
  mount -t tmpfs cgroup_root /sys/fs/cgroup
  for sys in $(awk -F: '{print $2}' /proc/1/cgroup | tr ',' '\n' | sort -u); do
      [ -n "$sys" ] && mkdir -p /sys/fs/cgroup/$sys
      [ -n "$sys" ] && mount -t cgroup -o $sys cgroup /sys/fs/cgroup/$sys
  done
fi
exit 0
EOF
    chmod +x "$RC_LOCAL"
fi
