from __future__ import generator_stop

import os

import dulwich

from mercurial import bookmarks
from mercurial.node import hex


def update_worktree(repo):
    if not repo.dirstate.parents() or not repo.ui.configbool(
        b'hggit',
        b'worktree',
    ):
        return

    gh = repo.githandler

    hgref = hgsha = hex(repo.dirstate.parents()[0])
    gitref = gitsha = gh.map_git_get(hgsha)
    symbolic = False

    # try running an export if the commit is missing
    if gitsha is None:
        gh.export_git_objects()
        gitref = gitsha = gh.map_git_get(hgsha)

    if gitsha is None or gitsha not in gh.git.object_store:
        repo.ui.warn(b"warning: cannot synchronise git checkout!\n")
        return

    if os.path.exists(repo.wvfs.join(b".git")):
        wrepo = dulwich.repo.Repo(os.fsdecode(repo.root))
    else:
        # dulwich throws a KeyError if creating a worktree
        # pointing to a repository with no HEAD — also, HEAD is
        # apparently always *in* the refs container?!
        has_head = b'HEAD' in gh.git.refs.as_dict()

        if not has_head:
            gh.git.refs[b"HEAD"] = gitsha

        wrepo = dulwich.repo.Repo._init_new_working_directory(
            os.fsdecode(repo.root),
            gh.git,
        )

        if not has_head:
            del gh.git.refs[b"HEAD"]

    if bookmarks.isactivewdirparent(repo):
        bookmark = repo._bookmarks._active
        suffix = gh.branch_bookmark_suffix

        if suffix and bookmark.endswith(suffix):
            bookmark = bookmark[-len(suffix) :]

        ref = dulwich.refs.LOCAL_BRANCH_PREFIX + bookmark

        if ref in wrepo.refs:
            hgref = bookmark
            gitref = ref
            symbolic = True

    msg = b"git checkout %s due to hg update %s" % (gitref, hgref)
    repo.ui.note(b"hg-git: %s\n" % msg)

    committer = gh.get_git_author()

    if symbolic:
        wrepo.refs.set_symbolic_ref(
            b"HEAD",
            gitref,
            message=msg,
            committer=committer,
        )
    else:
        # forcibly break a symbolic ref
        if b"HEAD" in wrepo.refs:
            del wrepo.refs[b"HEAD"]

        wrepo.refs.set_if_equals(
            b"HEAD",
            None,
            gitref,
            message=msg,
            committer=committer,
        )

    wrepo.reset_index()
