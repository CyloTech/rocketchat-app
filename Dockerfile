# Preserve the released MongoDB, volumes, supervisor and Appbox lifecycle.
FROM repo.cylo.net/rocketchat@sha256:a1f99468372b63ce2495956e1bceed024ceebc76b84f5750a100d9924473334f
ENV RC_VERSION=8.9.0 NODE_VERSION=24.15.0
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz" -o /tmp/node.tgz \
 && tar -xzf /tmp/node.tgz -C /usr/local --strip-components=1 \
 && rm /tmp/node.tgz
COPY scripts/npm-failure.py /usr/local/bin/rocketchat-npm-failure.py
RUN apt-get update \
 && apt-get install -y --no-install-recommends g++ make python3 \
 && curl -fsSL "https://releases.rocket.chat/${RC_VERSION}/download" -o /tmp/rocket.chat.tgz \
 && rm -rf /app/bundle \
 && tar -xzf /tmp/rocket.chat.tgz -C /app \
 && rm /tmp/rocket.chat.tgz \
 && cd /app/bundle/programs/server \
 && (npm install --cache /tmp/rocketchat-npm-cache || { python3 /usr/local/bin/rocketchat-npm-failure.py; exit 1; }) \
 && chown -R appbox:appbox /app \
 && rm -rf /var/lib/apt/lists/* \
 && npm cache clean --force
# Startup commands must not expand credentials into logs.
RUN sed -i '/^set -x$/d' /etc/my_init.d/19_mongo_upgrade.sh /etc/my_init.d/30_rocketchat.sh /scripts/mongodb.sh \
 && rm -f /usr/local/bin/deno

COPY scripts/01_detect_existing_database.sh /etc/my_init.d/01_detect_existing_database.sh
COPY scripts/30_rocketchat.sh /etc/my_init.d/30_rocketchat.sh
RUN chmod +x /etc/my_init.d/01_detect_existing_database.sh /etc/my_init.d/30_rocketchat.sh
