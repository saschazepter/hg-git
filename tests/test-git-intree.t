#testcases intree worktree

Load commonly used test logic
  $ . "$TESTDIR/testutil"

#if intree
  $ echo "[git]" >> $HGRCPATH
  $ echo "intree = True" >> $HGRCPATH
#else
  $ echo "[hggit]" >> $HGRCPATH
  $ echo "worktree = True" >> $HGRCPATH
#endif

  $ hg init hgrepo
  $ cd hgrepo
  $ hg debuggitdir
  $TESTTMP/hgrepo/.hg/git (worktree !)
  $TESTTMP/hgrepo/.git (intree !)
  $ echo alpha > alpha
  $ hg add alpha
  $ fn_hg_commit -m "add alpha"
  $ hg log --graph --debug | grep -v phase:
  @  changeset:   0:0221c246a56712c6aa64e5ee382244d8a471b1e2
     tag:         tip
     parent:      -1:0000000000000000000000000000000000000000
     parent:      -1:0000000000000000000000000000000000000000
     manifest:    0:8b8a0e87dfd7a0706c0524afa8ba67e20544cbf0
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     files+:      alpha
     extra:       branch=default
     description:
     add alpha
  
  

  $ cd ..

configure for use from git
  $ hg clone hgrepo gitrepo
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd gitrepo
  $ hg book master

#if intree
  $ hg debuggitdir
  $TESTTMP/gitrepo/.git
  $ hg gexport
  $ hg up null
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (leaving bookmark master)
#else
  $ hg debuggitdir
  $TESTTMP/gitrepo/.hg/git
  $ cat .git
  gitdir: $TESTTMP/gitrepo/.hg/git/worktrees/gitrepo
  $ git show -q --decorate --oneline
  672a49b (HEAD -> master) add alpha
  $ hg book -i
  $ git show -q --decorate --oneline
  672a49b (HEAD, master) add alpha
  $ hg up null
  warning: cannot synchronise git checkout!
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ git show -q --decorate --oneline
  672a49b (HEAD, master) add alpha
  $ hg up tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ git show -q --decorate --oneline
  672a49b (HEAD, master) add alpha
  $ hg up null
  warning: cannot synchronise git checkout!
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
#endif

do some work
  $ git checkout -q master
  $ echo beta > beta
  $ git add beta
  $ fn_git_commit -m 'add beta'

get things back to hg
  $ hg gimport -q
  $ hg book
     master                    1:9f124f3c1fc2
  $ hg log --graph --debug | grep -v phase:
  o  changeset:   1:9f124f3c1fc29a14f5eb027c24811b0ac9d5ff10
  |  bookmark:    master
  |  tag:         tip
  |  parent:      0:0221c246a56712c6aa64e5ee382244d8a471b1e2
  |  parent:      -1:0000000000000000000000000000000000000000
  |  manifest:    1:f0bd6fbafbaebe4bb59c35108428f6fce152431d
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  files+:      beta
  |  extra:       branch=default
  |  extra:       hg-git-rename-source=git
  |  description:
  |  add beta
  |
  |
  o  changeset:   0:0221c246a56712c6aa64e5ee382244d8a471b1e2
     parent:      -1:0000000000000000000000000000000000000000
     parent:      -1:0000000000000000000000000000000000000000
     manifest:    0:8b8a0e87dfd7a0706c0524afa8ba67e20544cbf0
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     files+:      alpha
     extra:       branch=default
     description:
     add alpha
  
  
gimport should have updated the bookmarks as well
  $ hg bookmarks
     master                    1:9f124f3c1fc2

gimport support for git.mindate
  $ cat >> .hg/hgrc << EOF
  > [git]
  > mindate = 2014-01-02 00:00:00 +0000
  > EOF
  $ echo oldcommit > oldcommit
  $ git add oldcommit
  $ GIT_AUTHOR_DATE="2014-03-01 00:00:00 +0000" \
  > GIT_COMMITTER_DATE="2009-01-01 00:00:00 +0000" \
  > git commit -m oldcommit > /dev/null || echo "git commit error"
  $ hg gimport
  no changes found
  $ hg log --graph
  o  changeset:   1:9f124f3c1fc2
  |  bookmark:    master
  |  tag:         tip
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     add beta
  |
  o  changeset:   0:0221c246a567
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  

  $ echo newcommit > newcommit
  $ git add newcommit
  $ GIT_AUTHOR_DATE="2014-01-01 00:00:00 +0000" \
  > GIT_COMMITTER_DATE="2014-01-02 00:00:00 +0000" \
  > git commit -m newcommit > /dev/null || echo "git commit error"
  $ hg gimport
  importing 2 git commits
  updating bookmark master
  new changesets befdecd14df5:3d10b7289d79 (2 drafts)
  $ hg log --graph
  o  changeset:   3:3d10b7289d79
  |  bookmark:    master
  |  tag:         tip
  |  user:        test <test@example.org>
  |  date:        Wed Jan 01 00:00:00 2014 +0000
  |  summary:     newcommit
  |
  o  changeset:   2:befdecd14df5
  |  user:        test <test@example.org>
  |  date:        Sat Mar 01 00:00:00 2014 +0000
  |  summary:     oldcommit
  |
  o  changeset:   1:9f124f3c1fc2
  |  user:        test <test@example.org>
  |  date:        Mon Jan 01 00:00:11 2007 +0000
  |  summary:     add beta
  |
  o  changeset:   0:0221c246a567
     user:        test
     date:        Mon Jan 01 00:00:10 2007 +0000
     summary:     add alpha
  


#if intree

Can we switch back and forth?

  $ hg debugstrip --no-backup master
  $ hg git-cleanup
  git commit map cleaned
  $ hg debug-move-git-repo --config git.intree=no
  $TESTTMP/gitrepo/.git -> $TESTTMP/gitrepo/.hg/git
  $ hg debug-move-git-repo --config git.intree=yes
  $TESTTMP/gitrepo/.hg/git -> $TESTTMP/gitrepo/.git

And what if such a repository already exists, or there's nothing to do?

  $ hg gimport --config git.intree=no
  warning: created new git repository at $TESTTMP/gitrepo/.hg/git
  no changes found
  $ hg debug-move-git-repo
  abort: refusing to override an existing git repository
  (a git repository already exists at $TESTTMP/gitrepo/.git)
  [255]
  $ rm -rf .hg/git
  $ hg debug-move-git-repo
  nothing to do; no git repository exists at $TESTTMP/gitrepo/.hg/git

And the repository survived all that:

  $ hg gimport
  importing 1 git commits
  updating bookmark master
  new changesets 3d10b7289d79 (1 drafts)

#endif
