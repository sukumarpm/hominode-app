#!/bin/sh

set -eu

usage() {
  echo "Usage: $0 <marketing-build-dir> <resident-flutter-build-dir>" >&2
  exit 64
}

[ "$#" -eq 2 ] || usage

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
marketing_dir=$(CDPATH= cd -- "$1" && pwd)
resident_dir=$(CDPATH= cd -- "$2" && pwd)
deploy_root="$repository_root/hosting/hominode-prod"
resident_deploy_dir="$deploy_root/__resident_app"

[ -f "$marketing_dir/index.html" ] || {
  echo "Marketing build is missing index.html: $marketing_dir" >&2
  exit 66
}

[ -f "$resident_dir/index.html" ] || {
  echo "Resident Flutter build is missing index.html: $resident_dir" >&2
  exit 66
}

grep -Fq '<base href="/">' "$resident_dir/index.html" || {
  echo "Resident Flutter build must use a public browser base of /." >&2
  exit 65
}

[ ! -e "$marketing_dir/__resident_app" ] || {
  echo "Marketing build already owns reserved path /__resident_app/." >&2
  exit 65
}

staging_root=$(mktemp -d "${TMPDIR:-/tmp}/hominode-hosting.XXXXXX")
trap 'rm -rf "$staging_root"' EXIT HUP INT TERM

mkdir -p "$staging_root/site/__resident_app"
cp -R "$marketing_dir/." "$staging_root/site/"
cp -R "$resident_dir/." "$staging_root/site/__resident_app/"

rm -rf "$deploy_root"
mkdir -p "$(dirname -- "$deploy_root")"
mv "$staging_root/site" "$deploy_root"

echo "Assembled hominode-prod Hosting release at: $deploy_root"
echo "Marketing entry: $deploy_root/index.html"
echo "Resident entry:  $resident_deploy_dir/index.html"
