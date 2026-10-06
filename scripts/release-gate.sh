#!/usr/bin/env bash
set -euo pipefail
image_ref=${1:?Expected image reference}
[[ "$image_ref" = repo.cylo.net/rocketchat:8.9.0 ]] || exit 1
[[ "$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$image_ref")" = linux/amd64 ]]
run_id="rocketchat-890-gate-$$"
fresh="${run_id}-fresh"
old="${run_id}-old"
new="${run_id}-new"
volumes=("${run_id}-data" "${run_id}-logs")
cleanup() {
  docker rm -f "$fresh" "$old" "$new" >/dev/null 2>&1 || true
  docker volume rm "${volumes[@]}" >/dev/null 2>&1 || true
}
trap cleanup EXIT
wait_version() {
  local container=$1 expected=$2 info attempt
  for attempt in $(seq 1 450); do
    [[ "$(docker inspect --format '{{.State.Running}}' "$container")" = true ]] || { echo "Test container exited: $container" >&2; return 1; }
    info=$(docker exec "$container" curl -fsS http://127.0.0.1/api/info 2>/dev/null || true)
    if printf '%s' "$info" | python3 -c 'import json,sys; data=json.load(sys.stdin); sys.exit(0 if data.get("version") in {sys.argv[1],".".join(sys.argv[1].split(".")[:2])} else 1)' "$expected" 2>/dev/null; then
      echo "Verified $container serves Rocket.Chat $expected"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for $container" >&2
  return 1
}
mongo_eval() { docker exec "$1" bash -c 'exec mongosh --quiet --port "${MONGO_PORT:-27017}" -u "${DB_USER:-mongoUser}" -p "${DB_PASS:-mongoPass}" --authenticationDatabase admin rocketchat --eval "$1"' bash "$2" >/dev/null; }
run() { docker run -d --platform linux/amd64 --name "$1" -e APP_APEX_CALLBACK=false "${@:3}" "$2" >/dev/null; }
docker run --rm --entrypoint sh "$image_ref" -ec '
 test "$RC_VERSION" = 8.9.0
 test "$(node --version)" = v24.15.0
 mongod --version | grep -Fq v8.0.
 test "$(id -u appbox)" = 1000
 test -f /app/bundle/main.js
 ! grep -Eq "^set -x$" /etc/my_init.d/30_rocketchat.sh
'
run "$fresh" "$image_ref"
wait_version "$fresh" 8.9.0
docker restart "$fresh" >/dev/null
wait_version "$fresh" 8.9.0
docker stop --time 90 "$fresh" >/dev/null
docker pull repo.cylo.net/rocketchat:8.8.0 >/dev/null
for volume in "${volumes[@]}"; do docker volume create "$volume" >/dev/null; done
mounts=(-v "${volumes[0]}:/home/appbox/mongodb/data" -v "${volumes[1]}:/home/appbox/logs")
run "$old" repo.cylo.net/rocketchat:8.8.0 "${mounts[@]}"
wait_version "$old" 8.8.0
mongo_eval "$old" 'db.appbox_release_canary.insertOne({_id:"upgrade-8.9.0",value:"persistent-data"}); db.rocketchat_settings.updateOne({_id:"uniqueID"},{$set:{value:"appbox-upgrade-identity-canary"}},{upsert:true});'
docker stop --time 90 "$old" >/dev/null
run "$new" "$image_ref" "${mounts[@]}"
wait_version "$new" 8.9.0
mongo_eval "$new" 'quit(db.appbox_release_canary.findOne({_id:"upgrade-8.9.0"})?.value === "persistent-data" && db.rocketchat_settings.findOne({_id:"uniqueID"})?.value === "appbox-upgrade-identity-canary" ? 0 : 1)'
docker restart "$new" >/dev/null
wait_version "$new" 8.9.0
python3 "$(dirname "$0")/registry-check.py" "$image_ref"
echo "Fresh install, restart and 8.8.0 persistent-data upgrade passed"
