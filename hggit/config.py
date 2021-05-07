from __future__ import generator_stop

from mercurial import exthelper
from mercurial.utils import stringutil

from . import compat

eh = exthelper.exthelper()

CONFIG_DEFAULTS = {
    b'git': {
        b'authors': None,
        b'branch_bookmark_suffix': None,
        b'debugextrainmessage': False,  # test only -- do not document this!
        b'findcopiesharder': False,
        b'intree': None,
        b'mindate': None,
        b'public': list,
        b'renamelimit': 400,
        b'similarity': 0,
        b'pull-prune-remote-branches': True,
        b'pull-prune-bookmarks': True,
    },
    b'hggit': {
        b'fetchbuffer': 100,
        b'mapsavefrequency': 1000,
        b'usephases': False,
        b'retries': 3,
        b'invalidpaths': b'skip',
    },
    b'devel': {
        b'debug.hg-git.find-successors-in': list,
    },
}

for section, items in CONFIG_DEFAULTS.items():
    for item, default in items.items():
        eh.configitem(section, item, default=default)


@eh.extsetup
def extsetup(ui):
    @compat.pathsuboption(b'hg-git.publish', b'hggit_publish')
    def pathsuboption(ui, path, value):
        b = stringutil.parsebool(value)
        if b is not None:
            return b
        else:
            return compat.parselist(value)
