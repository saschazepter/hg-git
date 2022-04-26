from __future__ import generator_stop

import io

from mercurial import bundle2
from mercurial import exchange
from mercurial import exthelper
from mercurial import hg
from mercurial import repoview
from mercurial import streamclone
from mercurial import util as hgutil
from mercurial.node import bin, hex

from .git_handler import GitHandler
from .gitrepo import gitrepo
from . import util

eh = exthelper.exthelper()

CAPABILITY_MAP = b'exp-hg-git-map'
CAPABILITY_TAGS = b'exp-hg-git-tags'

BUNDLEPART_MAP = b'exp-hg-git-map'
BUNDLEPART_TAGS = b'exp-hg-git-tags'


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
                out, h = super().findoutgoing(remote, base, heads, force)
                return out
            else:  # pragma: no cover
                return super().findoutgoing(remote, base, heads, force)

        def _findtags(self):
            (tags, tagtypes) = super()._findtags()

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
            tagscache = super().tags()
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
        rev = repo.changelog.rev

        pinned.update(rev(bin(r)) for r in repo.githandler.tags.values())
        pinned.update(rev(r) for r in repo.githandler.remote_refs.values())

    return pinned


@eh.wrapfunction(bundle2, 'getrepocaps')
def getrepocaps(orig, repo, **kwargs):
    caps = orig(repo, **kwargs)

    if repo.ui.configbool(b'experimental', b'hg-git-serve'):
        caps[CAPABILITY_MAP] = ()
        caps[CAPABILITY_TAGS] = ()

    return caps


def addpartrevgitmap(repo, bundler, outgoing):
    if repo.githandler:
        # this is different from what we store in the repository,
        # and uses binary node ids: <20 bytes> <20 bytes>
        repo.ui.debug(b'bundling git map\n')

        chunks = (
            bin(repo.githandler._map_hg[hex(hgnode)]) + hgnode
            for hgnode in outgoing.missing
            if hex(hgnode) in repo.githandler._map_hg
        )

        bundler.newpart(BUNDLEPART_MAP, data=chunks, mandatory=False)


def addpartrevgittags(repo, bundler, outgoing):
    if repo.githandler.tags:
        # this is consistent with the format used in the repository:
        # <40 hex digits> <space> <tag name> <newline>
        repo.ui.debug(b'bundling git tags\n')

        chunks = (
            b"%s %s\n" % (sha, name)
            for name, sha in sorted(repo.githandler.tags.items())
            if bin(sha) in outgoing.missing
        )

        bundler.newpart(BUNDLEPART_TAGS, data=chunks, mandatory=False)


@eh.wrapfunction(bundle2, '_addpartsfromopts')
def _addpartsfromopts(orig, ui, repo, bundler, source, outgoing, opts):
    orig(ui, repo, bundler, source, outgoing, opts)

    if opts.get(b'exp-hg-git', False) or ui.configbool(
        b'experimental', b'hg-git-bundle'
    ):
        addpartrevgitmap(repo, bundler, outgoing)
        addpartrevgittags(repo, bundler, outgoing)


if hasattr(streamclone, '_v2_walk'):
    # added in mercurial 5.9
    @eh.wrapfunction(streamclone, '_v2_walk')
    def _v2_walk(orig, repo, *args, **kwargs):
        entries, totalfilesize = orig(repo, *args, **kwargs)

        if repo.ui.configbool(b'experimental', b'hg-git-serve'):
            for fn in (repo.githandler.map_file, repo.githandler.tags_file):
                totalfilesize += repo.svfs.lstat(fn).st_size
                entries.append(
                    (streamclone._srcstore, fn, streamclone._filefull, None),
                )

        return entries, totalfilesize

else:

    @eh.reposetup
    def add_files_to_copylist(ui, repo):
        if hasattr(repo, 'store'):

            class hggitstore(repo.store.__class__):
                def copylist(self):
                    fns = super().copylist()

                    if repo.ui.configbool(b'experimental', b'hg-git-serve'):
                        fns += [
                            b'store/' + repo.githandler.map_file,
                            b'store/' + repo.githandler.tags_file,
                        ]

                    return fns

            repo.store.__class__ = hggitstore


@eh.wrapfunction(bundle2, 'getrepocaps')
def getrepocaps(orig, repo, **kwargs):
    caps = orig(repo, **kwargs)

    if repo.ui.configbool(b'experimental', b'hg-git-serve'):
        caps[CAPABILITY_MAP] = ()
        caps[CAPABILITY_TAGS] = ()

    return caps


@eh.extsetup
def install_server_support(ui):
    @bundle2.parthandler(BUNDLEPART_MAP)
    def handlebundlemap(op, inpart):
        ui.debug(b'unbundling git map\n')

        while True:
            # this is different from what we store in the repository,
            # and uses binary node ids: <20 bytes> <20 bytes>
            line = inpart.read(40)

            if inpart.consumed:
                break

            gitsha = hex(line[:20])
            hgsha = hex(line[20:])

            op.repo.githandler.map_set(gitsha, hgsha)

        op.repo.githandler.save_map()

    @exchange.getbundle2partsgenerator(BUNDLEPART_MAP)
    def gitmapbundle(
        bundler, repo, source, bundlecaps=None, b2caps=None, **kwargs
    ):
        if not b2caps or CAPABILITY_MAP not in b2caps:
            return

        ui.debug(b'bundling git map\n')

        outgoing = exchange._computeoutgoing(
            repo,
            kwargs['heads'],
            kwargs['common'],
        )

        addpartrevgitmap(repo, bundler, outgoing)

    @bundle2.parthandler(BUNDLEPART_TAGS)
    def handlebundletags(op, inpart):
        with io.BytesIO() as buf:
            while not inpart.consumed:
                buf.write(inpart.read())
            buf.seek(0)

            # we're consistent, and always load everything, so just
            # let the handler do its thing
            op.repo.githandler._read_tags_from(buf)
            op.repo.githandler.save_tags()

    @exchange.getbundle2partsgenerator(BUNDLEPART_TAGS)
    def gittagbundle(
        bundler, repo, source, bundlecaps=None, b2caps=None, **kwargs
    ):
        if not b2caps or CAPABILITY_TAGS not in b2caps:
            return

        outgoing = exchange._computeoutgoing(
            repo,
            kwargs['heads'],
            kwargs['common'],
        )

        addpartrevgittags(repo, bundler, outgoing)
