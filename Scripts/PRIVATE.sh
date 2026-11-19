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

# 3. 首次开机等所有 uci-defaults 初始化彻底完成后，统一固化无线参数 + Honk 开箱即用手动模式（仅执行一次）
rm -f ./files/etc/uci-defaults/zzz-custom-wifi
mkdir -p ./files/etc
cat <<'EOF' > ./files/etc/rc.local
if [ ! -f /etc/.sys_init_done ]; then
	(
		sleep 15

		# A. 固化双频无线参数（避开 router-tool 首次重置）
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

		# B. 自动完成 Honk 首次初始化（防更新写法，默认停止且不自启，点启动即绿灯并开启 --store db）
		if [ -f /etc/init.d/honk ]; then
			printf '{"username":"root","password":"12345678"}' | /usr/share/honk/control.sh initialize

			mkdir -p /var/lib/honk /etc/honk
			ln -sf /usr/share/v2ray/geoip.dat /var/lib/honk/geoip.dat
			ln -sf /usr/share/v2ray/geosite.dat /var/lib/honk/geosite.dat

			cat <<'HONKEOF' > /etc/honk/config.dae
global {
    wan_interface: auto
    lan_interface: br-lan
    log_level: info
    dial_mode: domain
    allow_insecure: false
    auto_config_kernel_parameter: true
    data_dir: '/var/lib/honk'
    log_file: ''
    tcp_check_url: 'https:/''/gstatic.com'
    tcp_check_http_method: HEAD
    udp_check_dns: '8.8.8.8:53'
    check_interval: 300s
    bootstrap_resolver: '223.5.5.5:53'
    store_subscribe: true
    nfqueue_enable: true
}

experimental {
    native_api {
        enabled: true
        listen: '192.168.1.1:9527'
        password_auth: true
        allow_anonymous_loopback: false
        config_write: true
        ui: '/usr/share/doona'
    }
}

node {
}

group {
    proxy {
        policy: min_moving_avg
    }
}

dns {
    client_subnet: auto
    upstream {
        default: 'udp://223.5.5.5:53' -> direct
        remote: 'tcp+udp://8.8.8.8:53' -> proxy
    }
    routing {
        request {
            qname(geosite:private) -> asis
            qname(geosite:cn) -> default
            fallback: remote
        }
        response {
            upstream(remote) -> accept
            qname(geosite:private) -> accept
            ip(geoip:cn) -> accept
            fallback: remote
        }
    }
}

routing {
    dip(224.0.0.0/3, 'ff00::/8') -> direct
    pname(AdGuardHome, mosdns, mihomo, sing-box, clash, frpc, xray, v2ray) -> direct(must)
    pname(qbittorrent) -> direct(must)
    dscp(4) -> direct(must)
    pname(dnsmasq) && l4proto(udp) && dport(53) -> direct(must)
    dip(geoip:private) && !dport(53) -> direct(must)
    dip(geoip:cn) && !dport(53) -> direct(must)
    domain(geosite:private) -> direct
    domain(geosite:cn) -> direct
    domain(geosite:apple-cn) -> direct
    domain(geosite:category-games@cn) -> direct
    domain(geosite:steam@cn) -> direct
    domain(geosite:category-ai-cn) -> direct
    domain(geosite:onedrive) -> direct
    fallback: proxy
}
HONKEOF

			sed -i "s|'https:/''/gstatic.com'|'https://gstatic.com'|g" /etc/honk/config.dae
			sed -i "s|data_dir: '/etc/honk'|data_dir: '/var/lib/honk'|g" /etc/honk/system.dae
			[ ! -f /etc/init.d/honk.bak ] && cp -f /etc/init.d/honk /etc/init.d/honk.bak
			cp -f /etc/init.d/honk.bak /etc/init.d/honk
			grep -q -- '--store db' /etc/init.d/honk || sed -i '/procd_set_param command.*honk-core/ s/$/ --store db/' /etc/init.d/honk

			uci set honk.main.enabled='0'
			uci commit honk
			/etc/init.d/honk disable
			/etc/init.d/honk stop
			rm -rf /var/run/honk/* /tmp/honk* /var/lib/honk/state
		fi

		touch /etc/.sys_init_done
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
