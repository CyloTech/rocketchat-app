#!/bin/bash
set -e

if [ ! -f /etc/rc_installed ]; then
    echo "Creating Directories"
    mkdir -p /home/appbox/rocketchat
    mkdir -p /home/appbox/rocketchat/app/uploads

    echo "Installing Rocketchat"
    cp -R /app /home/appbox/rocketchat/

    echo "Setting Permissions"
    chown -R appbox:appbox /home/appbox

echo "Starting MongoDB"
MONGO_PORT=${MONGO_PORT:-"27017"}
MONGO_LOGFILE=${MONGO_LOGFILE:-"/home/appbox/logs/mongodb/mongod.log"}
MONGO_USER=${MONGO_USER:-"mongo"}
MONGO_HOME=${MONGO_HOME:-"/home/appbox/mongodb/data"}
MONGO_LOGLEVEL=${MONGO_LOGLEVEL:-"v"}
DB_USER=${DB_USER:-"mongoUser"}
DB_PASS=${DB_PASS:-"mongoPass"}
MONGOD_PID=""
ROCKETCHAT_PID=""

cleanup_bootstrap() {
    if [ -n "${ROCKETCHAT_PID}" ] && kill -0 "${ROCKETCHAT_PID}" 2>/dev/null; then
        kill "${ROCKETCHAT_PID}" 2>/dev/null || true
        wait "${ROCKETCHAT_PID}" 2>/dev/null || true
    fi

    killall -9 node 2>/dev/null || true

    if [ -n "${MONGOD_PID}" ] && kill -0 "${MONGOD_PID}" 2>/dev/null; then
        kill "${MONGOD_PID}" 2>/dev/null || true
        wait "${MONGOD_PID}" 2>/dev/null || true
    fi
}

wait_for_authenticated_mongo() {
    for _ in $(seq 1 60); do
        if mongosh --port "${MONGO_PORT}" -u "${DB_USER}" -p "${DB_PASS}" --authenticationDatabase 'admin' --quiet --eval "db.runCommand({ ping: 1 }).ok" admin >/dev/null 2>&1; then
            return 0
        fi

        echo "Waiting for authenticated MongoDB connection..."
        sleep 2
    done

    echo "MongoDB authentication did not become ready"
    mongosh --port "${MONGO_PORT}" -u "${DB_USER}" -p "${DB_PASS}" --authenticationDatabase 'admin' --quiet --eval "db.runCommand({ ping: 1 })" admin || true
    return 1
}

wait_for_mongo_primary() {
    for _ in $(seq 1 60); do
        if mongosh --port "${MONGO_PORT}" -u "${DB_USER}" -p "${DB_PASS}" --authenticationDatabase 'admin' --quiet --eval "try { const status = rs.status(); quit(status.myState === 1 ? 0 : 1) } catch (e) { quit(1) }" admin >/dev/null 2>&1; then
            return 0
        fi

        echo "Waiting for MongoDB primary..."
        sleep 2
    done

    echo "MongoDB did not become primary in time"
    mongosh --port "${MONGO_PORT}" -u "${DB_USER}" -p "${DB_PASS}" --authenticationDatabase 'admin' --quiet --eval "rs.status()" admin || true
    return 1
}

wait_for_rocketcat_delete() {
    local result=""

    for _ in $(seq 1 300); do
        result="$(mongosh --port "${MONGO_PORT}" -u "${DB_USER}" -p "${DB_PASS}" --authenticationDatabase 'admin' --quiet --eval "const result = db.users.deleteOne({ username: 'rocket.cat' }); printjson(result);" rocketchat 2>&1)" || true

        if echo "${result}" | grep -q 'deletedCount: 1'; then
            return 0
        fi

        if echo "${result}" | grep -q 'Authentication failed'; then
            echo "MongoDB authentication failed while waiting for Rocket.Chat bootstrap"
            echo "${result}"
            return 1
        fi

        if ! kill -0 "${ROCKETCHAT_PID}" 2>/dev/null; then
            echo "Rocket.Chat exited before bootstrap completed"
            echo "Last MongoDB delete result: ${result}"
            return 1
        fi

        echo "Sleeping until rocketcat is deleted"
        sleep 2
    done

    echo "Timed out waiting for Rocket.Chat to create and delete rocket.cat"
    echo "Last MongoDB delete result: ${result}"
    return 1
}

/usr/bin/mongod --config /home/appbox/config/mongodb/mongod.conf --bind_ip 0.0.0.0 --port "${MONGO_PORT}" --dbpath "${MONGO_HOME}" --logpath "${MONGO_LOGFILE}" --logappend -"${MONGO_LOGLEVEL}" --replSet rs01 --oplogSize 128 &
MONGOD_PID=$!
trap cleanup_bootstrap EXIT

wait_for_authenticated_mongo
wait_for_mongo_primary

echo "Starting Rocketchat"

cd /home/appbox/rocketchat/app/bundle
su -s /bin/sh -c "node main.js" appbox &
ROCKETCHAT_PID=$!

wait_for_rocketcat_delete

echo "Sleeping for a minutes"
sleep 60

# On fresh installs, clear all workspace identity data (unique ID, fingerprint,
# cloud registration) generated during setup so Rocket.Chat starts completely
# clean on the final runit start. On upgrades, preserve everything.
if [ ! -f /home/appbox/rocketchat/.rc_setup_done ] && [ ! -f /run/rocketchat_existing_database ]; then
    echo "Fresh install - clearing workspace identity data for clean start"
    mongosh --port ${MONGO_PORT} -u ${DB_USER} -p ${DB_PASS} --authenticationDatabase 'admin' --quiet --eval '
        // Delete unique ID, deployment fingerprint, and all cloud workspace settings
        db.rocketchat_settings.deleteMany({
            $or: [
                { _id: "uniqueID" },
                { _id: /^Cloud_/ },
                { _id: /^Organization_/ },
                { _id: /FingerPrint/ },
                { _id: /Deployment_/ }
            ]
        });
    ' rocketchat 2>/dev/null || true
    touch /home/appbox/rocketchat/.rc_setup_done
fi

cleanup_bootstrap
trap - EXIT
echo "Killing MongoDB"

# Setup Rocketchat Daemon
echo "Setting up Rocketchat Daemon"
mkdir -p /etc/service/rocketchat
cat << EOF > /etc/service/rocketchat/run
#!/bin/sh
cd /home/appbox/rocketchat/app/bundle
su -s /bin/sh -c "exec node main.js" appbox
EOF
chmod +x /etc/service/rocketchat/run

    if [ "${APP_APEX_CALLBACK:-true}" = true ]; then
        if [ -z "${INSTANCE_ID:-}" ]; then
            echo "INSTANCE_ID is not set; cannot send install callback"
            exit 1
        fi

        callback_complete=false
        for _ in $(seq 1 60); do
            if curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST "https://api.cylo.io/v1/apps/installed/${INSTANCE_ID}" | grep -q '200'; then
                callback_complete=true
                break
            fi

            sleep 5
        done

        if [ "${callback_complete}" != true ]; then
            echo "Timed out waiting for install callback"
            exit 1
        fi
    fi
    touch /etc/rc_installed
fi
