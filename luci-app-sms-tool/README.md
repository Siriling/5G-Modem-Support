# LuCI 短信收件箱

本组件继承自 [Siriling/5G-Modem-Support](https://github.com/Siriling/5G-Modem-Support/tree/b1d9a12ac4c209b82fb9db533b067c3fec95a9a6/luci-app-sms-tool)，保留 Siriling、Rafał Wabik（IceG）等原作者署名，使用 [GPL-3.0](LICENSE)。ainuoyan 于 2026-10-10 增加后台收件、本地保存、导航与回归测试，安装包附带 [修改说明](root/usr/share/luci-app-sms-tool/MODIFICATIONS.txt)。

安装本仓库的 `sms-tool` 与本插件后，在“网络 → 移动通信模组 → 短信 → 配置”选择实际 AT 端口及接收缓冲区。单独安装短信插件也会创建该菜单。

后台服务 `sms-inbox` 每 10 秒扫描设备支持的 SM / ME 缓冲区。它将原始 PDU、解码内容和 SIM 身份保存到 `/etc/sms-tool/inbox.json`，完成文件同步、目录同步及读回核验后，再核对 SIM 和每个槽位的原始 PDU，逐条释放模组空间。保存失败、SIM 变化、槽位复用或原始数据缺失时保留模组中的短信。接收缓冲区可以选择模组内存 ME；SIM 无需作为唯一缓冲区。

浏览器每 5 秒读取本地记录，关闭页面仍会收件。长短信按 SIM 分组、发件人、参考号和总段数合并，并提示缺段。收到时间依据原始 PDU 的时区转换到浏览器本地时间。发送、USSD、AT 和收件共用串口锁，用户输入按 shell 参数转义。

网页删除通过带 CSRF 校验的 POST 请求，只删除选中的、已完成模组清理的本地记录；新到短信不会自动被选中。存储目录权限为 0700、短信文件为 0600，备份应保持私有。正常保留历史会占用路由器存储，请按需删除旧记录。

本次三个包的 release 均为 2，升级时需要同时安装本仓库的新版 `sms-tool` 与短信插件。

首次安装会启用并启动 `/etc/init.d/sms-inbox`。已有安装升级后应执行：

```sh
/etc/init.d/sms-inbox enable
/etc/init.d/sms-inbox restart
```

停止服务使用 `/etc/init.d/sms-inbox stop`；停用后模组空间仍可能被新短信占满。本地归档在服务重启后保留，不应在回退旧界面时删除。旧版本 `sms-tool` 缺少原始 PDU，不能用于自动释放空间。

后台核验目前在 QDC507 上验收，依赖 `AT+QCCID`、`AT+CPMS`、`AT+CMGR` 和 `AT+CMGD`；不支持这些命令的设备会显示错误并保留模组短信，尚未验证其他模组的收件兼容性。

在仓库根目录运行：

```sh
node luci-app-sms-tool/tests/inbox_test.js
node luci-app-sms-tool/tests/inbox_view_test.js
lua luci-app-sms-tool/tests/menu_test.lua
lua luci-app-sms-tool/tests/archive_test.lua luci-app-sms-tool/luasrc/model/sms_tool/inbox.lua
lua luci-app-sms-tool/tests/controller_test.lua luci-app-sms-tool/luasrc/controller/modem/sms.lua
```

Lua 测试使用 OpenWrt Lua 5.1 和 LuCI 库；归档测试模拟文件系统与模组，控制器测试只捕获命令，不发送短信。实机范围及未验证项见 [QDC507 说明](../luci-app-modem/QDC507.md)。
