﻿# Copyright 2020-2021 Rafał Wabik - IceG - From eko.one.pl forum
# Licensed to the GNU General Public License v3.0.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-sms-tool
LUCI_TITLE:=LuCI Support for sms_tool
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+sms-tool +kmod-usb-serial +kmod-usb-serial-option +luci-compat
PKG_VERSION:=1.9.2-20211018
PKG_LICENSE:=GPLv3

define Package/luci-app-sms-tool/postinst
#!/bin/sh
rm -rf /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/
/sbin/set_sms_ports.sh
exit 0
endef

define Package/$(PKG_NAME)/config
# shown in make menuconfig <Help>
help
	$(LUCI_TITLE)
	Version: $(PKG_VERSION)
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
