#!/usr/bin/env python3
"""Fail closed unless the authenticated registry reports this tag absent."""
import json
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request

if len(sys.argv) != 2 or sys.argv[1] != 'repo.cylo.net/rocketchat:8.9.0':
    raise SystemExit('Unexpected Rocket.Chat image reference')
try:
    credentials = json.loads((Path.home() / '.docker/config.json').read_text())
    auth = next(value['auth'] for key, value in credentials['auths'].items() if key.rstrip('/').removeprefix('https://') == 'repo.cylo.net')
    headers = {'Authorization': 'Basic ' + auth, 'Accept': 'application/vnd.docker.distribution.manifest.v2+json,application/vnd.oci.image.index.v1+json'}
    # Authenticate against an existing private image before interpreting absence.
    with urllib.request.urlopen(urllib.request.Request('https://repo.cylo.net/v2/rocketchat/manifests/8.8.0', headers=headers), timeout=60) as response:
        if response.status != 200:
            raise RuntimeError()
    image, tag = sys.argv[1].split('/', 1)[1].split(':')
    try:
        urllib.request.urlopen(urllib.request.Request(f'https://repo.cylo.net/v2/{image}/manifests/{tag}', headers=headers), timeout=60).close()
    except urllib.error.HTTPError as error:
        body = json.loads(error.read())
        codes = {entry.get('code') for entry in body.get('errors', [])}
        if error.code != 404 or not codes or not codes <= {'MANIFEST_UNKNOWN', 'NAME_UNKNOWN'}:
            raise RuntimeError()
        print('Authenticated registry confirms the Rocket.Chat release tag is absent')
    else:
        raise SystemExit('Rocket.Chat release tag already exists; replacement is refused')
except SystemExit:
    raise
except Exception:
    raise SystemExit('Registry authentication, transport or response verification failed; publication is refused')
