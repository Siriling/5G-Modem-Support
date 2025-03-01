# 5G-Modem-Support Enhanced
## Features
- Dynamic kmod loading (`load_kmod.sh`)
- Modem profile database (`modem_profiles.sh`)
- Auto-detect with profiles (`detect_modem.sh`)
- Supported modems: Quectel, Sierra Wireless, Telit, Huawei, Fibocom, and more
- Band locking (`band_lock.sh`)
- Diagnostics (`modem_diag.sh`)
- Multi-protocol support (`modem_connect.sh`)
- Multi-modem detection (`multi_modem.sh`)
- Signal monitoring (`signal_monitor.sh`)
- Auto IP recovery (`auto_reconnect.sh`)
## Installation
1. Clone repo: `git clone git@github.com:Doanduy09/5G-Modem-Support.git`
2. Copy scripts: `scp scripts/* root@192.168.1.1:/usr/bin/`
3. Install kmods: `opkg install kmod-usb-serial kmod-qmi-wwan kmod-cdc-mbim kmod-sierra kmod-cdc-ether`
## Usage
- Detect modems: `sh /usr/bin/main.sh detect`
- Check logs: `cat /var/log/wwan_kmod.log`
- Full usage: `sh /usr/bin/main.sh {detect|lock <bands>|diag|connect <protocol>|auto}`
