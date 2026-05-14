#!/bin/sh

set -e

BUILDDEPENDS="curl jq coreutils gcc gettext musl-dev"
RUNDEPENDS="git git-daemon unzip openssh gnupg"

# coverage >= 7.13.0 would break with:
#
# Traceback (most recent call last):
#   File "/usr/lib64/python3.10/site.py", line 195, in addpackage
#     exec(line)
#   File "<string>", line 1, in <module>
#   File "<string>", line 15, in <module>
#   File "<PYTHONPATH>/site-packages/coverage/control.py", line 1491, in process_startup
#     cov = Coverage(config_file=config_file)
#   File "<PYTHONPATH>/site-packages/coverage/control.py", line 325, in __init__
#     self.config = read_coverage_config(
#   File "<PYTHONPATH>/site-packages/coverage/config.py", line 702, in read_coverage_config
#     raise ConfigError(f"Couldn't read {fname!r} as a config file")
# coverage.exceptions.ConfigError: Couldn't read '<BASE>/tests/.coveragerc' as a config file
#
# A simple fix would be creating an empty file in <BASE>/tests/.coveragerc, but
# it would be fragile: the file position would depend on the current working
# directory. Using a fixed absolute path would be better, but coverage is
# controlled by run-tests.py, which is a very complex script.
#
# Fixing coverage version to 7.12.0, which is the latest one that works without
# requiring less controllable changes.
PIPDEPENDS="black coverage==7.12.0 dulwich pyflakes pygments pylint setuptools_scm"

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
