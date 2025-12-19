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
