# Copyright (C) 2023 Siriling <siriling@qq.com>
# This is free software, licensed under the GNU General Public License v3.
# Modified by ainuoyan, 2026-10-10: QDC507 support, serial locking and license metadata.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-modem
LUCI_TITLE:=LuCI support for Modem
LUCI_PKGARCH:=all
PKG_VERSION:=1.4.4
PKG_RELEASE:=2
PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKF_MAINTAINER:=Siriling <siriling@qq.com>
LUCI_DEPENDS:=+luci-compat \
		+kmod-usb2 +kmod-usb3 \
		+kmod-usb-net-sierrawireless +kmod-usb-ohci \
		+kmod-usb-serial-option +kmod-usb-serial +kmod-usb-serial-qualcomm \
		+kmod-usb-net +kmod-usb-acm \
		+kmod-usb-net-cdc-ether \
		+kmod-usb-net-cdc-mbim \
		+kmod-usb-net-rndis \
		+kmod-usb-net-cdc-ncm +kmod-usb-net-huawei-cdc-ncm \
		+usbutils \
		+kmod-pcie_mhi \
		+pciutils \
		+quectel-cm \
		+sms-tool \
		+ndisc6 +rdisc6 \
		+bc +jq +flock

define Package/luci-app-modem/conffiles
/etc/config/modem
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
