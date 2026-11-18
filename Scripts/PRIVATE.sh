#!/bin/bash

# 1. 拉取 daede（含统一 LuCI 界面 luci-app-daede）、honk（仅核心）以及 openclash
UPDATE_PACKAGE "daede" "kenzok8/openwrt-daede" "main" "" "dae daed luci-app-daede"
UPDATE_PACKAGE "honk" "kenzok8/openwrt-honk" "main" "" "honk"
UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"

# 2. 预下载 Clash Meta (Mihomo) 内核（ARM64 架构，适配京东云亚瑟 IPQ60xx）
CORE_DIR="./files/etc/openclash/core"
mkdir -p "$CORE_DIR"
wget -qO /tmp/clash-meta.tar.gz "https://githubusercontent.com"
tar -zxf /tmp/clash-meta.tar.gz -C "$CORE_DIR"
[ -f "$CORE_DIR/clash" ] && mv -f "$CORE_DIR/clash" "$CORE_DIR/clash_meta"
chmod +x "$CORE_DIR/clash_meta"
rm -f /tmp/clash-meta.tar.gz

# 3. 精简多余主题（仅保留 luci-theme-vantage）和未使用的大型插件源码
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

# 4. 彻底固化 WiFi 默认配置（修改底层模板 + 延迟校准双保险）
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_UC" ]; then
	sed -i "s/country='.*'/country='CN'/g; s/country = '.*'/country = 'CN'/g" "$WIFI_UC"
	sed -i "s/disabled=1/disabled=0/g; s/disabled = 1/disabled = 0/g" "$WIFI_UC"
	sed -i "s/htmode='HE20'/htmode='HE80'/g; s/htmode = 'HE20'/htmode = 'HE80'/g" "$WIFI_UC"
	sed -i "s/channel='auto'/channel='36'/g; s/channel = 'auto'/channel = '36'/g" "$WIFI_UC"
fi

# 5. 写入根目录 files/etc/uci-defaults/zzz-custom-wifi（确保最后执行且等待驱动就绪）
mkdir -p ./files/etc/uci-defaults
cat <<'EOF' > ./files/etc/uci-defaults/zzz-custom-wifi
#!/bin/sh

for i in $(seq 1 15); do
	[ -s /etc/config/wireless ] && grep -q "wifi-device" /etc/config/wireless && break
	sleep 1
done

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

for iface in default_radio0 default_radio1; do
	if uci -q get wireless.${iface} >/dev/null; then
		uci set wireless.${iface}.disabled='0'
	fi
done

uci commit wireless
wifi reload
exit 0
EOF
chmod +x ./files/etc/uci-defaults/zzz-custom-wifi
