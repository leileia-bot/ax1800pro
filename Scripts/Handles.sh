# ============================================================
# 亚瑟 AX1800 Pro (1G RAM) - 构建处理脚本
# daede + honk + NSS 共存 | BTF/eBPF | 无线双频固化
# ============================================================

#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
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
#修改argon主题字体和颜色
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

#修改aurora菜单式样
FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

#修改vantage进度条标签字体（anothaDev/luci-theme-vantage#52）
FIX "theme-vantage" "$PACKAGE_PATH/luci-theme-vantage" sed -i \
	-e '/^\/\* progress bars: thin track/,$ { /^\.cbi-progressbar::before {/,/^}/ { s/^[[:space:]]*font: 500 var(--fs-micro)\/1\.2 var(--mono);/\tfont: inherit; line-height: normal;/; } }' \
	"$PACKAGE_PATH/luci-theme-vantage/luci-theme-vantage/htdocs/luci-static/vantage/vantage.css"

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"

# ---------- 内核分区 12MB + rootfs 20MB ----------
FIX "ipq60xx-kernel-size" "./target/linux/qualcommax/image" sed -i \
	-E 's/^([[:space:]]*KERNEL_SIZE[[:space:]]*:=[[:space:]]*).*/\112288k/' \
	"./target/linux/qualcommax/image/ipq60xx.mk"

FIX "ipq60xx-rootfs-size" "./target/linux/qualcommax/image" sed -i \
	-E 's/^([[:space:]]*ROOTFS_SIZE[[:space:]]*:=[[:space:]]*).*/\120480k/' \
	"./target/linux/qualcommax/image/ipq60xx.mk"

# ---------- BTF kconfig 强制覆盖（针对 6.18：关 REDUCED，开 BTF）----------
FIX "btf-kconfig-force-618" "./target/linux/qualcommax" bash -c '
KCFG="./target/linux/qualcommax/config-6.18"
[ -f "$KCFG" ] || exit 0
sed -i "/^CONFIG_DEBUG_INFO_REDUCED=/d" "$KCFG"
sed -i "/^CONFIG_DEBUG_INFO_BTF=/d" "$KCFG"
cat >> "$KCFG" << '"'"'BTFEOT'"'"'
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_REDUCED=n
CONFIG_DEBUG_INFO_DWARF5=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_DEBUG_INFO_BTF_MODULES=y
CONFIG_PAHOLE_HAS_SPLIT_BTF=y
CONFIG_BPF_EVENTS=y
CONFIG_CGROUP_BPF=y
CONFIG_XDP_SOCKETS=y
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

# ---------- daede 一体源（kenzok8）+ dae/daed 后端 ----------
UPDATE_PACKAGE "openwrt-daede" "kenzok8/openwrt-daede" "main" "pkg"
UPDATE_PACKAGE "dae" "daeuniverse/dae" "main" "pkg"
UPDATE_PACKAGE "daed" "daeuniverse/daed" "main" "pkg"

# ---------- honk（189160/luci-app-honk，支持 aarch64）----------
UPDATE_PACKAGE "luci-app-honk" "189160/luci-app-honk" "main" "pkg"

# ---------- 双频无线固化：hotplug 方式（不依赖开机时序）----------
mkdir -p "$PACKAGE_PATH/base-files/files/etc/hotplug.d/ieee80211"
cat > "$PACKAGE_PATH/base-files/files/etc/hotplug.d/ieee80211/10-cn-fix" << 'WLEOT'
#!/bin/sh
# phy 上线后按实际频段固化 CN/信道/带宽，幂等执行
[ "$ACTION" = "add" ] || exit 0

DEV="${DEVNAME:-$DEVICE}"
[ -n "$DEV" ] || exit 0

INFO=$(iw phy "$DEV" info 2>/dev/null)
[ -n "$INFO" ] || exit 0

# 取该 phy 支持的最高频段：Band 2 优先按 5G 处理
case "$INFO" in
	*"Band 2:"*)
		RD="radio0"; CH="36"; HM="HE80"; BAND="5g"
		;;
	*"Band 1:"*)
		RD="radio1"; CH="1"; HM="HT20"; BAND="2g"
		;;
	*)
		exit 0
		;;
esac

# 找到该 phy 对应的 wireless 配置节（匹配 path 或 phy）
SEC=""
for s in $(uci show wireless 2>/dev/null | sed -n 's/^wireless\.\(radio[0-9]*\)=wifi-device$/\1/p'); do
	P=$(uci -q get "wireless.$s.path")
	PH=$(uci -q get "wireless.$s.phy")
	[ "$P" = "$DEV" ] || [ "$PH" = "$DEV" ] && { SEC="$s"; break; }
done
[ -n "$SEC" ] || SEC="$RD"

# 已在目标值上就跳过，避免反复写 flash
CUR_CH=$(uci -q get "wireless.$SEC.channel")
CUR_HM=$(uci -q get "wireless.$SEC.htmode")
CUR_CC=$(uci -q get "wireless.$SEC.country")
if [ "$CUR_CH" = "$CH" ] && [ "$CUR_HM" = "$HM" ] && [ "$CUR_CC" = "CN" ]; then
	exit 0
fi

uci set "wireless.$SEC.country=CN"
uci set "wireless.$SEC.channel=$CH"
uci set "wireless.$SEC.htmode=$HM"
uci delete "wireless.$SEC.channels" 2>/dev/null
uci commit wireless

# 关掉内核 flow offload（交给 NSS，避免与 eBPF/dae 冲突）
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

logger -t cn-wifi "fixed $SEC ($DEV) -> CN ch$CH $HM"

# 配置已由 netifd 加载过，需要重新加载无线才生效
wifi reload
exit 0
WLEOT
chmod +x "$PACKAGE_PATH/base-files/files/etc/hotplug.d/ieee80211/10-cn-fix"

# ---------- 首次启动兜底：等配置生成后再修正一次 ----------
mkdir -p "$PACKAGE_PATH/base-files/files/etc/uci-defaults"
cat > "$PACKAGE_PATH/base-files/files/etc/uci-defaults/99-wireless-cn" << 'WLEOT'
#!/bin/sh
# 等待 mac80211.uc 生成 /etc/config/wireless
for i in $(seq 1 30); do
	[ -s /etc/config/wireless ] && break
	sleep 2
done

uci show wireless 2>/dev/null | while IFS='=' read -r key val; do
	case "$key" in
		wireless.radio[0-9]*)
			[ "$val" = "wifi-device" ] || continue
			R="${key#wireless.}"
			C=$(uci -q get "wireless.$R.channel")
			case "$C" in
				36|40|44|48|149|153|157|161|165)
					uci set "wireless.$R.country=CN"
					uci set "wireless.$R.htmode=HE80"
					uci delete "wireless.$R.channels" 2>/dev/null
					;;
				[1-9]|1[1-3])
					uci set "wireless.$R.country=CN"
					uci set "wireless.$R.htmode=HT20"
					uci delete "wireless.$R.channels" 2>/dev/null
					;;
			esac
			;;
	esac
done

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
echo "  Done - 亚瑟 1G / daede / honk / NSS / 双频固化"
echo "  5G: CN ch36 HE80 | 2.4G: CN ch1 HT20"
echo "=================================================="
