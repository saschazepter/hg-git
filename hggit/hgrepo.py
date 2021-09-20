from __future__ import generator_stop

from mercurial import exthelper
from mercurial import repoview
from mercurial import util as hgutil
from mercurial.node import bin

from .git_handler import GitHandler
from .gitrepo import gitrepo
from . import util

eh = exthelper.exthelper()


@eh.reposetup
def reposetup(ui, repo):
    if isinstance(repo, gitrepo):
        return

    if hasattr(repo, '_wlockfreeprefix'):
        repo._wlockfreeprefix |= {
            GitHandler.map_file,
            GitHandler.remote_refs_file,
            GitHandler.tags_file,
        }

    class hgrepo(repo.__class__):
        @util.transform_notgit
        def findoutgoing(self, remote, base=None, heads=None, force=False):
            if isinstance(remote, gitrepo):
                base, heads = self.githandler.get_refs(remote.path)
                out, h = super(hgrepo, self).findoutgoing(remote, base,
                                                          heads, force)
                return out
            else:  # pragma: no cover
                return super(hgrepo, self).findoutgoing(remote, base,
                                                        heads, force)

        def _findtags(self):
            (tags, tagtypes) = super(hgrepo, self)._findtags()

            for tag, rev in self.githandler.tags.items():
                if tag not in tags:
                    assert isinstance(tag, bytes)
                    tags[tag] = bin(rev)
                    tagtypes[tag] = b'git'
            for tag, rev in self.githandler.remote_refs.items():
                assert isinstance(tag, bytes)
                tags[tag] = rev
                tagtypes[tag] = b'git-remote'
            tags.update(self.githandler.remote_refs)
            return (tags, tagtypes)

        @hgutil.propertycache
        def githandler(self):
            '''get the GitHandler for an hg repo

            This only makes sense if the repo talks to at least one git remote.
            '''
            return GitHandler(self, self.ui)

        def tags(self):
            # TODO consider using self._tagscache
            tagscache = super(hgrepo, self).tags()
            tagscache.update(self.githandler.remote_refs)
            for tag, rev in self.githandler.tags.items():
                if tag in tagscache:
                    continue

                tagscache[tag] = bin(rev)

            return tagscache

    repo.__class__ = hgrepo


@eh.wrapfunction(repoview, b'pinnedrevs')
def pinnedrevs(orig, repo):
    pinned = orig(repo)

    # Mercurial pins bookmarks, even if obsoleted, so that they always
    # appear in e.g. log; do the same with git tags and remotes.
    if repo.local() and hasattr(repo, 'githandler'):
        # build up a list of applicable nodes
        nodes = set(map(bin, repo.githandler.tags.values()))
        nodes.update(repo.githandler.remote_refs.values())

        # convert it to revs, taking care to handle unknown nodes
        revs = set(map(repo.changelog.rev, filter(repo.__contains__, nodes)))

        pinned.update(revs)

    return pinned
