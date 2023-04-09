#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-rooterddns
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/luci-app-rooterddns
  SECTION:=luci
  CATEGORY:=LuCI
  DEPENDS:=+ddns-scripts +ddns-scripts_no-ip_com 
  SUBMENU:=3. Applications
  TITLE:=LuCI Support for Dynamic DNS Client
  PKGARCH:=all
endef

define Package/luci-app-rooterddns/description
  LuCI Support for Dynamic DNS Client
endef


define Build/Compile
endef

define Package/luci-app-rooterddns/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,luci-app-rooterddns))
