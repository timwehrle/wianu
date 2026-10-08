#!/usr/bin/env bash
set -euo pipefail

release_id=${1:?Missing release ID}
[[ "$release_id" =~ ^[0-9]+-[0-9]+$ ]] || exit 1
root=/srv/wianu
release="$root/releases/$release_id"
archive="$root/incoming/$release_id.tar.gz"

test -f "$root/shared/website.env"
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
    sudo -n /usr/bin/systemctl restart wianu.service
    echo "Restored previous release: $previous" >&2
  else
    sudo -n /usr/bin/systemctl stop wianu.service
    echo 'First deployment failed; inspect journalctl -u wianu.service.' >&2
  fi
}

if sudo -n /usr/bin/systemctl restart wianu.service; then
  for attempt in {1..20}; do
    if curl --fail --silent --max-time 3 http://127.0.0.1:3000/health > /dev/null; then
      echo "Deployed release $release_id"
      exit 0
    fi
    sleep 2
  done
fi
rollback
exit 1
