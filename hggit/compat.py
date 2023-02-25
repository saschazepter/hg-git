from __future__ import generator_stop

import functools

from mercurial import (
    node,
    ui,
    util as hgutil,
    wireprotov1peer,
)

from dulwich import object_store
from dulwich import pack

# dulwich 0.20.49 changed create_delta to a generator
def create_delta(base_buf, target_buf):
    delta = pack.create_delta(base_buf, target_buf)

    if not isinstance(delta, bytes):
        delta = b''.join(delta)

    return delta


# 5.9 and earlier used a future-based API
if hasattr(wireprotov1peer, 'future'):

    def makebatchable(fn):
        @functools.wraps(fn)
        @wireprotov1peer.batchable
        def wrapper(*args, **kwargs):
            yield None, wireprotov1peer.future()
            yield fn(*args, **kwargs)

        return wrapper


# 6.0 and later simplified the API
else:

    def makebatchable(fn):
        @functools.wraps(fn)
        @wireprotov1peer.batchable
        def wrapper(*args, **kwargs):
            return None, lambda v: fn(*args, **kwargs)

        return wrapper


try:
    # moved in 5.9
    from mercurial.utils.stringutil import parselist
except ImportError:
    from mercurial.config import parselist

assert parselist  # silence pyflakes

try:
    # added in 5.9
    from mercurial.node import sha1nodeconstants
except ImportError:

    class sha1nodeconstants(object):
        nodelen = len(node.nullid)

        nullid = node.nullid
        nullhex = node.nullhex
        newnodeid = node.newnodeid
        addednodeid = node.addednodeid
        modifiednodeid = node.modifiednodeid
        wdirfilenodeids = node.wdirfilenodeids
        wdirid = node.wdirid
        wdirhex = node.wdirhex


try:
    # added in 5.8
    from mercurial.utils import urlutil

    url = urlutil.url
    path = urlutil.path
    pathsuboption = urlutil.pathsuboption
except ImportError:
    urlutil = hgutil
    url = hgutil.url
    path = ui.path
    pathsuboption = ui.pathsuboption

try:
    from dulwich.client import HTTPUnauthorized
except ImportError:
    # added in dulwich 0.20.3; just create a dummy class for catching
    class HTTPUnauthorized(Exception):
        pass


# dulwich 0.21 removed find_missing_objects() and made MissingObjectFinder a
# proper iterable
if not hasattr(object_store.MissingObjectFinder, '__iter__'):

    class MissingObjectFinder(object_store.MissingObjectFinder):
        def __iter__(self):
            return iter(self.next, None)

else:
    MissingObjectFinder = object_store.MissingObjectFinder
