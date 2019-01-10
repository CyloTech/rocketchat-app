#!/bin/sh
set -x

/bin/sh /configmongo.sh

export MONGO_URL="mongodb://mongoUser:mongoPass@localhost:27017/rocketchat?authSource=admin"

if [ ! -f /etc/rc_installed ]; then
    echo "Installing RocketChat"
    sleep 5

    cd /data \
     && curl -L https://releases.rocket.chat/latest/download -o rocket.chat.tgz \
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

    #Tell Apex we're done installing.
    curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST "https://api.cylo.io/v1/apps/installed/$INSTANCE_ID"

    touch /etc/rc_installed
fi

cd /data/app/bundle


echo "Starting MongoDB with Supervisor"
exec /usr/bin/supervisord -n -c /etc/supervisord.conf