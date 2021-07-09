from __future__ import generator_stop

import functools
import urllib.parse

from mercurial.i18n import _
from mercurial import (
    error,
    node,
    httppeer,
    pycompat,
    ui,
    url as urlmod,
    util as hgutil,
    wireprotov1peer,
)


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


def sysbytes(s):
    # 5.2 does not check this
    if isinstance(s, str):
        return pycompat.sysbytes(s)
    else:
        return s


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


try:
    from mercurial.cmdutil import check_at_most_one_arg
except (ImportError, AttributeError):
    # added in 5.3
    def check_at_most_one_arg(opts, *args):
        """abort if more than one of the arguments are in opts

        Returns the unique argument or None if none of them were specified.
        """

        def to_display(name):
            return sysbytes(name).replace(b'_', b'-')

        previous = None
        for x in args:
            if opts.get(x):
                if previous:
                    raise error.Abort(
                        _(b'cannot specify both --%s and --%s')
                        % (to_display(previous), to_display(x))
                    )
                previous = x
        return previous


# added in 5.3 but changed in 5.4, so always use our implementation
def check_incompatible_arguments(opts, first, others):
    """abort if the first argument is given along with any of the others

    Unlike check_at_most_one_arg(), `others` are not mutually exclusive
    among themselves, and they're passed as a single collection.
    """
    for other in others:
        check_at_most_one_arg(opts, first, other)


try:
    # added in dulwich 0.20.24
    from dulwich.client import AbstractHttpGitClient

    class HgHttpGitClient(AbstractHttpGitClient):
        def __init__(self, ui, base_url, **kwargs):
            url = urlutil.url(base_url)

            if url.query or url.fragment:
                raise error.Abort(
                    _(b'unsupported URL component: "%s"')
                    % (url.query or url.fragment)
                )

            # urllib cannot handle URLs with embedded user or passwd.
            url, authinfo = url.authinfo()
            ui.debug(b'using %s\n' % url)

            self.__ui = ui
            self.__opener = urlmod.opener(ui, authinfo)

            super().__init__(pycompat.strurl(url), **kwargs)

        def _get_url(self, path):
            u = urllib.parse.urljoin(self._base_url, pycompat.strurl(path))
            return u.rstrip("/") + "/"

        def _http_request(
            self,
            str_url,
            headers=None,
            data=None,
            allow_compression=False,
        ):
            self.__ui.debug(
                b"requesting %s\n"
                % urlutil.hidepassword(pycompat.bytesurl(str_url))
            )

            if headers is None:
                headers = {}
            if allow_compression:
                headers["Accept-Encoding"] = "gzip"
            else:
                headers["Accept-Encoding"] = "identity"

            # TODO: recent versions of dulwich use generators for
            # passing data on lazily; it would be nice to somehow
            # retain that memory optimisation
            if data is not None and not isinstance(data, bytes):
                data = b''.join(data)

            req = hgutil.urlreq.request(str_url, data, headers)

            resp = httppeer.sendrequest(self.__ui, self.__opener, req)

            resp_url = resp.geturl()

            # used by dulwich
            resp.redirect_location = resp_url if resp_url != url else ""
            resp.content_type = resp.getheader("Content-Type")

            return resp, resp.read

except ImportError:
    HgHttpGitClient = None
