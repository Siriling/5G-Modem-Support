# Copyright (C) 2023 Siriling <siriling@qq.com>
# This is free software, licensed under the GNU General Public License v3.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-modem
LUCI_TITLE:=LuCI support for Modem
LUCI_PKGARCH:=all
PKG_VERSION:=1.4.4
PKG_LICENSE:=GPLv3
PKG_LINCESE_FILES:=LICENSE
PKF_MAINTAINER:=Siriling <siriling@qq.com>
LUCI_DEPENDS:=+luci-compat \
		+usbutils \
		+pciutils \
		+quectel-CM-5G \
		+sms-tool \
		+jq \

define Package/luci-app-modem/conffiles
/etc/config/modem
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
