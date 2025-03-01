# 5G-Modem-Support Enhanced
## Features
- Auto-detect WWAN cards with kmod loading (`detect_modem.sh` + `load_kmod.sh`)
- Supported modems: Quectel, Sierra Wireless, Telit, Huawei, Fibocom
- Band locking (`band_lock.sh`)
- Diagnostics (`modem_diag.sh`)
- Multi-protocol support (`modem_connect.sh`)
- Multi-modem detection (`multi_modem.sh`)
- Signal monitoring (`signal_monitor.sh`)
- Auto IP recovery (`auto_reconnect.sh`)
## Installation
1. Clone repo: `git clone git@github.com:Doanduy09/5G-Modem-Support.git`
2. Copy scripts: `scp scripts/* root@192.168.1.1:/usr/bin/`
3. Install kmods on OpenWrt: `opkg install kmod-usb-serial kmod-qmi-wwan kmod-cdc-mbim kmod-sierra kmod-cdc-ether`
## Usage
- Detect and load kmods: `sh /usr/bin/main.sh detect`
- Full usage: `sh /usr/bin/main.sh {detect|lock <bands>|diag|connect <protocol>|auto}`
