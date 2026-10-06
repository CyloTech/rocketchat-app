#!/usr/bin/env python3
from pathlib import Path
import re
logs = sorted(Path('/tmp/rocketchat-npm-cache/_logs').glob('*debug-0.log'))
if not logs:
    raise SystemExit('Npm did not create a diagnostic log')
for line in logs[-1].read_text(errors='replace').splitlines():
    if True:
        line = re.sub(r'[A-Za-z][A-Za-z0-9+.-]*://[^\s]+', '[url]', line)
        line = re.sub(r'(?i)(password|token|authorization|cookie)([=:]\s*)[^\s]+', r'\1\2[redacted]', line)
        print(line[:600])
