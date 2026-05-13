import inspect

import mercurial.commands  # TODO: do not re-export mercurial.commands (use "as _commands"?)
from dulwich.object_store import PackBasedObjectStore


if hasattr(PackBasedObjectStore, 'delete_loose_object'):

    def delete_loose_object(object_store: PackBasedObjectStore, sha: bytes):
        object_store.delete_loose_object(sha)

else:

    def delete_loose_object(object_store: PackBasedObjectStore, sha: bytes):
        object_store._remove_loose_object(sha)


try:
    # dulwich >= 0.25.0
    from dulwich.protocol import PEELED_TAG_SUFFIX
except ImportError:
    # dulwich <= 0.24.10
    from dulwich.refs import PEELED_TAG_SUFFIX

    assert PEELED_TAG_SUFFIX  # silence pyflakes

try:
    # hg >= 7.2
    from mercurial.bundle2_part_handlers import parthandler
except ImportError:
    from mercurial.bundle2 import parthandler

    assert parthandler  # silence pyflakes

try:
    # hg >= 7.2
    from mercurial.exchanges.peer import Peer
except ImportError:
    from mercurial.interfaces.repository import peer as Peer

    assert Peer  # silence pyflakes

import mercurial.utils.urlutil as _urlutil  # do not re-export urlutil

if hasattr(_urlutil, 'add_branch_revs'):
    # hg >= 7.2
    from mercurial.utils import urlutil as add_branch_revs_mod

    add_branch_revs_function_name = 'add_branch_revs'
else:
    from mercurial import hg as add_branch_revs_mod

    add_branch_revs_function_name = 'addbranchrevs'
    assert add_branch_revs_mod  # silence pyflakes

try:
    # hg >= 7.2
    from mercurial.cmd_impls.clone import default_dest
except ImportError:
    from mercurial.hg import defaultdest as default_dest

    assert default_dest  # silence pyflakes

if inspect.getfullargspec(mercurial.commands.init).args == []:
    # hg >= 7.2
    #
    # this accesses the private function _init(), and assumes that:
    #
    # >>> inspect.getfullargspec(mercurial.commands._init)
    # FullArgSpec(args=['ui', 'dest'], varargs=None, varkw='opts', defaults=(b'.',), kwonlyargs=[], kwonlydefaults=None, annotations={})
    from mercurial.commands import _init as commands_init
else:
    from mercurial.commands import init as commands_init

    assert commands_init  # silence pyflakes
