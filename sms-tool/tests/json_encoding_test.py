#!/usr/bin/env python3
"""Exercise the real upstream serializer with signed and unsigned char builds."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

source = Path(sys.argv[1]).read_text()
start = source.index('static void print_json_escape_char(')
end = source.index('\n}\n', start) + 3
function = source[start:end]
points = [0, 8, 9, 10, 13, 34, 47, 92, 0x80, 0xA3, 0xE9, 0xFF, 0x4E2D, 0x6587, 0x9001, 0x8D39, 0xFF1A]
expected = [chr(point) for point in points]
body = ['#include <stdio.h>', function, 'int main(void) { puts("[");']
for i, point in enumerate(points):
    body += ['putchar(34);', f'print_json_escape_char({point >> 8}, {point & 255});', 'putchar(34);']
    if i != len(points) - 1:
        body += ['putchar(44);']
body += ['puts("]"); return 0; }']
with tempfile.TemporaryDirectory(prefix='sms-json-test-') as temp:
    path = Path(temp)
    (path / 'test.c').write_text('\n'.join(body))
    for flag in ('-fsigned-char', '-funsigned-char'):
        subprocess.run(['cc', flag, str(path / 'test.c'), '-o', str(path / 'test')], check=True)
        decoded = json.loads(subprocess.check_output([str(path / 'test')]).decode('utf-8'))
        assert decoded == expected, f'Unicode corruption with {flag}'
print(f'SMS JSON encoding: {len(points)} code points x 2 char modes passed')
