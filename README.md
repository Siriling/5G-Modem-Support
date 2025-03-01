# 5G-Modem-Support Enhanced
## Features
- Auto-detect WWAN cards by VID:PID (`detect_modem.sh`)
- Band locking for 4G/5G optimization (`band_lock.sh`)
- Detailed modem diagnostics (`modem_diag.sh`)
- Multi-protocol support: QMI, MBIM, PPP (`modem_connect.sh`)
## Installation
1. Clone repo: `git clone git@github.com:Doanduy09/5G-Modem-Support.git`
2. Copy scripts to OpenWrt: `scp scripts/* root@192.168.1.1:/usr/bin/`
## Usage
- Detect modem: `sh /usr/bin/detect_modem.sh`
- Lock bands: `sh /usr/bin/band_lock.sh "1,3,41"`
- Diagnostics: `sh /usr/bin/modem_diag.sh`
- Connect: `sh /usr/bin/modem_connect.sh qmi`
