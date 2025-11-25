from dulwich.object_store import PackBasedObjectStore

try:
    # Mercurial >= 7.2
    from mercurial.bundle2_part_handlers import parthandler
    from mercurial.interfaces.repository import IPeer
except ImportError:
    # fallback for Mercurial < 7.2
    from mercurial.bundle2 import parthandler
    from mercurial.interfaces.repository import peer as IPeer

    # the following is to silence pyflakes, which has no support for
    # "noqa: F401".
    #
    # TODO: when possible (for example once we migrate to ruff), replace the
    #       following asserts with a "noqa: F401" directive in the imports above
    assert parthandler
    assert IPeer


if hasattr(PackBasedObjectStore, 'delete_loose_object'):

    def delete_loose_object(object_store: PackBasedObjectStore, sha: bytes):
        object_store.delete_loose_object(sha)

else:

    def delete_loose_object(object_store: PackBasedObjectStore, sha: bytes):
        object_store._remove_loose_object(sha)
