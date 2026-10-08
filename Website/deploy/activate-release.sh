#!/usr/bin/env bash
set +x
set -Eeuo pipefail

exec 3>&1
exec > /dev/null 2>&1
trap 'printf "Deployment failed.\n" >&3' ERR
fail() {
  printf 'Deployment failed.\n' >&3
  exit 1
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

command -v pnpm > /dev/null
command -v curl > /dev/null
mkdir -p "$release"
tar --exclude='*.map' --exclude='*.map.gz' --exclude='*.map.br' -xzf "$archive" -C "$release"
cd "$release"
pnpm install --prod --frozen-lockfile --ignore-scripts

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

if sudo -n /usr/bin/systemctl restart "$service"; then
  for attempt in {1..20}; do
    if curl --fail --silent --max-time 3 "$health_url" > /dev/null; then
      printf 'Deployment completed.\n' >&3
      exit 0
    fi
    sleep 2
  done
fi
rollback
fail
