#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-huasifei16
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-huasifei16
  SECTION:=utils
  CATEGORY:=ROOter
  DEPENDS:=+ext-huasifei \
  		+luci-app-mwan3 +luci-app-dnsmasq-ipset
  TITLE:=ROOter support w/o MWan3 for Huasifei
  PKGARCH:=all
endef

define Package/ext-huasifei16/description
  Helper scripts to enable ROOter support for Huasifei
endef


define Build/Compile
endef

$(eval $(call BuildPackage,ext-huasifei16))
