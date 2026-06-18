#!/bin/sh

set -x

# MUXATOR 2026-06-18
#
# CI tests were failing with:
#    AssertionError: Invalid sideband channel 3
#
# see: https://foss.heptapod.net/mercurial/hg-git/-/jobs/4221633
#
# Looking up this error for hg-git, pops up this thread from 2016:
#     https://github.com/schacon/hg-git/issues/289
#
# A solution suggested at the time was running "easy_install keyring".
#
# A possible alternative, that worked in the past when I had a similar problem
# with poetry, is to set PYTHON_KEYRING_BACKEND.
#
# Let's test it and see what happens.
export PYTHON_KEYRING_BACKEND=keyring.backends.fail.Keyring

git version
hg debuginstall --config extensions.hggit=./hggit
hg version -v --config extensions.hggit=./hggit

exec python$PYTHON tests/run-tests.py \
     --allow-slow-tests \
     --color=always \
     --cover \
     --xunit $PWD/tests-$CI_JOB_ID.xml
