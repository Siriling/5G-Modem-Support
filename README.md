# 5G-Modem-Support Enhanced
## Features
- Hotplug support for auto-detection
- Firmware updates for modems
- Network optimization based on signal
- LuCI-ready JSON output
- Full WWAN automation
## Installation
1. Clone: `git clone git@github.com:Doanduy09/5G-Modem-Support.git`
2. Copy: `scp scripts/* root@192.168.1.1:/usr/bin/`
3. Hotplug: `scp scripts/wwan_hotplug.sh root@192.168.1.1:/etc/hotplug.d/usb/20-wwan`
4. Install deps: `opkg install atinout qmi-utils libmbim ip-full`
## Usage
- Run: `sh /usr/bin/main.sh {detect|install|lock <bands>|diag|connect|auto|update <firmware>|optimize|luci}`
- Example: `sh /usr/bin/main.sh optimize`
