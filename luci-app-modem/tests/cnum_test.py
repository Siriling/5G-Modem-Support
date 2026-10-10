#!/usr/bin/env python3
"""Exercise the real SIM-info reader using AT responses, without a modem."""
from pathlib import Path
import subprocess
import sys
import tempfile

source = Path(sys.argv[1] if len(sys.argv) > 1 else
              'luci-app-modem/root/usr/share/modem/quectel.sh').resolve()
cases = [
    ('omitted label', '\r\n+CNUM: ,"+441234567890",145\r\n', '+441234567890'),
    ('empty quoted label', '\r\n+CNUM: "","+441234567890",145\r\n', '+441234567890'),
    ('named entry', '\r\n+CNUM: "Voice","01234567890",129\r\n', '01234567890'),
    ('label with comma', '\r\n+CNUM: "My, SIM","+441234567890",145\r\n', '+441234567890'),
    ('echo and extra lines', 'AT+CNUM\r\n\r\n+CNUM: ,"+441234567890",145\r\n\r\nOK\r\n', '+441234567890'),
    ('empty number', '\r\n+CNUM: "Voice","",145\r\n', ''),
    ('no stored number', '\r\nOK\r\n', ''),
    ('unsupported command', '\r\nERROR\r\n', ''),
]

with tempfile.TemporaryDirectory(prefix='modem-cnum-test-') as directory:
    fixture = Path(directory)
    (fixture / 'modem_at.sh').write_text('''#!/bin/sh
case "$2" in
    'AT+CPIN?') printf '\\r\\n+CPIN: READY\\r\\n' ;;
    'AT+CNUM') cat "${0%/*}/cnum.response" ;;
    *) printf '\\r\\nOK\\r\\n' ;;
esac
''')
    for name, response, expected in cases:
        (fixture / 'cnum.response').write_bytes(response.encode('ascii'))
        result = subprocess.run([
            'sh', '-c',
            '. "$1"; SCRIPT_DIR="$2"; debug() { :; }; '
            'at_port=/dev/mock; quectel_sim_info; printf "%s" "$sim_number"',
            'cnum-test', str(source), str(fixture)
        ], check=True, capture_output=True, text=True)
        assert result.stdout == expected, f'{name}: {result.stdout!r} != {expected!r}'
print(f'CNUM regression tests passed: {len(cases)}')
