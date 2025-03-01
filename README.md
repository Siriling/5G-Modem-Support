# 5G-Modem-Support Enhanced
## Features
- Auto-detect WWAN cards (`detect_modem.sh`)
- Band locking (`band_lock.sh`)
- Diagnostics (`modem_diag.sh`)
- Multi-protocol support (`modem_connect.sh`)
- Multi-modem detection (`multi_modem.sh`)
- Signal monitoring (`signal_monitor.sh`)
## Installation
1. Clone repo: `git clone git@github.com:Doanduy09/5G-Modem-Support.git`
2. Copy scripts: `scp scripts/* root@192.168.1.1:/usr/bin/`
## Usage
- Run: `sh /usr/bin/main.sh {detect|lock <bands>|diag|connect <protocol>}`
- Example: `sh /usr/bin/main.sh lock "1,3,41"`
