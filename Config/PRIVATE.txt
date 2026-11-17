# ============================================================
# PRIVATE.sh - 亚瑟 AX1800 Pro (1G RAM) 专属配置
# dae + honk + NSS 共存 | BTF/eBPF | 无线双频固化
# ============================================================

# ---------- 设备锁定：仅亚瑟 ----------
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y

# 取消所有其他 IPQ60xx 设备
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_qihoo_360v6=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_anysafe_e1=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_dptotech_ap3000-2c=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_glinet_gl-ax1800=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_glinet_gl-axt1800=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_link_nn6000-v1=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_link_nn6000-v2=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_linksys_mr7350=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_linksys_mr7500=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_philips_ly1800=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_redmi_ax5=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_redmi_ax5-jdcloud=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_sy_y6010=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_xiaomi_ax1800=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_zn_m2=n

# ---------- 内核 eBPF / BTF（dae + honk 核心依赖） ----------
CONFIG_KERNEL_BPF=y
CONFIG_KERNEL_BPF_SYSCALL=y
CONFIG_KERNEL_BPF_JIT=y
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_NET_CLS_BPF=y
CONFIG_KERNEL_NET_ACT_BPF=y
CONFIG_KERNEL_XDP_SOCKETS=y
CONFIG_KERNEL_NETFILTER_XT_MATCH_BPF=y

# ---------- BTF 内核模块包 ----------
CONFIG_PACKAGE_vmlinux-btf=y
CONFIG_PACKAGE_kmod-sched-core=y
CONFIG_PACKAGE_kmod-sched-bpf=y
CONFIG_PACKAGE_kmod-veth=y
CONFIG_PACKAGE_kmod-xdp-sockets-diag=y
CONFIG_PACKAGE_kmod-nft-core=y
CONFIG_PACKAGE_kmod-nft-queue=y
CONFIG_PACKAGE_kmod-nfnetlink-queue=y
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_libstdcpp=y

# ---------- NSS 硬件加速（1G 版全开，与 eBPF 共存） ----------
CONFIG_PACKAGE_kmod-qca-nss-drv=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-drv-pppoe=y
CONFIG_PACKAGE_kmod-qca-nss-drv-bridge-mgr=y
CONFIG_PACKAGE_kmod-qca-nss-drv-vlan-mgr=y
CONFIG_PACKAGE_kmod-nss-wifi-drv=y
CONFIG_PACKAGE_qca-nss-firmware-ipq60xx=y
CONFIG_PACKAGE_nss-ifb=y

# 关掉与 eBPF 冲突的内核 flow offload（NSS 接管，不用这个）
CONFIG_PACKAGE_kmod-nft-offload=n
CONFIG_PACKAGE_kmod-ipt-offload=n

# ---------- dae 全家桶 ----------
CONFIG_PACKAGE_dae=y
CONFIG_PACKAGE_daed=y
CONFIG_PACKAGE_luci-app-dae=y
CONFIG_PACKAGE_luci-app-daed=y
CONFIG_PACKAGE_luci-lib-daeuniverse=y

# ---------- honk ----------
CONFIG_PACKAGE_honk=y
CONFIG_PACKAGE_luci-app-honk=y

# ---------- OpenClash（不含内核二进制） ----------
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_dnsmasq=n
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_kmod-nft-tproxy=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-tun=y

# ---------- ttyd 网页终端 ----------
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y

# ---------- 调试工具 ----------
CONFIG_PACKAGE_bpftool=y
CONFIG_PACKAGE_tcpdump=y

# ---------- 禁用冗余/冲突插件 ----------
CONFIG_PACKAGE_luci-app-gecoosac=n
CONFIG_PACKAGE_luci-app-fullconenat-sonic=n
CONFIG_PACKAGE_luci-app-natmapt=n
CONFIG_PACKAGE_luci-app-wolultra=n
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-i18n-homeproxy-zh-cn=n
CONFIG_PACKAGE_sing-box=n
CONFIG_PACKAGE_luci-app-nss-userspace=n
CONFIG_PACKAGE_luci-app-upnp=n
