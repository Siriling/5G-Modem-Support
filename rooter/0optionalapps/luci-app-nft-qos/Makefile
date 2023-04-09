#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-nft-qos
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/luci-app-nft-qos
  SECTION:=luci
  CATEGORY:=LuCI
  DEPENDS:=+nft-qos
  SUBMENU:=3. Applications
  TITLE:=support for NFT over QOS
  PKGARCH:=all
endef

define Package/luci-app-nft-qos/description
  Helper scripts to enable NFT over QOS
endef


define Build/Compile
endef

define Package/luci-app-nft-qos/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,luci-app-nft-qos))
