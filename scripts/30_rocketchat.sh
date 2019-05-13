#!/bin/bash
set -e

if [ ! -f /etc/rc_installed ]; then
    echo "Creating Directories"
    mkdir -p /home/appbox/rocketchat
    mkdir -p /home/appbox/rocketchat/app/uploads

    echo "Installing Rocketchat"
    cd /home/appbox/rocketchat \
     && curl -L https://releases.rocket.chat/${RC_VERSION}/download -o rocket.chat.tgz \
     && mkdir -p /home/appbox/rocketchat/app \
     && tar -zxf rocket.chat.tgz -C /home/appbox/rocketchat/app \
     && rm rocket.chat.tgz \
     && cd /home/appbox/rocketchat/app/bundle/programs/server \
     && npm install \
     && npm cache clear --force

     echo "Setting Permissions"
     chown -R appbox:appbox /home/appbox

# Setup Rocketchat Daemon
echo "Setting up Rocketchat Daemon"
mkdir -p /etc/service/rocketchat
cat << EOF >> /etc/service/rocketchat/run
#!/bin/sh
exec nodejs /home/appbox/rocketchat/app/bundle/main.js
EOF
chmod +x /etc/service/rocketchat/run

    until [[ $(curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST "https://api.cylo.io/v1/apps/installed/${INSTANCE_ID}" | grep '200') ]]
       do
       sleep 5
    done
    touch /etc/rc_installed
fi

cd /home/appbox/rocketchat/app/bundle