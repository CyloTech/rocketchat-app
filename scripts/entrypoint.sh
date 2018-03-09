#!/bin/sh
set -x

export DB_USER=$(pwgen -s 8 1)
export DB_PASS=$(pwgen -s 12 1)

/bin/sh /configmongo.sh

export MONGO_URL="mongodb://${DB_USER}:${DB_PASS}@localhost:27017/rocketchat?authSource=admin"

if [ ! -f /data/conf/rocketchatinstalled ]; then
    echo "Installing RocketChat"
    sleep 5

    cd /data \
     && curl -SLf "https://releases.rocket.chat/0.63.0-develop/download/" -o rocket.chat.tgz \
     && mkdir -p /data/app \
     && tar -zxf rocket.chat.tgz -C /data/app \
     && rm rocket.chat.tgz \
     && cd /data/app/bundle/programs/server \
     && npm install \
     && npm cache clear --force

cat << EOF >> /etc/supervisor/conf.d/rocketchat.conf
[program:rocketchat]
command=nodejs /data/app/bundle/main.js
autostart=true
autorestart=true
priority=20
stdout_events_enabled=true
stderr_events_enabled=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

    touch /data/conf/rocketchatinstalled
fi

cd /data/app/bundle


echo "Starting MongoDB with Supervisor"
exec /usr/bin/supervisord -n -c /etc/supervisord.conf