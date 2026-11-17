#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 亚瑟 AX1800 Pro (1G) - dae/honk/NSS 共存 + 双频无线固化

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2
	[ -d "$GUARD" ] || return 0
	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

SAFE_RM_FIND() {
	local pattern="$1"
	[ -n "$(find ./ -name "$pattern" 2>/dev/null | head -1)" ] \
		&& find ./ -name "$pattern" -exec rm -rf {} + 2>/dev/null
}

# ---------- 主题 ----------
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

FIX "theme-vantage" "$PACKAGE_PATH/luci-theme-vantage" sed -i \
	-e '/^\/\* progress bars: thin track/,$ { /^\.cbi-progressbar::before {/,/^}/ { s/^[[:space:]]*font: 500 var(--fs-micro)\/1\.2 var(--mono);/\tfont: inherit; line-height: normal;/; } }' \
	"$PACKAGE_PATH/luci-theme-vantage/luci-theme-vantage/htdocs/luci-static/vantage/vantage.css"

FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

# ---------- 内核分区 12MB + rootfs 20MB ----------
FIX "ipq60xx-kernel-size" "./target/linux/qualcommax/image" sed -i \
	-E 's/^([[:space:]]*KERNEL_SIZE[[:space:]]*:=[[:space:]]*).*/\112288k/' \
	"./target/linux/qualcommax/image/ipq60xx.mk"

FIX "ipq60xx-rootfs-size" "./target/linux/qualcommax/image" sed -i \
	-E 's/^([[:space:]]*ROOTFS_SIZE[[:space:]]*:=[[:space:]]*).*/\120480k/' \
	"./target/linux/qualcommax/image/ipq60xx.mk"

# ---------- BTF kconfig 兜底追加 ----------
FIX "btf-kconfig-append" "./target/linux/qualcommax" bash -c '
KCFG="./target/linux/qualcommax/config-6.12"
[ -f "$KCFG" ] || KCFG="./target/linux/qualcommax/config-6.6"
[ -f "$KCFG" ] || exit 0
grep -q "CONFIG_DEBUG_INFO_BTF" "$KCFG" || cat >> "$KCFG" << '"'"'BTFEOT'"'"'
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_BPF_EVENTS=y
CONFIG_CGROUP_BPF=y
BTFEOT
'

# ---------- 删冗余源码 ----------
rm -rf ./package/viking/gecoosac 2>/dev/null
rm -rf ./package/viking/luci-app-wolultra 2>/dev/null
rm -rf ./package/natmapt ./package/stuntman ./package/luci-app-natmapt 2>/dev/null
rm -rf ./feeds/packages/net/fullconenat-sonic ./feeds/luci/applications/luci-app-fullconenat-sonic 2>/dev/null
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
