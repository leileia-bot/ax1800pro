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

#修改vantage进度条标签字体（anothaDev/luci-theme-vantage#52）
FIX "theme-vantage" "$PACKAGE_PATH/luci-theme-vantage" sed -i \
	-e '/^\/\* progress bars: thin track/,$ { /^\.cbi-progressbar::before {/,/^}/ { s/^[[:space:]]*font: 500 var(--fs-micro)\/1\.2 var(--mono);/\tfont: inherit; line-height: normal;/; } }' \
	"$PACKAGE_PATH/luci-theme-vantage/luci-theme-vantage/htdocs/luci-static/vantage/vantage.css"

#扩大IPQ60xx京东云设备内核分区限制至12MB以支持BTF大内核
FIX "ipq60xx-kernel-size" "./target/linux/qualcommax/image" sed -i \
	's/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g' \
	"./target/linux/qualcommax/image/ipq60xx.mk"

#彻底删除不需要的冗余和冲突插件源码（防止被依赖自动拉回）
rm -rf ./package/viking/luci-app-homeproxy ./package/viking/sing-box
rm -rf ./package/viking/gecoosac
rm -rf ./package/viking/luci-app-wolultra ./package/viking/luci-app-upnp
rm -rf ./package/natmapt ./package/stuntman ./package/luci-app-natmapt
rm -rf ./feeds/packages/net/fullconenat-sonic ./feeds/luci/applications/luci-app-fullconenat-sonic
rm -rf ./feeds/luci/applications/luci-app-upnp ./feeds/packages/net/miniupnpd
rm -rf ./feeds/luci/applications/luci-app-samba4
