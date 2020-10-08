from __future__ import generator_stop

from mercurial import exthelper
from mercurial import namespaces
from mercurial import repoview
from mercurial import util as hgutil
from mercurial.node import bin, hex

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

    # add namespaces for git commit & committer
    if repo.local():
        def namemap(repo, name):
            r = repo.githandler.map_hg_get(name)
            return [bin(r)] if r else []

        def nodemap(repo, node):
            r = repo.githandler.map_git_get(hex(node))
            return [r] if r else []

        def singlenode(repo, name):
            r = repo.githandler.map_hg_get(name)
            return bin(r) if r else None

        def listnames(repo):
            return repo.githandler._map_git

        repo.names.addnamespace(namespaces.namespace(
            name=b'gitnode',
            templatename=b'gitnode',
            colorname=b'gitnode',
            logfmt=b'git node:    %.12s\n',
            namemap=namemap,
            nodemap=nodemap,
            singlenode=singlenode,
            listnames=listnames,
        ))

        def committer(repo, node):
            ctx = repo[node]
            extra = ctx.extra()
            committer = extra.get(b'committer', b'').rsplit(b' ', 2)[0]

            if committer and committer != ctx.user():
                return [committer]
            else:
                return []

        repo.names.addnamespace(namespaces.namespace(
            name=b'committer', templatename=b'committer',
            nodemap=committer, namemap=lambda repo, name: [],
        ))

    repo.__class__ = hgrepo


@eh.wrapfunction(repoview, b'pinnedrevs')
def pinnedrevs(orig, repo):
    pinned = orig(repo)

    # Mercurial pins bookmarks, even if obsoleted, so that they always
    # appear in e.g. log; do the same with git tags and remotes.
    if repo.local() and hasattr(repo, 'githandler'):
        rev = repo.changelog.rev

        pinned.update(rev(bin(r)) for r in repo.githandler.tags.values())
        pinned.update(rev(r) for r in repo.githandler.remote_refs.values())

    return pinned
