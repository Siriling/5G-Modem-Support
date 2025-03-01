# 5G-Modem-Support Enhanced
## Features
- Auto-detect WWAN cards (`detect_modem.sh`)
- Band locking (`band_lock.sh`)
- Diagnostics (`modem_diag.sh`)
- Multi-protocol: QMI, MBIM, PPP (`modem_connect.sh`)
## Installation
1. Clone: `git clone git@github.com:Doanduy09/5G-Modem-Support.git`
2. Copy: `scp scripts/* root@192.168.1.1:/usr/bin/`
## Usage
- Detect: `sh /usr/bin/detect_modem.sh`
- Lock bands: `sh /usr/bin/band_lock.sh "1,3,41"`
- Diagnose: `sh /usr/bin/modem_diag.sh`
- Connect: `sh /usr/bin/modem_connect.sh qmi`
