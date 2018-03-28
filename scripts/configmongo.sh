#!/bin/sh

if [ ! -f /etc/app_configured ]; then

mkdir -p /data/db
mkdir -p /data/logs
mkdir -p /data/conf

echo "starting MongoDB without Auth"
mongod \
  --port ${SERVICE_PORT} \
  --dbpath ${SERVICE_HOME} \
  --logpath ${SERVICE_LOGFILE} \
  --logappend \
  -${SERVICE_LOGLEVEL} &

sleep 10

echo "Adding the MongoDB User"

mongo admin << EOF
use admin
db.createUser(
{
    user: "${DB_USER}",
    pwd: "${DB_PASS}",
    roles: [ "userAdminAnyDatabase",
             "dbAdminAnyDatabase",
             "readWriteAnyDatabase" ]
})
EOF

cat << EOF >> /data/conf/mongod.conf
security:
  authorization: enabled
EOF

sleep 5

echo "Killing MongoDB"
    pkill -9 mongod

echo "Installing Mongo Supervisor config"

mkdir -p /etc/supervisor/conf.d
cat << EOF >> /etc/supervisor/conf.d/mongod.conf
[program:mongod]
command=mongod --config /data/conf/mongod.conf --port ${SERVICE_PORT} --dbpath ${SERVICE_HOME} --logpath ${SERVICE_LOGFILE} --logappend -${SERVICE_LOGLEVEL}
autostart=true
autorestart=true
priority=10
stdout_events_enabled=true
stderr_events_enabled=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

    touch /etc/app_configured
fi