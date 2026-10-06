#!/bin/bash
set -eu
if [ -f /home/appbox/mongodb/data/WiredTiger ]; then
    touch /run/rocketchat_existing_database
fi
