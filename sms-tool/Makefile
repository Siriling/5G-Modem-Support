# Package source: https://github.com/Siriling/5G-Modem-Support/tree/b1d9a12ac4c209b82fb9db533b067c3fec95a9a6/sms-tool
# C program upstream: https://github.com/obsy/sms_tool (Apache-2.0).
# Build revision and patch provenance: README.md and files/MODIFICATIONS.txt.

include $(TOPDIR)/rules.mk

PKG_NAME:=sms-tool
PKG_RELEASE:=2
PKG_LICENSE:=Apache-2.0 BSD-3-Clause HTMLTIDY
PKG_LICENSE_FILES:=LICENSE-2.0.txt licenses/UNICODE-C-BSD-3-Clause.txt licenses/HTML-TIDY-LICENSE.txt

PKG_SOURCE_URL:=https://github.com/obsy/sms_tool
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2021-08-24
PKG_SOURCE_VERSION:=57a68d07c3d38fd8766d2705fd2a2c1ae01ee004

include $(INCLUDE_DIR)/package.mk

define Package/sms-tool
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=sms tool
  URL:=https://github.com/obsy/sms_tool
endef

define Package/sms-tool/description
	SMS Tool for 3G/4G modem
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/licenses
	$(CP) ./files/licenses/* $(PKG_BUILD_DIR)/licenses/
	$(CP) ./files/MODIFICATIONS.txt $(PKG_BUILD_DIR)/
endef

define Package/sms-tool/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/sms_tool $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/usr/share/sms-tool/licenses
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/LICENSE-2.0.txt $(1)/usr/share/sms-tool/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/MODIFICATIONS.txt $(1)/usr/share/sms-tool/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/licenses/* $(1)/usr/share/sms-tool/licenses/
endef

$(eval $(call BuildPackage,sms-tool))
