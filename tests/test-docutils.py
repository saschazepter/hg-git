#!/usr/bin/env python3

from __future__ import print_function

import sys

if sys.version_info[0] < 3:
    print("skipped: Python 3 required", file=sys.stderr)
    sys.exit(80)

try:
    from docutils import core
except ImportError:
    print("skipped: docutils not installed", file=sys.stderr)
    sys.exit(80)

import pathlib

TOPDIR = pathlib.Path(__file__).parent.parent.absolute()

for fn in TOPDIR.glob("*.rst"):
    core.publish_file(writer_name='null', source_path=fn)
