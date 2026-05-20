#!/bin/sh

set -e

BUILDDEPENDS="curl jq coreutils gcc gettext musl-dev"
RUNDEPENDS="git git-daemon unzip openssh gnupg"
# The version constraints should be kept in sync with setup.cfg and .gitlab-ci.yml.
PIPDEPENDS="black<26 coverage<7.13.0 dulwich>=0.22.1,<2.0.0 pyflakes pygments pylint setuptools_scm"

PIP="python -m pip --no-cache-dir"

set -xe

apk add --no-cache $BUILDDEPENDS $RUNDEPENDS

# update pip itself, due to issue #11123 in pip
$PIP install -U pip setuptools wheel

$PIP install $PIPDEPENDS

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
    $PIP install mercurial==$hgversion
else
    # unreleased, so fetch directly from Heptapod itself
    $PIP install \
        https://foss.heptapod.net/octobus/mercurial-devel/-/archive/branch/$HG/hg.tar.bz2
fi

apk del $BUILDDEPENDS
