#!/bin/bash

# 1. 拉取 daede（含统一 LuCI 界面 luci-app-daede）、honk（仅核心）以及 openclash
UPDATE_PACKAGE "daede" "kenzok8/openwrt-daede" "main" "" "dae daed luci-app-daede"
UPDATE_PACKAGE "honk" "kenzok8/openwrt-honk" "main" "" "honk"
UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"

# 2. 预下载 Clash Meta (Mihomo) 内核与规则数据库（适配 1GB RAM + 2GB 大分区，多源兜底防失效）
OPENCLASH_DIR="./files/etc/openclash"
CORE_DIR="$OPENCLASH_DIR/core"
mkdir -p "$CORE_DIR"

GH_RAW="https:/""/raw.githubusercontent.com"
CDN_GH="https:/""/testingcf.jsdelivr.net/gh"
GH_API="https:/""/api.github.com"

# 动态获取最新 Meta 内核压缩包地址（兼容文件名变更），并保留官方直链兜底
META_URL=$(curl -fsSL "$GH_API/repos/MetaCubeX/mihomo/releases/latest" | grep -oE 'https://[^"]+mihomo-linux-arm64-v1-[^"]+\.gz' | head -n 1)
[ -z "$META_URL" ] && META_URL=$(curl -fsSL "$GH_API/repos/MetaCubeX/mihomo/releases/latest" | grep -oE 'https://[^"]+mihomo-linux-arm64-[^"]+\.gz' | grep -vE 'compatible|v2|v3|go' | head -n 1)

if [ -n "$META_URL" ] && wget -O /tmp/clash-meta.gz "$META_URL"; then
	gzip -dc /tmp/clash-meta.gz > "$CORE_DIR/clash_meta"
	rm -f /tmp/clash-meta.gz
else
	wget -O /tmp/clash-meta.tar.gz "$GH_RAW/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz" || \
	wget -O /tmp/clash-meta.tar.gz "$CDN_GH/vernesong/OpenClash@core/master/meta/clash-linux-arm64.tar.gz"
	tar -zxf /tmp/clash-meta.tar.gz -C "$CORE_DIR"
	find "$CORE_DIR" -maxdepth 1 -type f -name "clash*" ! -name "clash_meta" -exec mv -f {} "$CORE_DIR/clash_meta" \;
	rm -f /tmp/clash-meta.tar.gz
fi

chmod +x "$CORE_DIR/clash_meta"

# 校验内核是否有效下载（避免空包）
if [ ! -s "$CORE_DIR/clash_meta" ]; then
	echo "ERROR: clash_meta download failed!"
	exit 1
fi

# 预置三大规则数据库
wget -qO "$OPENCLASH_DIR/Country.mmdb" "$CDN_GH/alecthw/mmdb_china_ip_list@release/Country.mmdb"
wget -qO "$OPENCLASH_DIR/GeoIP.dat" "$CDN_GH/Loyalsoldier/v2ray-rules-dat@release/geoip.dat"
wget -qO "$OPENCLASH_DIR/GeoSite.dat" "$CDN_GH/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"

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

# 4. 无线参数永久固化（等 router-tool 首次初始化完成后精准覆写，仅执行一次）
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

# 5. 内核分区扩容至 12MB 及冗余冲突包清理（集中收口，防止同步上游覆盖 Handles.sh 后失效）
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
