#!/bin/bash

# 1. 拉取 daede（含统一 LuCI 界面）、kenzok8 版 honk（含界面）以及 openclash（仅纯界面，不预装内核与规则）
UPDATE_PACKAGE "daede" "kenzok8/openwrt-daede" "main" "" "dae daed luci-app-daede"
UPDATE_PACKAGE "honk" "kenzok8/openwrt-honk" "main" "" "luci-app-honk"
UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"

# 2. 精简多余主题（仅保留 luci-theme-vantage）和未使用的大型插件源码
rm -rf ./package/luci-theme-argon ./package/luci-app-argon-config
rm -rf ./package/luci-theme-aurora ./package/luci-app-aurora-config
rm -rf ./package/luci-theme-fluent ./package/luci-theme-footstrap
rm -rf ./package/luci-theme-kucat ./package/luci-app-kucat-config
rm -rf ./package/luci-theme-shadcn
rm -rf ./package/OpenWrt-momo ./package/OpenWrt-nikki
rm -rf ./package/luci-app-passwall ./package/luci-app-passwall2
rm -rf ./package/luci-app-qbittorrent ./package/luci-app-openlist2 ./package/luci-app-mosdns
rm -rf ./package/QModem ./package/luci-app-airpi3000m-fancontrol ./package/luci-app-chfs
rm -rf ./package/luci-app-fm350 ./package/luci-app-h5000m-netmode ./package/luci-app-mt5700
rm -rf ./package/luci-app-mt5700m ./package/luci-app-netmonitor ./package/luci-app-qmodem-generic

# 3. 无线参数永久固化（等 router-tool 首次初始化完成后精准覆写，仅执行一次）
rm -f ./files/etc/uci-defaults/zzz-custom-wifi
mkdir -p ./files/etc
cat <<'EOF' > ./files/etc/rc.local
if [ ! -f /etc/.wifi_fixed ]; then
	(
		sleep 15
		[ -s /etc/config/wireless ] || wifi config
		for radio in radio0 radio1; do
			band=$(uci -q get wireless.${radio}.band)
			if [ "$band" = "5g" ]; then
				uci set wireless.${radio}.country='CN'
				uci set wireless.${radio}.channel='36'
				uci set wireless.${radio}.htmode='HE80'
				uci set wireless.${radio}.disabled='0'
			elif [ "$band" = "2g" ]; then
				uci set wireless.${radio}.country='CN'
				uci set wireless.${radio}.channel='1'
				uci set wireless.${radio}.htmode='HT20'
				uci set wireless.${radio}.disabled='0'
			fi
		done
		uci -q set wireless.default_radio0.disabled='0'
		uci -q set wireless.default_radio1.disabled='0'
		uci commit wireless
		wifi reload
		touch /etc/.wifi_fixed
	) &
fi

exit 0
EOF
chmod +x ./files/etc/rc.local

# 4. 内核分区扩容至 12MB 及冗余冲突包清理（集中收口，防止同步上游覆盖 Handles.sh 后失效）
if [ -f "./target/linux/qualcommax/image/ipq60xx.mk" ]; then
	sed -i 's/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g' "./target/linux/qualcommax/image/ipq60xx.mk"
fi
rm -rf ./package/viking/luci-app-homeproxy ./package/viking/sing-box
rm -rf ./package/viking/gecoosac
rm -rf ./package/viking/luci-app-wolultra ./package/viking/luci-app-upnp
rm -rf ./package/natmapt ./package/stuntman ./package/luci-app-natmapt
rm -rf ./feeds/packages/net/fullconenat-sonic ./feeds/luci/applications/luci-app-fullconenat-sonic
rm -rf ./feeds/luci/applications/luci-app-upnp ./feeds/packages/net/miniupnpd
rm -rf ./feeds/luci/applications/luci-app-samba4

# 5. 调整「服务」菜单顺序：Honk 在上 (order:10) -> daede 在中 (order:20) -> OpenClash 在下（仅修改首个顶级 order，保留子标签页原顺序）
for f in $(find ./package -path "*/luci-app-honk/*" -name "*.json"); do
	awk '!done && /"order"[[:space:]]*:/ { sub(/[0-9]+/, "10"); done=1 } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
for f in $(find ./package -path "*/luci-app-daede/*" -name "*.json"); do
	awk '!done && /"order"[[:space:]]*:/ { sub(/[0-9]+/, "20"); done=1 } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
