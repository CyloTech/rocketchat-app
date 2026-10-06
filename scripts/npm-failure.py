#!/usr/bin/env python3
from pathlib import Path
import re
logs = sorted(Path('/tmp/rocketchat-npm-cache/_logs').glob('*debug-0.log'))
if not logs:
    raise SystemExit('Npm did not create a diagnostic log')
for line in logs[-1].read_text(errors='replace').splitlines():
    if re.match(r'^\d+ (?:error|verbose (?:stack|title|cwd|node|npm|exit|code)|info (?:using|run))\b', line):
        line = re.sub(r'https?://[^\s]+', '[url]', line)
        line = re.sub(r'(?i)(password|token|authorization|cookie)([=:]\s*)[^\s]+', r'\1\2[redacted]', line)
        print(line[:600])
