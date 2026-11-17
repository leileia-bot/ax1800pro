#!/bin/sh
# ---------- 清理旧包/冲突 ----------
rm -rf ./packages/net/fullconenat-sonic ./feeds/luci/applications/luci-app-fullconenat-sonic 2>/dev/null
rm -rf ./feeds/luci/applications/luci-app-upnp 2>/dev/null
rm -rf ./feeds/luci/applications/luci-app-samba4 2>/dev/null
rm -rf ./feeds/luci/applications/luci-app-homeproxy 2>/dev/null
rm -rf ./feeds/packages/net/sing-box 2>/dev/null
SAFE_RM_FIND "*homeproxy*"
SAFE_RM_FIND "*sing-box*"

# ---------- dae / honk 源码拉取 ----------
UPDATE_PACKAGE "luci-app-dae" "daeuniverse/luci-app-dae" "main" "pkg"
UPDATE_PACKAGE "daed" "daeuniverse/daed" "main" "pkg"
UPDATE_PACKAGE "dae" "daeuniverse/dae" "main" "pkg"
UPDATE_PACKAGE "luci-app-honk" "gzd1106/luci-app-honk" "main" "pkg"
UPDATE_PACKAGE "honk" "gzd1106/honk" "main" "pkg"

# ---------- 双频无线固化：5G CN/36/HE80 | 2.4G CN/1/HT20 ----------
mkdir -p "$PACKAGE_PATH/base-files/files/etc/uci-defaults"
cat > "$PACKAGE_PATH/base-files/files/etc/uci-defaults/99-wireless-cn" << 'WLEOT'
#!/bin/sh
sleep 3

for dev in $(uci show wireless 2>/dev/null | sed -n 's/.*\.\(radio[0-9]\)$/\1/p' | sort -u); do
	band=$(uci -q get wireless.$dev.band 2>/dev/null)
	case "$band" in
		5g)
			uci set wireless.$dev.country='CN'
			uci set wireless.$dev.channel='36'
			uci set wireless.$dev.htmode='HE80'
			uci delete wireless.$dev.channels 2>/dev/null
			;;
		2g)
			uci set wireless.$dev.country='CN'
			uci set wireless.$dev.channel='1'
			uci set wireless.$dev.htmode='HT20'
			uci delete wireless.$dev.channels 2>/dev/null
			;;
	esac
done

# 关内核 flow offload（NSS 接管，避免与 eBPF/dae 冲突）
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'

uci commit wireless
uci commit firewall
exit 0
WLEOT
chmod +x "$PACKAGE_PATH/base-files/files/etc/uci-defaults/99-wireless-cn"

# ---------- 防火墙模板层兜底关 flow offload ----------
FIX "firewall-no-flow-offload" "./package/network/config/firewall" sed -i \
	's/option.*flow_offloading.*1/option flow_offloading 0/g; s/option.*flow_offloading_hw.*1/option flow_offloading_hw 0/g' \
	./package/network/config/firewall/files/firewall.config 2>/dev/null

echo " "
echo "=================================================="
echo "  Done - 亚瑟 1G / dae / honk / NSS / 双频固化"
echo "  5G: CN ch36 HE80 | 2.4G: CN ch1 HT20"
echo "=================================================="
