# sms-tool

OpenWrt 包定义来自 [Siriling/5G-Modem-Support](https://github.com/Siriling/5G-Modem-Support/tree/b1d9a12ac4c209b82fb9db533b067c3fec95a9a6/sms-tool)。C 程序来自 [obsy/sms_tool](https://github.com/obsy/sms_tool)，原生构建固定到 [57a68d07c3d38fd8766d2705fd2a2c1ae01ee004](https://github.com/obsy/sms_tool/tree/57a68d07c3d38fd8766d2705fd2a2c1ae01ee004)。

按文件名顺序应用四个补丁：

- `0001`：保留 Siriling 仓库已有补丁及 dwj0 署名。
- `0002`：ainuoyan 于 2026-10-10 修复 JSON 高字节的符号扩展，并标明文件修改。
- `0003`：恢复 Unicode 原作者和 HTML Tidy 来源与许可指向，不改编码实现。
- `0004`：在 JSON 中保留原始 PDU，拒绝空、奇数长度或非十六进制内容，供后台归档及逐槽核验使用。

主程序及新增 C 补丁沿用 [Apache-2.0](LICENSE-2.0.txt)。Unicode 转换实现保留 lovewilliam 署名，其中 Ben Bullock 的代码选用 [BSD-3-Clause](files/licenses/UNICODE-C-BSD-3-Clause.txt)，随附 [作者授权](files/licenses/UNICODE-C-AUTHORIZATION.txt)；HTML Tidy 部分随附 [原始版权与许可](files/licenses/HTML-TIDY-LICENSE.txt)。完整来源和修改日期见 [MODIFICATIONS.txt](files/MODIFICATIONS.txt)。OpenWrt 安装规则将这些文件与许可证一起安装到 `/usr/share/sms-tool/`。

在固定版本应用四个补丁后执行：

```sh
python3 sms-tool/tests/json_encoding_test.py /path/to/patched/sms_main.c
```

该测试编译真实序列化函数，覆盖 17 个码点及 signed / unsigned char 两种模式。`tests/pdu_replay.c` 仅在 Linux 私有伪终端回放模拟 PDU，用于检查中文、特殊字符、原始数据及错误输入；不要改为物理串口。完整 OpenWrt SDK APK/IPK 构建尚未完成验收。
