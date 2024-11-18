#!/bin/sh

set -x

git version
hg debuginstall --config extensions.hggit=./hggit
hg version -v --config extensions.hggit=./hggit

mkdir -p out

exec python$PYTHON tests/run-tests.py \
     --color=always \
     --outputdir out \
     --cover \
     --xunit tests-$CI_JOB_ID.xml
