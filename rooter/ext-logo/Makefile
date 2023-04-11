#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-logo
PKG_VERSION:=4.500
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

# +kmod-rt2800-usb

define Package/ext-logo
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Optional Applications
  DEPENDS:=+luci-theme-openwrt-2020 +luci-theme-material
  TITLE:=ROOter logos
  PKGARCH:=all
endef

define Package/ext-logo/description
  ROOter logos
endef


define Build/Compile
endef

define Package/ext-logo/install
	$(CP) ./files/* $(1)/


endef

$(eval $(call BuildPackage,ext-logo))
