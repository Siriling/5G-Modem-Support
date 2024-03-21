# This is free software, licensed under the GNU General Public License v3.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-modem
LUCI_TITLE:=LuCI support for Modem
LUCI_PKGARCH:=all
PKG_VERSION:=1.0.0
PKG_LICENSE:=GPLv3
PKG_LINCESE_FILES:=LICENSE
PKF_MAINTAINER:=siriling <siriling@qq.com>
LUCI_DEPENDS:=+luci-compat +kmod-usb-net  +kmod-usb-net-cdc-ether +kmod-usb-acm \
		+kmod-usb-net-qmi-wwan  +kmod-usb-net-rndis +kmod-usb-serial-qualcomm \
		+kmod-usb-net-sierrawireless +kmod-usb-ohci +kmod-usb-serial \
		+kmod-usb-serial-option +kmod-usb-wdm \
		+kmod-usb2 +kmod-usb3 \
		+kmod-usb-net-cdc-mbim \
		+usbutils \
		+kmod-pcie_mhi \
		+pciutils \
		+quectel-CM-5G \
		+sms-tool \
		+jq +grep\

define Package/luci-app-modem/conffiles
/etc/config/modem
endef

define Package/$(PKG_NAME)/config
# shown in make menuconfig <Help>
help
	$(LUCI_TITLE)
	Version: $(PKG_VERSION)
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
