#!/usr/bin/env bash
set +x
set -Eeuo pipefail

exec 3>&1
exec > /dev/null 2>&1
failure_code=31
trap 'printf "Deployment failed.\n" >&3; exit "$failure_code"' ERR
fail() {
  printf 'Deployment failed.\n' >&3
  exit "$failure_code"
}

release_id=${1:-}
root=${2:-}
service=${3:-}
health_url=${4:-}
[[ "$release_id" =~ ^[0-9]+-[0-9]+$ ]] || fail
[[ "$root" =~ ^/[a-zA-Z0-9_/-]+$ && "$root" != / ]] || fail
[[ "$service" =~ ^[a-zA-Z0-9_-]+\.service$ ]] || fail
[[ "$health_url" =~ ^http://127\.0\.0\.1:[0-9]+/[a-zA-Z0-9/_-]+$ ]] || fail
release="$root/releases/$release_id"
archive="$root/incoming/$release_id.tar.gz"

failure_code=32
command -v pnpm > /dev/null
command -v curl > /dev/null
failure_code=33
mkdir -p "$release"
tar --exclude='*.map' --exclude='*.map.gz' --exclude='*.map.br' -xzf "$archive" -C "$release"
cd "$release"
failure_code=34
pnpm install --prod --frozen-lockfile --ignore-scripts

failure_code=35
previous=$(readlink -f "$root/current" || true)

ln -s "$release" "$root/current.next"
mv -Tf "$root/current.next" "$root/current"

rollback() {
  if [[ -n "$previous" && -d "$previous" ]]; then
    ln -s "$previous" "$root/current.rollback"
    mv -Tf "$root/current.rollback" "$root/current"
    sudo -n /usr/bin/systemctl restart "$service"
  else
    sudo -n /usr/bin/systemctl stop "$service"
  fi
}

failure_code=36
if sudo -n /usr/bin/systemctl restart "$service"; then
  failure_code=37
  for attempt in {1..20}; do
    if curl --fail --silent --max-time 3 "$health_url" > /dev/null; then
      printf 'Deployment completed.\n' >&3
      exit 0
    fi
    sleep 2
  done
fi
result_code=$failure_code
rollback || true
failure_code=$result_code
fail
