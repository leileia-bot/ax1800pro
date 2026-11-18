#!/bin/bash

# 1. 拉取 daede (dae + daed + luci界面) 和 honk (honk + Doona面板 + luci界面)
UPDATE_PACKAGE "daede" "kenzok8/openwrt-daede" "main" "" "dae daed luci-app-dae luci-app-daed"
UPDATE_PACKAGE "honk" "kenzok8/openwrt-honk" "main" "" "luci-app-honk"

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

# 3. 固化 WiFi 默认配置（5G: CN / 信道36 / 80MHz；2.4G: CN / 信道1 / 20MHz）
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_UC" ]; then
	# 将默认国家代码替换为 CN
	sed -i "s/country='.*'/country='CN'/g; s/country = '.*'/country = 'CN'/g" "$WIFI_UC"
	
	# 注入首次开机自动校准脚本（确保 5G/2.4G 射频参数与开关状态 100% 精准固化）
	mkdir -p ./package/base-files/files/etc/uci-defaults
	cat <<-'EOF' > ./package/base-files/files/etc/uci-defaults/99-custom-wifi
	#!/bin/sh
	[ -f /etc/config/wireless ] || wifi config
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
			uci set wireless.${radio}.htmode='HE20'
			uci set wireless.${radio}.disabled='0'
		fi
	done
	uci commit wireless
	wifi reload
	exit 0
	EOF
	chmod +x ./package/base-files/files/etc/uci-defaults/99-custom-wifi
fi
