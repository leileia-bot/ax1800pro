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

# ---------- daede 一体源（kenzok8）+ dae/daed 后端 ----------
UPDATE_PACKAGE "openwrt-daede" "kenzok8/openwrt-daede" "main" "pkg"
UPDATE_PACKAGE "dae" "daeuniverse/dae" "main" "pkg"
UPDATE_PACKAGE "daed" "daeuniverse/daed" "main" "pkg"

# ---------- honk（kenzok8/openwrt-honk 一体源）----------
UPDATE_PACKAGE "openwrt-honk" "kenzok8/openwrt-honk" "main" "pkg"

# ---------- 双频无线固化：5G CN/36/HE80 | 2.4G CN/1/HT20 ----------
mkdir -p "$PACKAGE_PATH/base-files/files/etc/uci-defaults"

cat > "$PACKAGE_PATH/base-files/files/etc/uci-defaults/99-wireless-cn" << 'WLEOT'
#!/bin/sh

# 等 wireless 配置生成完毕
for i in 1 2 3 4 5 6 7 8 9 10; do
	[ -f /etc/config/wireless ] && break
	sleep 2
done

# 遍历 wireless 配置里所有 wifi-device 节
uci show wireless 2>/dev/null | while IFS='=' read -r key val; do
	case "$key" in
		wireless.radio[0-9])
			radio=$(echo "$key" | sed 's/.*\.//')
			band=$(uci -q get wireless.$radio.band 2>/dev/null)
			case "$band" in
				5g|60g)
					uci set wireless.$radio.country='CN'
					uci set wireless.$radio.channel='36'
					uci set wireless.$radio.htmode='HE80'
					uci delete wireless.$radio.channels 2>/dev/null
					;;
				2g)
					uci set wireless.$radio.country='CN'
					uci set wireless.$radio.channel='1'
					uci set wireless.$radio.htmode='HT20'
					uci delete wireless.$radio.channels 2>/dev/null
					;;
			esac
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
