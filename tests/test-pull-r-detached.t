This test checks our behaviour with detached git tags, or tags that
aren't present in the Git repository. In particular, we should fetch
only save the git tags actually present in the repository, and obtain
detached tags even with --rev/-r

Load commonly used test logic
  $ . "$TESTDIR/testutil"

Create a Git repository with two tags: One on the branch, annotated,
and two elsewhere, one of each kind.

  $ git init gitrepo
  Initialized empty Git repository in $TESTTMP/gitrepo/.git/
  $ cd gitrepo
  $ git config receive.denyCurrentBranch ignore
  $ echo alpha > alpha
  $ git add alpha
  $ fn_git_commit -m 'add alpha'
  $ fn_git_tag -a -m 'added tag alpha' alpha

  $ git checkout -b not-master
  Switched to a new branch 'not-master'
  $ echo beta > beta
  $ git add beta
  $ fn_git_commit -m 'add beta'
  $ fn_git_tag -a -m 'added tag beta' beta

  $ echo gamma > gamma
  $ git add gamma
  $ fn_git_commit -m 'add gamma'
  $ fn_git_tag -a -m 'added tag gamma' gamma

  $ git log --graph --all --oneline --decorate
  * 46162f6 (HEAD -> not-master, tag: gamma) add gamma
  * 2479458 (tag: beta) add beta
  * 7eeab2e (tag: alpha, master) add alpha
  $ cd ..

Try cloning everything:

  $ hg clone -U gitrepo hgrepo
  importing 3 git commits
  new changesets ff7a2f2d8d70:5160063ed871 (3 drafts)
  $ cd hgrepo
  $ hg log --graph --style=compact
  o  2[default/not-master,gamma,tip][not-master]   5160063ed871   2007-01-01 00:00 +0000   test
  |    add gamma
  |
  o  1[beta]   5403d6137622   2007-01-01 00:00 +0000   test
  |    add beta
  |
  o  0[alpha,default/master][master]   ff7a2f2d8d70   2007-01-01 00:00 +0000   test
       add alpha
  
  $ GIT_DIR=$(hg debuggitdir) git tag -ln
  alpha           added tag alpha
  beta            added tag beta
  gamma           added tag gamma
  $ cd ..
  $ rm -rf hgrepo

That is what we expect!

Try cloning master:

  $ hg clone -U -r master gitrepo hgrepo
  importing 1 git commits
  new changesets ff7a2f2d8d70 (1 drafts)
  $ cd hgrepo
  $ hg log --graph --style=compact
  o  0[alpha,default/master,tip][master]   ff7a2f2d8d70   2007-01-01 00:00 +0000   test
       add alpha
  
  $ GIT_DIR=$(hg debuggitdir) git tag -ln
  error: refs/tags/alpha does not point to a valid object!
  error: refs/tags/beta does not point to a valid object!
  error: refs/tags/gamma does not point to a valid object!
  $ cd ..
  $ rm -rf hgrepo

Try cloning everything, but with an explicit -r; that should also
include the annotated tags:

  $ hg clone -U -r not-master gitrepo hgrepo
  importing 3 git commits
  new changesets ff7a2f2d8d70:5160063ed871 (3 drafts)
  $ cd hgrepo
  $ hg log --graph --style=compact
  o  2[default/not-master,gamma,tip][not-master]   5160063ed871   2007-01-01 00:00 +0000   test
  |    add gamma
  |
  o  1[beta]   5403d6137622   2007-01-01 00:00 +0000   test
  |    add beta
  |
  o  0[alpha,default/master][master]   ff7a2f2d8d70   2007-01-01 00:00 +0000   test
       add alpha
  
  $ GIT_DIR=$(hg debuggitdir) git tag -ln
  error: refs/tags/alpha does not point to a valid object!
  error: refs/tags/beta does not point to a valid object!
  error: refs/tags/gamma does not point to a valid object!

Check how we handle pushing with those missing revisions:

  $ hg up not-master
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark not-master)
  $ echo delta > delta
  $ fn_hg_commit -Am 'add delta'
  $ hg push -q || true
  abort: branch 'refs/tags/alpha' changed on the server, please pull and merge before pushing
  $ cd ..
  $ rm -rf hgrepo
