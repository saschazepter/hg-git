#!/bin/sh

set -e

BUILDDEPENDS="curl gcc gettext musl-dev"
RUNDEPENDS="git git-daemon unzip openssh gnupg"

if echo "$HG" | fgrep -q .
then
    PIPDEPENDS="mercurial~=$HG.0"
else
    PIPDEPENDS="https://www.mercurial-scm.org/repo/hg/archive/$HG.tar.gz"
fi

if echo "$PYTHON" | grep -q ^2
then
    PIPDEPENDS="$PIPDEPENDS dulwich~=0.19.0"
else
    PIPDEPENDS="$PIPDEPENDS dulwich pyflakes"
fi

if test "$PYTHON" -gt 3.5
then
    PIPDEPENDS="$PIPDEPENDS black==20.8b1"
fi

set -xe

apk add --no-cache $BUILDDEPENDS $RUNDEPENDS

python -m pip --no-cache-dir install $PIPDEPENDS

apk del $BUILDDEPENDS
