#!/bin/zsh
# Updates the version and sha256 stanzas of a Homebrew cask file to match a
# release zip. Used by the release workflow after building and notarizing
# FrameGen-<version>.zip.
#
# Usage: scripts/update-cask.sh <version> <zip-path> <cask-file>
set -euo pipefail

script_name=${0:t}

usage() {
  print -u2 "Usage: $script_name <version> <zip-path> <cask-file>"
  exit 2
}

(( $# == 3 )) || usage

version=$1
zip_path=$2
cask_file=$3

if [[ ! $version =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
  print -u2 "error: invalid version '$version' (expected e.g. 2.0 or 2.0.1)"
  exit 1
fi
[[ -f $zip_path ]] || { print -u2 "error: zip not found: $zip_path"; exit 1; }
[[ -f $cask_file ]] || { print -u2 "error: cask file not found: $cask_file"; exit 1; }

sha256=$(shasum -a 256 "$zip_path" | awk '{print $1}')

version_re='^[[:space:]]*version "[^"]*"[[:space:]]*$'
sha_re='^[[:space:]]*sha256 "[^"]*"[[:space:]]*$'
for re name in "$version_re" version "$sha_re" sha256; do
  count=$(grep -cE "$re" "$cask_file" || true)
  if (( count != 1 )); then
    print -u2 "error: expected exactly one '$name \"...\"' line in $cask_file, found $count"
    exit 1
  fi
done

sed -E -i '' \
  -e "s/^([[:space:]]*)version \"[^\"]*\"[[:space:]]*\$/\\1version \"$version\"/" \
  -e "s/^([[:space:]]*)sha256 \"[^\"]*\"[[:space:]]*\$/\\1sha256 \"$sha256\"/" \
  "$cask_file"

print "version: $version"
print "sha256:  $sha256"
