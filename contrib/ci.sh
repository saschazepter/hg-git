#!/bin/sh

set -x

hg debuginstall

exec python$PYTHON tests/run-tests.py \
     --verbose --color=always \
     --xunit $PWD/tests-$PYTHON-$HG.xml
