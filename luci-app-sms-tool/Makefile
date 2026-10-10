# Copyright (C) 2023 Siriling <siriling@qq.com>
# This is free software, licensed under the GNU General Public License v3.
# Modified by ainuoyan, 2026-10-10: durable inbox, navigation and license metadata.
# Package source: https://github.com/Siriling/5G-Modem-Support/tree/b1d9a12ac4c209b82fb9db533b067c3fec95a9a6/luci-app-sms-tool
# SMS adaptations and attribution: README.md and root/usr/share/luci-app-sms-tool/MODIFICATIONS.txt.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-sms-tool
LUCI_TITLE:=LuCI Support for sms_tool
LUCI_PKGARCH:=all
PKG_VERSION:=1.0.0
PKG_RELEASE:=2
PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKF_MAINTAINER:=siriling <siriling@qq.com>
LUCI_DEPENDS:=+sms-tool +luci-compat +flock +kmod-usb-serial +kmod-usb-serial-option

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
