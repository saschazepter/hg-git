#!/bin/sh

set -e

BUILDDEPENDS="curl jq coreutils gcc gettext musl-dev"
RUNDEPENDS="git git-daemon unzip openssh gnupg"
PIPDEPENDS="black==22.3 coverage dulwich pyflakes pygments pylint"

set -xe

apk add --no-cache $BUILDDEPENDS $RUNDEPENDS

python -m pip --no-cache-dir install --pre $PIPDEPENDS

# handle pre-release versions
get_version() {
    curl -s "https://pypi.org/pypi/$1/json" \
        | jq -r '.releases | keys_unsorted | .[]' \
        | grep "^$2" \
        | sort --version-sort \
        | tail -1
}

hgversion=$(get_version mercurial $HG)

if test -n "$hgversion"
then
    python -m pip install --pre mercurial==$hgversion
else
    # unreleased, so fetch directly from Heptapod itself
    python -m pip install \
        https://foss.heptapod.net/octobus/mercurial-devel/-/archive/branch/$HG/hg.tar.bz2
fi

apk del $BUILDDEPENDS
