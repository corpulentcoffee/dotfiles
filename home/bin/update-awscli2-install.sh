#!/usr/bin/env bash
#
# Unlike v1 of the AWS CLI, v2 is no longer distributed via pip. Instead, v2
# requires the manual installation of a zip archive. See the GitHub issue at
# <https://github.com/aws/aws-cli/issues/4947> for more information.
#
# The AWS CLI sees very frequent releases, so this script endeavours to keep an
# already-existing installation up-to-date without the manual steps.
#
# The script assumes that `--install-dir ~/opt/aws-cli` and `--bin-dir ~/bin`
# were used for an initial install (i.e. in the user home directory without the
# need for `sudo`). These assumptions are checked before attempting anything.
#
# One possible alternative to doing this might be to make an `aws` bin script
# that wraps `docker run --rm -it amazon/aws-cli`. Practical usage would require
# creating bind mounts, however, like for reading credentials and getting input
# files; see <https://hub.docker.com/r/amazon/aws-cli> for examples.

set -euETo pipefail
shopt -s inherit_errexit

readonly installDir=~/opt/aws-cli
readonly binDir=~/bin
readonly binPath=$binDir/aws
readonly packageUrl=https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
readonly keepVersions=3 # including the new current version
test "$keepVersions" -ge 1

# Sanity check the installation is how we'd expect before touching anything.

function verify() {
  test $# -gt 1
  local -r reason=$1
  shift
  if ! "$@"; then
    echo "cannot update AWS CLI: expecting that $reason" >&2
    echo "(checking \`$*\` failed)" >&2
    exit 1
  fi
}

verify "$installDir is directory" test -d "$installDir"
verify "$installDir/v2 is directory" test -d "$installDir/v2"
verify "$installDir/v2/current is symlink" test -L "$installDir/v2/current"
verify "$binPath is symlink" test -L "$binPath"
verify "$binPath is executable" test -x "$binPath"

verify "$binPath points to $installDir/v2/current/bin/aws" \
  test "$(readlink "$binPath")" == "$installDir/v2/current/bin/aws"

verify "$installDir/v2/current points to a sibling version directory" \
  grep --quiet --perl-regexp \
  "^$installDir/v2/2\.\d+\.\d+\$" <(readlink "$installDir/v2/current")

# Okay, let's do it...

tempZip=$(mktemp --suffix=.zip)
oldVersion=$("$binPath" --version)
readonly tempZip oldVersion

curl \
  --fail \
  --time-cond "$installDir/v2/current" \
  --output "$tempZip" \
  "$packageUrl"

echo
if [ -s "$tempZip" ]; then # package on the web is newer than local
  tempDir=$(mktemp --directory)
  readonly tempDir

  unzip -q "$tempZip" -d "$tempDir"

  "$tempDir/aws/install" \
    --update \
    --install-dir "$installDir" \
    --bin-dir "$binDir"

  echo "was $oldVersion"

  # If these aren't cleaned up, they will just accumulate forever...
  (
    cd "$installDir"
    find 'v2' -mindepth 1 -maxdepth 1 -type d -name '2.*.*' |
      cut --delimiter=/ --fields=2 |
      sort --version-sort |
      head --lines=-"$keepVersions" |
      while read -r version; do
        echo "removing old version $version from $installDir/v2 directory"
        rm --recursive "./v2/$version"
      done
  )

  echo "now $("$binPath" --version)"
else
  echo 'AWS CLI already up-to-date:'
  echo "$oldVersion"
fi
